// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
import {IERC20} from '../interfaces/IERC20.sol';
import {IStakedToken} from '../interfaces/IStakedToken.sol';
import {StakeUIHelperI} from '../interfaces/StakeUIHelperI.sol';
import {IERC20WithNonce} from '../interfaces/IERC20WithNonce.sol';
import {IPriceOracleGetter} from '../interfaces/IPriceOracleGetter.sol';
import {SafeDecimalMath} from '../protocol/libraries/math/SafeDecimalMath.sol';
import {SafeMath} from '../dependencies/openzeppelin/contracts/SafeMath.sol';
import "hardhat/console.sol";

contract StakeUIHelper is StakeUIHelperI {
  using SafeMath for uint256;
  using SafeDecimalMath for uint256;

  IPriceOracleGetter public immutable PRICE_ORACLE;

  address public immutable MOCK_USD_ADDRESS;
  address public immutable SIO2;
  IStakedToken public immutable STAKED_SIO2;

  uint256 constant SECONDS_PER_YEAR = 365 * 24 * 60 * 60;
  uint256 constant SECONDS_PER_MONTH = 30 * 24 * 60 * 60;
  uint256 constant APY_PRECISION = 10000;
  uint256 internal constant USD_BASE = 1e26;

  constructor(
    IPriceOracleGetter priceOracle,
    address sio2,
    IStakedToken stkSiO2,
    address mockUsd
  ) public {
    PRICE_ORACLE = priceOracle;

    SIO2 = sio2;
    STAKED_SIO2 = stkSiO2;
    MOCK_USD_ADDRESS = mockUsd;
  }

  function _getUserAndGeneralStakedAssetData(
    IStakedToken stakeToken,
    address underlyingToken,
    address user,
    bool isNonceAvailable
  ) internal view returns (AssetUIData memory) {
    AssetUIData memory data;
    GeneralStakeUIData memory generalStakeData = _getGeneralStakedAssetData(stakeToken);

    data.stakeTokenTotalSupply = generalStakeData.stakeTokenTotalSupply;
    data.stakeCooldownSeconds = generalStakeData.stakeCooldownSeconds;
    data.stakeUnstakeWindow = generalStakeData.stakeUnstakeWindow;
    data.rewardTokenPriceEth = generalStakeData.rewardTokenPriceEth;
    data.intialSupply = generalStakeData.intialSupply;
    data.inflactionStart = generalStakeData.inflactionStart;
    data.decayRatio = generalStakeData.decayRatio;

    if (user != address(0)) {
      UserStakeUIData memory userStakeData =
        _getUserStakedAssetData(stakeToken, underlyingToken, user, isNonceAvailable);
      data.underlyingTokenUserBalance = userStakeData.underlyingTokenUserBalance;
      data.stakeTokenUserBalance = userStakeData.stakeTokenUserBalance;
      data.userIncentivesToClaim = userStakeData.userIncentivesToClaim;
      data.userCooldown = userStakeData.userCooldown;
      data.userPermitNonce = userStakeData.userPermitNonce;
    }

    return data;
  }

  function _getUserStakedAssetData(
    IStakedToken stakeToken,
    address underlyingToken,
    address user,
    bool isNonceAvailable
  ) internal view returns (UserStakeUIData memory) {
    UserStakeUIData memory data;
    data.underlyingTokenUserBalance = IERC20(underlyingToken).balanceOf(user);
    data.stakeTokenUserBalance = stakeToken.balanceOf(user);
    data.userIncentivesToClaim = stakeToken.getTotalRewardsBalance(user);
    data.userPermitNonce = isNonceAvailable ? IERC20WithNonce(underlyingToken)._nonces(user) : 0;
    return data;
  }

  function _getGeneralStakedAssetData(IStakedToken stakeToken)
    internal
    view
    returns (GeneralStakeUIData memory)
  {
    GeneralStakeUIData memory data;

    data.stakeTokenTotalSupply = stakeToken.totalSupply();
    data.stakeCooldownSeconds = stakeToken.COOLDOWN_SECONDS();
    data.stakeUnstakeWindow = stakeToken.UNSTAKE_WINDOW();
    data.rewardTokenPriceEth = PRICE_ORACLE.getAssetPrice(SIO2);
    data.intialSupply = stakeToken.assets(address(stakeToken)).intialSupply;
    data.inflactionStart = stakeToken.assets(address(stakeToken)).inflactionStart;
    data.decayRatio = stakeToken.assets(address(stakeToken)).decayRatio;

    return data;
  }

  function _calculateApy(
    uint256 inflactionStart, 
    uint256 intialSupply, 
    uint256 decayRatio,
    uint256 stakeTokenTotalSupply)
    internal
    view
    returns (uint256)
  {
    if (stakeTokenTotalSupply == 0) {
      return 0;
    }

    uint256 curDecayRatio = decayRatio._decPow(
        block.timestamp.sub(inflactionStart).div(SECONDS_PER_MONTH));
    uint256 distributionPerMonth = intialSupply.mul(curDecayRatio).div(SafeDecimalMath.DECIMAL_PRECISION);
    uint256 distributionPerSecond = distributionPerMonth.div(SECONDS_PER_MONTH);
    return (distributionPerSecond * SECONDS_PER_YEAR * APY_PRECISION) / stakeTokenTotalSupply;
  }

  function getStkSiO2Data(address user) public view override returns (AssetUIData memory) {
    AssetUIData memory data = _getUserAndGeneralStakedAssetData(STAKED_SIO2, SIO2, user, false);

    data.stakeTokenPriceEth = data.rewardTokenPriceEth;
    data.stakeApy = _calculateApy(
      data.inflactionStart, 
      data.intialSupply,
      data.decayRatio,
      data.stakeTokenTotalSupply);
    return data;
  }

  function getStkGeneralSiO2Data() public view override returns (GeneralStakeUIData memory) {
    GeneralStakeUIData memory data = _getGeneralStakedAssetData(STAKED_SIO2);

    data.stakeTokenPriceEth = data.rewardTokenPriceEth;
    data.stakeApy = _calculateApy( 
      data.inflactionStart, 
      data.intialSupply,
      data.decayRatio,
      data.stakeTokenTotalSupply);
    return data;
  }

  function getStkUserSiO2Data(address user) public view override returns (UserStakeUIData memory) {
    UserStakeUIData memory data = _getUserStakedAssetData(STAKED_SIO2, SIO2, user, false);
    return data;
  }

  function getUserUIData(address user)
    external
    view
    override
    returns (AssetUIData memory, uint256)
  {
    uint256 usdPrice = PRICE_ORACLE.getAssetPrice(MOCK_USD_ADDRESS);
    uint256 price = 0 == usdPrice ? 1 : usdPrice;
    return (getStkSiO2Data(user), USD_BASE / price);
  }

  function getGeneralStakeUIData()
    external
    view
    override
    returns (GeneralStakeUIData memory, uint256)
  {
    uint256 usdPrice = PRICE_ORACLE.getAssetPrice(MOCK_USD_ADDRESS);
    uint256 price = 0 == usdPrice ? 1 : usdPrice;
    return (getStkGeneralSiO2Data(), USD_BASE / price);
  }

  function getUserStakeUIData(address user)
    external
    view
    override
    returns (UserStakeUIData memory, uint256)
  {
    uint256 usdPrice = PRICE_ORACLE.getAssetPrice(MOCK_USD_ADDRESS);
    uint256 price = 0 == usdPrice ? 1 : usdPrice;
    return (getStkUserSiO2Data(user), USD_BASE / price);
  }
}
