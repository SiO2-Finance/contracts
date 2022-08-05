// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

interface StakeUIHelperI {
  struct AssetUIData {
    uint256 stakeTokenTotalSupply;
    uint256 stakeCooldownSeconds;
    uint256 stakeUnstakeWindow;
    uint256 stakeTokenPriceEth;
    uint256 rewardTokenPriceEth;
    uint256 stakeApy;
    uint256 stakeTokenUserBalance;
    uint256 underlyingTokenUserBalance;
    uint256 userCooldown;
    uint256 userIncentivesToClaim;
    uint256 userPermitNonce;
    uint256 intialSupply;
    uint256 inflactionStart;
    uint256 decayRatio;
  }

  struct GeneralStakeUIData {
    uint256 stakeTokenTotalSupply;
    uint256 stakeCooldownSeconds;
    uint256 stakeUnstakeWindow;
    uint256 stakeTokenPriceEth;
    uint256 rewardTokenPriceEth;
    uint256 stakeApy;
    uint256 intialSupply;
    uint256 inflactionStart;
    uint256 decayRatio;
  }

  struct UserStakeUIData {
    uint256 stakeTokenUserBalance;
    uint256 underlyingTokenUserBalance;
    uint256 userCooldown;
    uint256 userIncentivesToClaim;
    uint256 userPermitNonce;
  }

  function getStkSiO2Data(address user) external view returns (AssetUIData memory);

  function getStkGeneralSiO2Data() external view returns (GeneralStakeUIData memory);

  function getStkUserSiO2Data(address user) external view returns (UserStakeUIData memory);

  /// @dev This will return user + general for fallback
  function getUserUIData(address user) external view returns (AssetUIData memory, uint256);

  function getGeneralStakeUIData() external view returns (GeneralStakeUIData memory, uint256);

  function getUserStakeUIData(address user) external view returns (UserStakeUIData memory, uint256);
}
