// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;
pragma experimental ABIEncoderV2;

import {IIncentivesController} from '../interfaces/IIncentivesController.sol';
import {DistributionTypes} from '../lib/DistributionTypes.sol';
import {ISToken} from '../interfaces/ISToken.sol';

contract STokenMock is ISToken {
  IIncentivesController public _ic;
  uint256 internal _userBalance;
  uint256 internal _totalSupply;

  // hack to be able to test event from EI properly
  event RewardsAccrued(address indexed user, uint256 amount);

  // hack to be able to test event from Distribution manager properly
  event AssetConfigUpdated(address indexed asset, uint256 emission);
  event AssetIndexUpdated(address indexed asset, uint256 index);
  event UserIndexUpdated(address indexed user, address indexed asset, uint256 index);

  constructor(IIncentivesController ic) public {
    _ic = ic;
  }

  function handleActionOnAic(
    address user,
    uint256 userBalance,
    uint256 totalSupply
  ) external {
    _ic.handleAction(user, userBalance, totalSupply);
  }

  function setUserBalanceAndSupply(uint256 userBalance, uint256 totalSupply) public {
    _userBalance = userBalance;
    _totalSupply = totalSupply;
  }

  function getScaledUserBalanceAndSupply(address user)
    external
    view
    override
    returns (uint256, uint256)
  {
    return (_userBalance, _totalSupply);
  }

  function cleanUserState() external {
    _userBalance = 0;
    _totalSupply = 0;
  }
}
