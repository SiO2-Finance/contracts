pragma solidity 0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SiO2RewardsVault is Ownable {

  address public incentiveController;
  function setIncentiveController(address _incentiveController) external onlyOwner {
      incentiveController = _incentiveController;
  }
  function transfer(
    IERC20 token,
    uint256 amount
  ) external onlyOwner {
    token.transfer(incentiveController, amount);
  }
}
