// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;
pragma experimental ABIEncoderV2;

import {IERC20} from '../interfaces/IERC20.sol';
import {StakedTokenV4} from './StakedTokenV4.sol';

/**
 * @title StakedSiO2
 * @notice StakedToken with SiO2 token as staked token
 * @author SiO2
 **/
contract StakedSiO2V4 is StakedTokenV4 {
  string internal constant NAME = 'Staked SiO2';
  string internal constant SYMBOL = 'vSiO2';
  uint8 internal constant DECIMALS = 18;

  constructor(
    IERC20 stakedToken,
    IERC20 rewardToken,
    uint256 cooldownSeconds,
    uint256 unstakeWindow,
    address rewardsVault,
    address emissionManager
  )
    public
    StakedTokenV4(
      stakedToken,
      rewardToken,
      cooldownSeconds,
      unstakeWindow,
      rewardsVault,
      emissionManager,
      NAME,
      SYMBOL,
      DECIMALS
    )
  {}
}
