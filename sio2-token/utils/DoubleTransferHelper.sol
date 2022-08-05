// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.11;

import "../interfaces/IERC20.sol";

contract DoubleTransferHelper {

    IERC20 public immutable SiO2;

    constructor(IERC20 sio2) public {
        SiO2 = sio2;
    }

    function doubleSend(address to, uint256 amount1, uint256 amount2) external {
        SiO2.transfer(to, amount1);
        SiO2.transfer(to, amount2);
    }
}