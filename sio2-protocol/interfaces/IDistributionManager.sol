// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

interface IDistributionManager {

    struct AssetConfigInput {
    uint256 intialSupply;
    uint256 totalStaked;
    uint256 decayRatio;
    address underlyingAsset;
  }

  function EMISSION_MANAGER() external view returns(address);
  function configureAssets(AssetConfigInput[] calldata assetsConfigInput)
    external;
}

