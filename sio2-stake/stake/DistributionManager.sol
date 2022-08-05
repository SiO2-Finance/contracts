// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;
pragma experimental ABIEncoderV2;

import {Math} from '../lib/Math.sol';
import {SafeMath} from '../lib/SafeMath.sol';
import {SafeDecimalMath} from '../lib/SafeDecimalMath.sol';
import {DistributionTypes} from '../lib/DistributionTypes.sol';
import {IDistributionManager} from '../interfaces/IDistributionManager.sol';

/**
 * @title DistributionManager
 * @notice Accounting contract to manage multiple staking distributions
 * @author SiO2
 **/
contract DistributionManager is IDistributionManager {
  using Math for uint256;
  using SafeMath for uint256;
  using SafeDecimalMath for uint256;

  // 30 days per month
  uint256 immutable SECONDS_PER_MONTH = 2_592_000;

  // each round is 98% of the last round **18
  uint256 immutable DEFAULT_DECAY_RATIO = 980_000_000_000_000_000;

  struct AssetData {
    // intial release amount at T0
    uint256 intialSupply;
    // when the inflaction start,default to time-point when the under-assets setup
    uint256 inflactionStart;
    // decay_ratio by month, default to 20% per-month
    uint256 decayRatio;
    uint128 lastUpdateTimestamp;
    uint256 index;
    mapping(address => uint256) users;
  }

  struct DebugInfo {
    address user;
    address sender;
    address asset;
    uint256 balance;
    uint256 total;
    uint256 lastUpdate;
    uint256 updateNow;
    uint256 oldIndex;
    uint256 newIndex;
  }

  DebugInfo[] public debug;

  address public immutable EMISSION_MANAGER;

  uint8 public constant PRECISION = 18;

  mapping(address => AssetData) public assets;

  event AssetConfigUpdated(address indexed asset, uint256 intialSupply);
  event AssetIndexUpdated(address indexed asset, uint256 index);
  event UserIndexUpdated(address indexed user, address indexed asset, uint256 index);

  constructor(address emissionManager) public {
    EMISSION_MANAGER = emissionManager;
  }

  /**
   * @dev Configures the distribution of rewards for a list of assets
   * @param assetsConfigInput The list of configurations to apply
   **/
  function configureAssets(DistributionTypes.AssetConfigInput[] calldata assetsConfigInput)
    external
    override
  {
    require(msg.sender == EMISSION_MANAGER, 'ONLY_EMISSION_MANAGER'); // only location of use EMISSION_MANAGER

    for (uint256 i = 0; i < assetsConfigInput.length; i++) {
      AssetData storage assetConfig = assets[assetsConfigInput[i].underlyingAsset];

      _updateAssetStateInternal(
        assetsConfigInput[i].underlyingAsset,
        assetConfig,
        assetsConfigInput[i].totalStaked
      );

      assetConfig.intialSupply = assetsConfigInput[i].intialSupply;
      require(
        assetsConfigInput[i].decayRatio <= SafeDecimalMath.DECIMAL_PRECISION,
        'INVLID_DECAY_RATIO'
      );
      assetConfig.decayRatio = assetsConfigInput[i].decayRatio;
      assetConfig.inflactionStart = block.timestamp;

      emit AssetConfigUpdated(
        assetsConfigInput[i].underlyingAsset,
        assetsConfigInput[i].intialSupply
      );
    }
  }

  /**
   * @dev Updates the state of one distribution, mainly rewards index and timestamp
   * @param underlyingAsset The address used as key in the distribution, for example sSiO2 or the aTokens addresses on SiO2
   * @param assetConfig Storage pointer to the distribution's config
   * @param totalStaked Current total of staked assets for this distribution
   * @return The new distribution index
   **/
  function _updateAssetStateInternal(
    address underlyingAsset,
    AssetData storage assetConfig,
    uint256 totalStaked
  ) internal returns (uint256) {
    uint256 oldIndex = assetConfig.index;
    uint128 lastUpdateTimestamp = assetConfig.lastUpdateTimestamp;

    if (block.timestamp == lastUpdateTimestamp) {
      return oldIndex;
    }

    uint256 newIndex =
      _getAssetIndex(
        oldIndex,
        assetConfig.intialSupply,
        assetConfig.inflactionStart,
        assetConfig.decayRatio,
        lastUpdateTimestamp,
        totalStaked
      );

    if (newIndex != oldIndex) {
      assetConfig.index = newIndex;
      emit AssetIndexUpdated(underlyingAsset, newIndex);
    }

    assetConfig.lastUpdateTimestamp = uint128(block.timestamp);

    return newIndex;
  }

  function getDebugInfo() public returns (DebugInfo[] memory) {
    return debug;
  }

  /**
   * @dev Updates the state of an user in a distribution
   * @param user The user's address
   * @param asset The address of the reference asset of the distribution
   * @param stakedByUser Amount of tokens staked by the user in the distribution at the moment
   * @param totalStaked Total tokens staked in the distribution
   * @return The accrued rewards for the user until the moment
   **/
  function _updateUserAssetInternal(
    address user,
    address asset,
    uint256 stakedByUser,
    uint256 totalStaked
  ) internal returns (uint256) {
    AssetData storage assetData = assets[asset];
    uint256 userIndex = assetData.users[user];
    uint256 accruedRewards = 0;

    DebugInfo memory info =
      DebugInfo({
        user: user,
        sender: msg.sender,
        asset: asset,
        balance: stakedByUser,
        total: totalStaked,
        lastUpdate: assetData.lastUpdateTimestamp,
        updateNow: block.timestamp,
        oldIndex: assetData.index,
        newIndex: 0
      });

    uint256 newIndex = _updateAssetStateInternal(asset, assetData, totalStaked);

    info.newIndex = newIndex;
    debug.push(info);

    if (userIndex != newIndex) {
      if (stakedByUser != 0) {
        accruedRewards = _getRewards(stakedByUser, newIndex, userIndex);
      }

      assetData.users[user] = newIndex;
      emit UserIndexUpdated(user, asset, newIndex);
    }

    return accruedRewards;
  }

  /**
   * @dev Used by "frontend" stake contracts to update the data of an user when claiming rewards from there
   * @param user The address of the user
   * @param stakes List of structs of the user data related with his stake
   * @return The accrued rewards for the user until the moment
   **/
  function _claimRewards(address user, DistributionTypes.UserStakeInput[] memory stakes)
    internal
    returns (uint256)
  {
    uint256 accruedRewards = 0;

    for (uint256 i = 0; i < stakes.length; i++) {
      accruedRewards = accruedRewards.add(
        _updateUserAssetInternal(
          user,
          stakes[i].underlyingAsset,
          stakes[i].stakedByUser,
          stakes[i].totalStaked
        )
      );
    }

    return accruedRewards;
  }

  /**
   * @dev Return the accrued rewards for an user over a list of distribution
   * @param user The address of the user
   * @param stakes List of structs of the user data related with his stake
   * @return The accrued rewards for the user until the moment
   **/
  function _getUnclaimedRewards(address user, DistributionTypes.UserStakeInput[] memory stakes)
    internal
    view
    returns (uint256)
  {
    uint256 accruedRewards = 0;

    for (uint256 i = 0; i < stakes.length; i++) {
      AssetData storage assetConfig = assets[stakes[i].underlyingAsset];
      uint256 assetIndex =
        _getAssetIndex(
          assetConfig.index,
          assetConfig.intialSupply,
          assetConfig.inflactionStart,
          assetConfig.decayRatio,
          assetConfig.lastUpdateTimestamp,
          stakes[i].totalStaked
        );

      accruedRewards = accruedRewards.add(
        _getRewards(stakes[i].stakedByUser, assetIndex, assetConfig.users[user])
      );
    }
    return accruedRewards;
  }

  /**
   * @dev Internal function for the calculation of user's rewards on a distribution
   * @param principalUserBalance Amount staked by the user on a distribution
   * @param reserveIndex Current index of the distribution
   * @param userIndex Index stored for the user, representation his staking moment
   * @return The rewards
   **/
  function _getRewards(
    uint256 principalUserBalance,
    uint256 reserveIndex,
    uint256 userIndex
  ) internal pure returns (uint256) {
    return principalUserBalance.mul(reserveIndex.sub(userIndex)).div(10**uint256(PRECISION));
  }

  /**
   * @dev Calculates the next value of an specific distribution index, with validations
   * @param currentIndex Current index of the distribution
   * @param intialSupply The supply at the first month
   * @param inflactionStart When inflaction start
   * @param decayRatio The decay ratio
   * @param lastUpdateTimestamp Last moment this distribution was updated
   * @param totalBalance of tokens considered for the distribution
   * @return The new index.
   **/
  function _getAssetIndex(
    uint256 currentIndex,
    uint256 intialSupply,
    uint256 inflactionStart,
    uint256 decayRatio,
    uint128 lastUpdateTimestamp,
    uint256 totalBalance
  ) internal view returns (uint256) {
    if (
      totalBalance == 0 ||
      lastUpdateTimestamp == 0 ||
      lastUpdateTimestamp == block.timestamp ||
      inflactionStart == block.timestamp
    ) {
      return currentIndex;
    }

    uint256 cumulativeDelta = _getCumulativeDelta(inflactionStart, decayRatio, lastUpdateTimestamp);
    return intialSupply.mul(cumulativeDelta).div(totalBalance).add(currentIndex);
  }

  /**
   * @dev Returns the inflaction delta since last update
   * @param inflactionStart The inflaction start
   * @param decayRatio The decay ratio
   * @return lastUpdateTimestamp The last udpate timestamp
   **/
  function _getCumulativeDelta(
    uint256 inflactionStart,
    uint256 decayRatio,
    uint256 lastUpdateTimestamp
  ) internal view returns (uint256) {
    uint256 cumulativeDelta = 0;

    require(block.timestamp >= inflactionStart, 'INVALID_INFLACTION_START');

    // scope to avoid stack too deep
    {
      uint256 lastSpan = Math.max(lastUpdateTimestamp, inflactionStart).sub(inflactionStart);
      uint256 curSpan = block.timestamp.sub(inflactionStart);
      uint256 lastDecayPeriod = lastSpan.div(SECONDS_PER_MONTH);
      uint256 curDecayPeriod = curSpan.div(SECONDS_PER_MONTH);

      for (uint256 cur = curDecayPeriod; cur >= lastDecayPeriod; ) {
        uint256 tail = Math.max(lastSpan, cur.mul(SECONDS_PER_MONTH));

        cumulativeDelta = cumulativeDelta.add(
          curSpan.sub(tail).mul(SafeDecimalMath.DECIMAL_PRECISION).div(SECONDS_PER_MONTH).mul(
            decayRatio._decPow(cur)
          )
        );

        if (0 == cur) {
          break;
        } else {
          curSpan = cur.mul(SECONDS_PER_MONTH);
          cur--;
        }
      }
    }

    return cumulativeDelta.div(SafeDecimalMath.DECIMAL_PRECISION);
  }

  /**
   * @dev Returns the data of an user on a distribution
   * @param user Address of the user
   * @param asset The address of the reference asset of the distribution
   * @return The new index
   **/
  function getUserAssetData(address user, address asset) public view returns (uint256) {
    return assets[asset].users[user];
  }
}
