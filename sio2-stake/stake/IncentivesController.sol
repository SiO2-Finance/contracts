// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;
pragma experimental ABIEncoderV2;

import {DistributionTypes} from '../lib/DistributionTypes.sol';
import {SafeMath} from '../lib/SafeMath.sol';

import {IERC20} from '../interfaces/IERC20.sol';
import {ISToken} from '../interfaces/ISToken.sol';
import {IIncentivesController} from '../interfaces/IIncentivesController.sol';
import {VersionedInitializable} from '../utils/VersionedInitializable.sol';
import {DistributionManager} from './DistributionManager.sol';

/**
 * @title IncentivesController
 * @notice Distributor contract for rewards to the protocol
 * @author SiO2
 **/
contract IncentivesController is
  IIncentivesController,
  VersionedInitializable,
  DistributionManager
{
  using SafeMath for uint256;
  uint256 public constant REVISION = 1;

  IERC20 public immutable REWARD_TOKEN;
  address public immutable REWARDS_VAULT;

  mapping(address => uint256) internal _usersUnclaimedRewards;

  uint256[] public operations;

  event RewardsAccrued(address indexed user, uint256 amount);
  event RewardsClaimed(address indexed user, address indexed to, uint256 amount);

  constructor(
    IERC20 rewardToken,
    address rewardsVault,
    address emissionManager
  ) public DistributionManager(emissionManager) {
    REWARD_TOKEN = rewardToken;
    REWARDS_VAULT = rewardsVault;
  }

  function getOperations() public returns (uint256[] memory) {
    return operations;
  }

  /**
   * @dev Called by the corresponding asset on any update that affects the rewards distribution
   * @param user The address of the user
   * @param userBalance The balance of the user of the asset in the lending pool
   * @param totalSupply The total supply of the asset in the lending pool
   **/
  function handleAction(
    address user,
    uint256 totalSupply,
    uint256 userBalance
  ) external override {
    operations.push(1);
    uint256 accruedRewards = _updateUserAssetInternal(user, msg.sender, userBalance, totalSupply);
    if (accruedRewards != 0) {
      _usersUnclaimedRewards[user] = _usersUnclaimedRewards[user].add(accruedRewards);
      emit RewardsAccrued(user, accruedRewards);
    }
  }

  /**
   * @dev Returns the total of rewards of an user, already accrued + not yet accrued
   * @param user The address of the user
   * @return The rewards
   **/
  function getRewardsBalance(address[] calldata assets, address user)
    external
    view
    override
    returns (uint256)
  {
    uint256 unclaimedRewards = _usersUnclaimedRewards[user];

    DistributionTypes.UserStakeInput[] memory userState =
      new DistributionTypes.UserStakeInput[](assets.length);
    for (uint256 i = 0; i < assets.length; i++) {
      userState[i].underlyingAsset = assets[i];
      (userState[i].stakedByUser, userState[i].totalStaked) = (
        IERC20(assets[i]).balanceOf(user),
        IERC20(assets[i]).totalSupply()
      );
    }
    unclaimedRewards = unclaimedRewards.add(_getUnclaimedRewards(user, userState));
    return unclaimedRewards;
  }

  /**
   * @dev Claims reward for an user, on all the assets of the lending pool, accumulating the pending rewards
   * @param amount Amount of rewards to claim
   * @param to Address that will be receiving the rewards
   * @return Rewards claimed
   **/
  function claimRewards(
    address[] calldata assets,
    uint256 amount,
    address to
  ) external override returns (uint256) {
    if (amount == 0) {
      return 0;
    }
    operations.push(2);

    address user = msg.sender;
    uint256 unclaimedRewards = _usersUnclaimedRewards[user];

    DistributionTypes.UserStakeInput[] memory userState =
      new DistributionTypes.UserStakeInput[](assets.length);
    for (uint256 i = 0; i < assets.length; i++) {
      userState[i].underlyingAsset = assets[i];
      (userState[i].stakedByUser, userState[i].totalStaked) = ISToken(assets[i])
        .getScaledUserBalanceAndSupply(user);
    }

    uint256 accruedRewards = _claimRewards(user, userState);
    if (accruedRewards != 0) {
      unclaimedRewards = unclaimedRewards.add(accruedRewards);
      emit RewardsAccrued(user, accruedRewards);
    }

    if (unclaimedRewards == 0) {
      return 0;
    }

    uint256 amountToClaim = amount > unclaimedRewards ? unclaimedRewards : amount;
    _usersUnclaimedRewards[user] = unclaimedRewards - amountToClaim; // Safe due to the previous line

    REWARD_TOKEN.transferFrom(REWARDS_VAULT, to, amountToClaim);
    emit RewardsClaimed(msg.sender, to, amountToClaim);

    return amountToClaim;
  }

  /**
   * @dev returns the unclaimed rewards of the user
   * @param _user the address of the user
   * @return the unclaimed user rewards
   */
  function getUserUnclaimedRewards(address _user) external view returns (uint256) {
    return _usersUnclaimedRewards[_user];
  }

  /**
   * @dev returns the revision of the implementation contract
   */
  function getRevision() internal pure override returns (uint256) {
    return REVISION;
  }
}
