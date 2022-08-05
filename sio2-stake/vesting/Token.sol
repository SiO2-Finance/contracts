// contracts/Token.sol
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.7.5;

import {ERC20} from '../lib/ERC20.sol';

contract Token is ERC20 {
  constructor(
    string memory name,
    string memory symbol,
    uint256 initialSupply
  ) ERC20(name, symbol, 18) {
    _mint(msg.sender, initialSupply);
  }
}
