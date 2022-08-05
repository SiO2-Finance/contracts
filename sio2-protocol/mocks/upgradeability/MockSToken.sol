// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {SToken} from '../../protocol/tokenization/SToken.sol';
import {ILendingPool} from '../../interfaces/ILendingPool.sol';
import {ISiO2IncentivesController} from '../../interfaces/ISiO2IncentivesController.sol';

contract MockSToken is SToken {
  function getRevision() internal pure override returns (uint256) {
    return 0x2;
  }
}
