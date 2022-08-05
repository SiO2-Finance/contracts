// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {ILendingPool} from './ILendingPool.sol';
import {ISiO2IncentivesController} from './ISiO2IncentivesController.sol';

/**
 * @title IInitializableSToken
 * @notice Interface for the initialize function on SToken
 * @author SiO2
 **/
interface IInitializableSToken {
  /**
   * @dev Emitted when an sToken is initialized
   * @param underlyingAsset The address of the underlying asset
   * @param pool The address of the associated lending pool
   * @param treasury The address of the treasury
   * @param incentivesController The address of the incentives controller for this sToken
   * @param STokenDecimals the decimals of the underlying
   * @param STokenName the name of the sToken
   * @param STokenSymbol the symbol of the sToken
   * @param params A set of encoded parameters for additional initialization
   **/
  event Initialized(
    address indexed underlyingAsset,
    address indexed pool,
    address treasury,
    address incentivesController,
    uint8 STokenDecimals,
    string STokenName,
    string STokenSymbol,
    bytes params
  );

  /**
   * @dev Initializes the sToken
   * @param pool The address of the lending pool where this sToken will be used
   * @param treasury The address of the SiO2 treasury, receiving the fees on this sToken
   * @param underlyingAsset The address of the underlying asset of this sToken (E.g. WETH for lWETH)
   * @param incentivesController The smart contract managing potential incentives distribution
   * @param STokenDecimals The decimals of the sToken, same as the underlying asset's
   * @param STokenName The name of the sToken
   * @param STokenSymbol The symbol of the sToken
   */
  function initialize(
    ILendingPool pool,
    address treasury,
    address underlyingAsset,
    ISiO2IncentivesController incentivesController,
    uint8 STokenDecimals,
    string calldata STokenName,
    string calldata STokenSymbol,
    bytes calldata params
  ) external;
}
