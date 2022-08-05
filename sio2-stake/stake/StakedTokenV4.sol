// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;
pragma experimental ABIEncoderV2;

import {IERC20} from '../interfaces/IERC20.sol';
import {IStakedSiO2V4} from '../interfaces/IStakedSiO2V4.sol';
import {ITransferHook} from '../interfaces/ITransferHook.sol';
import {ERC20WithSnapshot} from '../lib/ERC20WithSnapshot.sol';
import {SafeERC20} from '../lib/SafeERC20.sol';
import {VersionedInitializable} from '../utils/VersionedInitializable.sol';
import {DistributionTypes} from '../lib/DistributionTypes.sol';
import {DistributionManager} from './DistributionManager.sol';
import {SafeMath} from '../lib/SafeMath.sol';

/**
 * @title StakedToken
 * @notice Contract to stake SiO2 token, tokenize the position and get rewards, inheriting from a distribution manager contract
 * @author SiO2
 **/
contract StakedTokenV4 is
  IStakedSiO2V4,
  ERC20WithSnapshot,
  VersionedInitializable,
  DistributionManager
{
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  struct StakeInfo {
    // the time point when staken
    uint256 start;
    // the chosen stake mode
    uint256 mode;
    // the staken amount
    uint256 amount;
    // cool down
    uint256 coolDown;
  }

  uint256 public constant REVISION = 1;

  IERC20 public immutable STAKED_TOKEN;
  IERC20 public immutable REWARD_TOKEN;
  uint256 public COOLDOWN_SECONDS;

  // seconds of 360 days
  uint256 public immutable MIN_FROZEN_SECONDS = 31_104_000;

  uint256 public immutable STAKE_MODE_A = 1;
  uint256 public immutable STAKE_MODE_B = 2;
  uint256 public immutable STAKE_MODE_C = 3;

  // staken mode multiplier
  uint256 public immutable STAKE_MODE_A_MUL = 2;
  uint256 public immutable STAKE_MODE_B_MUL = 4;
  uint256 public immutable STAKE_MODE_C_MUL = 8;

  /// @notice Seconds available to redeem once the cooldown period is fullfilled
  uint256 public immutable UNSTAKE_WINDOW;

  /// @notice Address to pull from the rewards, needs to have approved this contract
  address public immutable REWARDS_VAULT;

  mapping(address => uint256) public stakerRewardsToClaim;
  mapping(address => StakeInfo[]) internal stakeInfo;

  event Staked(
    address indexed from,
    address indexed onBehalfOf,
    uint256 index,
    uint256 mode,
    uint256 amount
  );
  event Redeem(address indexed from, address indexed to, uint256 index, uint256 amount);

  event RewardsAccrued(address user, uint256 amount);
  event RewardsClaimed(address indexed from, address indexed to, uint256 amount);

  event Cooldown(address indexed user, uint256 index);

  constructor(
    IERC20 stakedToken,
    IERC20 rewardToken,
    uint256 cooldownSeconds,
    uint256 unstakeWindow,
    address rewardsVault,
    address emissionManager,
    string memory name,
    string memory symbol,
    uint8 decimals
  ) public ERC20WithSnapshot(name, symbol, decimals) DistributionManager(emissionManager) {
    STAKED_TOKEN = stakedToken;
    REWARD_TOKEN = rewardToken;
    COOLDOWN_SECONDS = cooldownSeconds;
    UNSTAKE_WINDOW = unstakeWindow;
    REWARDS_VAULT = rewardsVault;
  }

  /**
   * @dev Called by the proxy contract
   **/
  function initialize(
    ITransferHook governance,
    string calldata name,
    string calldata symbol,
    uint8 decimals
  ) external initializer {
    _setName(name);
    _setSymbol(symbol);
    _setDecimals(decimals);
    _setGovernance(governance);
  }

  /**
   * @dev Stake tokens, and start earning rewards
   * @param onBehalfOf Address to redeem to
   * @param amount Amount to stake
   * @param mode Indicate the staking duration. 1: one year, 2: two years, 3: three years
   **/
  function stake(
    address onBehalfOf,
    uint256 amount,
    uint256 mode
  ) external override {
    require(amount != 0, 'INVALID_ZERO_AMOUNT');

    // check staken mode
    require(mode >= STAKE_MODE_A && mode <= STAKE_MODE_C, 'INVALID_STAKE_MODE');

    require(IERC20(STAKED_TOKEN).balanceOf(msg.sender) >= amount, 'INSUFFICIENT_FUNDS');

    uint256 balanceOfUser = balanceOf(onBehalfOf);
    uint256 accruedRewards =
      _updateUserAssetInternal(onBehalfOf, address(this), balanceOfUser, totalSupply());
    if (accruedRewards != 0) {
      emit RewardsAccrued(onBehalfOf, accruedRewards);
      stakerRewardsToClaim[onBehalfOf] = stakerRewardsToClaim[onBehalfOf].add(accruedRewards);
    }

    // more rewards if staken longer
    IERC20(STAKED_TOKEN).safeTransferFrom(msg.sender, address(this), amount); // Switch the order for safety reasons
    _mint(onBehalfOf, _powerAmount(mode, amount));

    stakeInfo[onBehalfOf].push(
      StakeInfo({start: block.timestamp, mode: mode, amount: amount, coolDown: 0})
    );

    emit Staked(msg.sender, onBehalfOf, stakeInfo[onBehalfOf].length - 1, mode, amount);
  }

  /**
   * @dev Redeems staked tokens, and stop earning rewards
   * @param to Address to redeem to
   **/
  function redeemAll(address to) external virtual {
    StakeInfo[] storage stakes = stakeInfo[msg.sender];

    if (stakes.length > 0) {
      for (uint256 i = stakes.length - 1; i >= 0; ) {
        redeem(to, i, stakes[i].amount);

        // avoid substraction overflow
        if (i <= 0) {
          break;
        } else {
          i--;
        }
      }
    }
  }

  function _powerAmount(uint256 mode, uint256 amount) internal pure returns (uint256) {
    if (STAKE_MODE_A == mode) {
      return amount.mul(STAKE_MODE_A_MUL);
    }
    if (STAKE_MODE_B == mode) {
      return amount.mul(STAKE_MODE_B_MUL);
    } else {
      return amount.mul(STAKE_MODE_C_MUL);
    }
  }

  /**
   * @dev Redeems staked tokens, and stop earning rewards
   * @param to Address to redeem to
   * @param amount Amount to redeem
   **/
  function redeem(
    address to,
    uint256 index,
    uint256 amount
  ) public override {
    require(amount != 0, 'INVALID_ZERO_AMOUNT');

    StakeInfo storage userInfo = _getStakeInfo(msg.sender, index);

    // check due date
    require(
      block.timestamp > (userInfo.start + userInfo.mode.mul(MIN_FROZEN_SECONDS)),
      'WITHIN_DUE_DATE'
    );

    //solium-disable-next-line
    // uint256 cooldownStartTimestamp = userInfo.coolDown;
    // require(
    //   block.timestamp > cooldownStartTimestamp.add(COOLDOWN_SECONDS),
    //   'INSUFFICIENT_COOLDOWN'
    // );
    // require(
    //   block.timestamp.sub(cooldownStartTimestamp.add(COOLDOWN_SECONDS)) <= UNSTAKE_WINDOW,
    //   'UNSTAKE_WINDOW_FINISHED'
    // );

    uint256 amountToRedeem = (amount > userInfo.amount) ? userInfo.amount : amount;
    uint256 powerAmount = _powerAmount(userInfo.mode, amountToRedeem);
    _updateCurrentUnclaimedRewards(msg.sender, balanceOf(msg.sender), true);
    _burn(msg.sender, powerAmount);

    _redeemAmount(to, index, amountToRedeem);
    IERC20(STAKED_TOKEN).safeTransfer(to, amountToRedeem);

    emit Redeem(msg.sender, to, index, amountToRedeem);
  }

  /**
   * @dev Get stake info by index
   * @param staker Staker address
   * @param index The index of stake info
   **/
  function getStakeInfo(address staker, uint256 index) public view returns (StakeInfo memory) {
    return _getStakeInfo(staker, index);
  }

  /**
   * @dev Get user stake info
   * @param staker Staker address
   **/
  function getAllStakeInfos(address staker) public view returns (StakeInfo[] memory) {
    return stakeInfo[staker];
  }

  /**
   * @dev Get user stake info size
   * @param staker Staker address
   **/
  function getStakeInfoSize(address staker) public view returns (uint256) {
    return stakeInfo[staker].length;
  }

  /**
   * @dev Get user stake info
   * @param staker Staker address
   * @param pageSt The page start
   * @param size The page size
   **/
  function getStakeInfosByPage(
    address staker,
    uint256 pageSt,
    uint256 size
  ) public view returns (StakeInfo[] memory) {
    StakeInfo[] storage infos = stakeInfo[staker];
    StakeInfo[] memory ret;

    if (pageSt < infos.length) {
      uint256 end = pageSt + size;
      end = end > infos.length ? infos.length : end;
      ret = new StakeInfo[](end - pageSt);
      for (uint256 i = 0; pageSt < end; i++) {
        ret[i] = infos[pageSt];
        pageSt++;
      }
    }

    return ret;
  }

  function _getStakeInfo(address staker, uint256 index) internal view returns (StakeInfo storage) {
    require(stakeInfo[staker].length > index, 'INVALID_STAKE_INDEX');
    return stakeInfo[staker][index];
  }

  /**
   * @dev Activates the cooldown period to unstake
   * - It can't be called if the user is not staking
   **/
  function cooldown(uint256 index) external override {
    require(balanceOf(msg.sender) != 0, 'INVALID_BALANCE_ON_COOLDOWN');

    //solium-disable-next-line
    StakeInfo storage userInfo = _getStakeInfo(msg.sender, index);

    require(
      block.timestamp > (userInfo.start + userInfo.mode.mul(MIN_FROZEN_SECONDS)),
      'WITHIN_DUE_DATE'
    );

    userInfo.coolDown = block.timestamp;

    emit Cooldown(msg.sender, index);
  }

  /**
   * @dev Claims an `amount` of `REWARD_TOKEN` to the address `to`
   * @param to Address to stake for
   * @param amount Amount to stake
   **/
  function claimRewards(address to, uint256 amount) external override {
    uint256 newTotalRewards =
      _updateCurrentUnclaimedRewards(msg.sender, balanceOf(msg.sender), false);
    uint256 amountToClaim = (amount == type(uint256).max) ? newTotalRewards : amount;

    stakerRewardsToClaim[msg.sender] = newTotalRewards.sub(amountToClaim, 'INVALID_AMOUNT');

    REWARD_TOKEN.safeTransferFrom(REWARDS_VAULT, to, amountToClaim); // only location of use REWARDS_VAULT https://docs.openzeppelin.com/contracts/3.x/api/token/erc721#IERC721-safeTransferFrom-address-address-uint256-

    emit RewardsClaimed(msg.sender, to, amountToClaim);
  }

  /**
   * @dev forbidden transferring staken tokens
   * @param from Address to transfer from
   * @param to Address to transfer to
   * @param amount Amount to transfer
   **/
  function _transfer(
    address from,
    address to,
    uint256 amount
  ) internal override {
    revert('TRANSFER_FORBIDDEN');
  }

  /**
   * @dev Updates the user amount
   * @param to Address of the user
   * @param index The current slot index of stake info
   * @param amountToRedeem The amount to redeem
   **/
  function _redeemAmount(
    address to,
    uint256 index,
    uint256 amountToRedeem
  ) internal {
    StakeInfo[] storage stakes = stakeInfo[to];
    StakeInfo storage userInfo = stakes[index];

    userInfo.amount = userInfo.amount.sub(amountToRedeem);
    if (userInfo.amount == 0) {
      for (uint256 i = index; i < stakes.length - 1; i++) {
        stakes[i] = stakes[i + 1];
      }
      stakes.pop();
    }
  }

  /**
   * @dev Updates the user state related with his accrued rewards
   * @param user Address of the user
   * @param userBalance The current balance of the user
   * @param updateStorage Boolean flag used to update or not the stakerRewardsToClaim of the user
   * @return The unclaimed rewards that were added to the total accrued
   **/
  function _updateCurrentUnclaimedRewards(
    address user,
    uint256 userBalance,
    bool updateStorage
  ) internal returns (uint256) {
    uint256 accruedRewards =
      _updateUserAssetInternal(user, address(this), userBalance, totalSupply());
    uint256 unclaimedRewards = stakerRewardsToClaim[user].add(accruedRewards);

    if (accruedRewards != 0) {
      if (updateStorage) {
        stakerRewardsToClaim[user] = unclaimedRewards;
      }
      emit RewardsAccrued(user, accruedRewards);
    }

    return unclaimedRewards;
  }

  /**
   * @dev Return the total rewards pending to claim by an staker
   * @param staker The staker address
   * @return The rewards
   */
  function getTotalRewardsBalance(address staker) external view returns (uint256) {
    DistributionTypes.UserStakeInput[] memory userStakeInputs =
      new DistributionTypes.UserStakeInput[](1);
    userStakeInputs[0] = DistributionTypes.UserStakeInput({
      underlyingAsset: address(this),
      stakedByUser: balanceOf(staker),
      totalStaked: totalSupply()
    });
    return stakerRewardsToClaim[staker].add(_getUnclaimedRewards(staker, userStakeInputs));
  }

  /**
   * @dev returns the revision of the implementation contract
   * @return The revision
   */
  function getRevision() internal pure override returns (uint256) {
    return REVISION;
  }
}
