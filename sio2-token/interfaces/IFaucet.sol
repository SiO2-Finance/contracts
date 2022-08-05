// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.11;

interface IFaucet {
    struct ClaimAssetsInfo {
        string asset;
        address addr;
        uint256 frozenDuration;
        uint256 maxToClaimed;
    }

    function addAssets(ClaimAssetsInfo[] memory _assets) external virtual;

    function claim(string memory _asset) external virtual;
}