// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.11;

import {SiO2Token} from '../SiO2Token.sol';

contract SiO2TokenTester is SiO2Token {
  function unprotectedMint(address _account, uint256 _amount) external {
    // No check on caller here
    _mint(_account, _amount);
  }

  function unprotectedBurn(address _account, uint _amount) external {
    // No check on caller here
    _burn(_account, _amount);
  }
}