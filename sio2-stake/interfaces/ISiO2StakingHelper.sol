// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;

interface ISiO2StakingHelper {
  /**
   * @dev stakes on behalf of msg.sender using signed approval.
   * The function expects a valid signed message from the user, and executes a permit()
   * to approve the transfer. The helper then stakes on behalf of the user
   * @param user the user for which the staking is being executed
   * @param amount the amount to stake
   * @param v signature param
   * @param r signature param
   * @param s signature param
   **/
  function stake(
    address user,
    uint256 amount,
    uint256 stakeMode,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external;
}
