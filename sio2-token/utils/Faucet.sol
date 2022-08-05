// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.11;

import {IERC20} from "../interfaces/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeMath} from "../open-zeppelin/SafeMath.sol";
import {IFaucet} from "../interfaces/IFaucet.sol";

contract Faucet is IFaucet, Ownable{
    using SafeMath for uint256;

    mapping(string => ClaimAssetsInfo) public assets;
    mapping(address=> mapping(string => uint256)) public lastClaimedStamp;

    function addAssets(ClaimAssetsInfo[] memory _assets) public override onlyOwner {
        for(uint256 i = 0; i < _assets.length; i++){
            require(address(0) != _assets[i].addr, "INVALID_ADDRESS");
            assets[_assets[i].asset] = _assets[i];
        }
    }

    function claim(string memory _asset) public override {
        ClaimAssetsInfo storage info = assets[_asset];
        require(address(0) != info.addr, "INVALID_ASSET");
        require(block.timestamp > info.frozenDuration.add(lastClaimedStamp[msg.sender][_asset]), "UNABLE_TO_CLAIM");
        IERC20 asset = IERC20(assets[_asset].addr);
        asset.transfer(msg.sender, info.maxToClaimed);
        lastClaimedStamp[msg.sender][_asset] = block.timestamp;
    }
}