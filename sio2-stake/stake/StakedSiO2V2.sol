// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;
pragma experimental ABIEncoderV2;

import {IERC20} from '../interfaces/IERC20.sol';
import {StakedTokenV2} from './StakedTokenV2.sol';

/**
 * @title StakedSiO2V2
 * @notice StakedTokenV2 with SiO2 token as staked token
 * @author SiO2
 **/
contract StakedSiO2V2 is StakedTokenV2 {
  string internal constant NAME = 'Staked SiO2';
  string internal constant SYMBOL = 'sSiO2';
  uint8 internal constant DECIMALS = 18;

  constructor(
    IERC20 stakedToken,
    IERC20 rewardToken,
    uint256 cooldownSeconds,
    uint256 unstakeWindow,
    address rewardsVault,
    address emissionManager,
    address governance
  )
    public
    StakedTokenV2(
      stakedToken,
      rewardToken,
      cooldownSeconds,
      unstakeWindow,
      rewardsVault,
      emissionManager,
      NAME,
      SYMBOL,
      DECIMALS,
      governance
    )
  {}
}
