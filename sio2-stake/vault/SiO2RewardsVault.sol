pragma solidity 0.7.5;

import {IERC20} from '../interfaces/IERC20.sol';
import {Ownable} from '../lib/Ownable.sol';

contract SiO2RewardsVault is Ownable {
  address public incentiveController;

  function setIncentiveController(address _incentiveController) external onlyOwner {
    incentiveController = _incentiveController;
  }

  function transfer(IERC20 token, uint256 amount) external onlyOwner {
    token.transfer(incentiveController, amount);
  }
}
