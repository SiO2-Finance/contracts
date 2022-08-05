// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;

import '../interfaces/IEIP2612Token.sol';
import '../interfaces/ISiO2StakingHelper.sol';
import '../interfaces/IStakedSiO2ImplWithInitialize.sol';

/**
 * @title StakingHelper contract
 * @author SiO2
 * @dev implements a staking function that allows staking through the EIP2612 capabilities of the SIO2 token
 **/

contract SiO2StakingHelper is ISiO2StakingHelper {
  IStakedSiO2ImplWithInitialize public immutable STAKE;
  IEIP2612Token public immutable SIO2;

  constructor(address stake, address sio2) public {
    STAKE = IStakedSiO2ImplWithInitialize(stake);
    SIO2 = IEIP2612Token(sio2);
    //approves the stake to transfer uint256.max tokens from this contract
    //avoids approvals on every stake action
    IEIP2612Token(sio2).approve(address(stake), type(uint256).max);
  }

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
  ) external override {
    SIO2.permit(user, address(this), amount, type(uint256).max, v, r, s);
    SIO2.transferFrom(user, address(this), amount);
    STAKE.stake(user, amount, stakeMode);
  }
}
