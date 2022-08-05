// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;

interface IStakedSiO2V4 {
  function stake(
    address to,
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
}
