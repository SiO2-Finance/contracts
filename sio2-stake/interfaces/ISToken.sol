pragma solidity ^0.7.5;

interface ISToken {
  function getScaledUserBalanceAndSupply(address user) external view returns (uint256, uint256);
}
