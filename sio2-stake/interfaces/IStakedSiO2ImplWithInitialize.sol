// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;

interface IStakedSiO2ImplWithInitialize {
  function initialize(
    address sio2Governance,
    string calldata name,
    string calldata symbol,
    uint8 decimals
  ) external;

  function stake(
    address onBehalfOf,
    uint256 amount,
    uint256 stakeMode
  ) external;

  function redeem(
    address to,
    uint256 index,
    uint256 amount
  ) external;

  function cooldown(uint256 index) external;

  function claimRewards(address to, uint256 amount) external;

  function balanceOf(address user) external view returns (uint256);
}
