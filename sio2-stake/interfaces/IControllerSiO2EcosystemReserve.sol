pragma solidity ^0.7.5;

interface IControllerSiO2EcosystemReserve {
  function approve(
    address token,
    address recipient,
    uint256 amount
  ) external;
}
