// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {ILendingPoolAddressesProvider} from '../interfaces/ILendingPoolAddressesProvider.sol';
import {ISiO2IncentivesController} from '../interfaces/ISiO2IncentivesController.sol';
import {IUiIncentiveDataProviderV2} from './interfaces/IUiIncentiveDataProviderV2.sol';
import {ILendingPool} from '../interfaces/ILendingPool.sol';
import {ISToken} from '../interfaces/ISToken.sol';
import {IVariableDebtToken} from '../interfaces/IVariableDebtToken.sol';
import {IStableDebtToken} from '../interfaces/IStableDebtToken.sol';
import {UserConfiguration} from '../protocol/libraries/configuration/UserConfiguration.sol';
import {DataTypes} from '../protocol/libraries/types/DataTypes.sol';
import {IERC20Detailed} from '../dependencies/openzeppelin/contracts/IERC20Detailed.sol';

contract UiIncentiveDataProviderV2 is IUiIncentiveDataProviderV2 {
  using UserConfiguration for DataTypes.UserConfigurationMap;

  constructor() public {}

  function getFullReservesIncentiveData(ILendingPoolAddressesProvider provider, address user)
    external
    view
    override
    returns (AggregatedReserveIncentiveData[] memory, UserReserveIncentiveData[] memory)
  {
    return (_getReservesIncentivesData(provider), _getUserReservesIncentivesData(provider, user));
  }

  function getReservesIncentivesData(ILendingPoolAddressesProvider provider)
    external
    view
    override
    returns (AggregatedReserveIncentiveData[] memory)
  {
    return _getReservesIncentivesData(provider);
  }

  function _getReservesIncentivesData(ILendingPoolAddressesProvider provider)
    private
    view
    returns (AggregatedReserveIncentiveData[] memory)
  {
    ILendingPool lendingPool = ILendingPool(provider.getLendingPool());
    address[] memory reserves = lendingPool.getReservesList();
    AggregatedReserveIncentiveData[] memory reservesIncentiveData =
      new AggregatedReserveIncentiveData[](reserves.length);

    for (uint256 i = 0; i < reserves.length; i++) {
      AggregatedReserveIncentiveData memory reserveIncentiveData = reservesIncentiveData[i];
      reserveIncentiveData.underlyingAsset = reserves[i];

      DataTypes.ReserveData memory baseData = lendingPool.getReserveData(reserves[i]);

      try IStableDebtToken(baseData.STokenAddress).getIncentivesController() returns (
        ISiO2IncentivesController STokenIncentiveController
      ) {
        if (address(STokenIncentiveController) != address(0)) {
          address sRewardToken = STokenIncentiveController.REWARD_TOKEN();

          try STokenIncentiveController.getAssetData(baseData.STokenAddress) returns (
              uint256 incentiveIntialSupply,
              uint256 incentiveInflactionStart,
              uint256 incentiveDecayRatio,
              uint128 sIncentivesLastUpdateTimestamp, 
              uint256 STokenIncentivesIndex
          ) {
              reserveIncentiveData.sIncentiveData = IncentiveData(
              incentiveIntialSupply,
              incentiveInflactionStart,
              incentiveDecayRatio,
              sIncentivesLastUpdateTimestamp,
              STokenIncentivesIndex,
              baseData.STokenAddress,
              sRewardToken,
              address(STokenIncentiveController),
              IERC20Detailed(sRewardToken).decimals(),
              STokenIncentiveController.PRECISION()
            );
          } catch (
            bytes memory /*lowLevelData*/
          ) {
            (
              uint256 incentiveIntialSupply,
              uint256 incentiveInflactionStart,
              uint256 incentiveDecayRatio,
              uint128 sIncentivesLastUpdateTimestamp, 
              uint256 STokenIncentivesIndex
            ) = STokenIncentiveController.assets(baseData.STokenAddress);

            reserveIncentiveData.sIncentiveData = IncentiveData(
              incentiveIntialSupply,
              incentiveInflactionStart,
              incentiveDecayRatio,
              sIncentivesLastUpdateTimestamp,
              STokenIncentivesIndex,
              baseData.STokenAddress,
              sRewardToken,
              address(STokenIncentiveController),
              IERC20Detailed(sRewardToken).decimals(),
              STokenIncentiveController.PRECISION()
            );
          }
        }
      } catch (
        bytes memory /*lowLevelData*/
      ) {
        // Will not get here
      }

      try IStableDebtToken(baseData.stableDebtTokenAddress).getIncentivesController() returns (
        ISiO2IncentivesController sdTokenIncentiveController
      ) {
        if (address(sdTokenIncentiveController) != address(0)) {
          address sdRewardToken = sdTokenIncentiveController.REWARD_TOKEN();
          try sdTokenIncentiveController.getAssetData(baseData.stableDebtTokenAddress) returns (
              uint256 sdIncentiveIntialSupply,
              uint256 sdIncentiveInflactionStart,
              uint256 sdIncentiveDecayRatio,
              uint128 sdIncentivesLastUpdateTimestamp, 
              uint256 sdTokenIncentivesIndex
          ) {
            reserveIncentiveData.sdIncentiveData = IncentiveData(
              sdIncentiveIntialSupply,
              sdIncentiveInflactionStart,
              sdIncentiveDecayRatio,
              sdIncentivesLastUpdateTimestamp,
              sdTokenIncentivesIndex,
              baseData.stableDebtTokenAddress,
              sdRewardToken,
              address(sdTokenIncentiveController),
              IERC20Detailed(sdRewardToken).decimals(),
              sdTokenIncentiveController.PRECISION()
            );
          } catch (
            bytes memory /*lowLevelData*/
          ) {
            (
              uint256 sdIncentiveIntialSupply,
              uint256 sdIncentiveInflactionStart,
              uint256 sdIncentiveDecayRatio,
              uint128 sdIncentivesLastUpdateTimestamp, 
              uint256 sdTokenIncentivesIndex
            ) = sdTokenIncentiveController.assets(baseData.stableDebtTokenAddress);

            reserveIncentiveData.sdIncentiveData = IncentiveData(
              sdIncentiveIntialSupply,
              sdIncentiveInflactionStart,
              sdIncentiveDecayRatio,
              sdIncentivesLastUpdateTimestamp,
              sdTokenIncentivesIndex,
              baseData.stableDebtTokenAddress,
              sdRewardToken,
              address(sdTokenIncentiveController),
              IERC20Detailed(sdRewardToken).decimals(),
              sdTokenIncentiveController.PRECISION()
            );
          }
        }
      } catch (
        bytes memory /*lowLevelData*/
      ) {
        // Will not get here
      }

      try IStableDebtToken(baseData.variableDebtTokenAddress).getIncentivesController() returns (
        ISiO2IncentivesController vdTokenIncentiveController
      ) {
        if (address(vdTokenIncentiveController) != address(0)) {
          address vdRewardToken = vdTokenIncentiveController.REWARD_TOKEN();

          try vdTokenIncentiveController.getAssetData(baseData.variableDebtTokenAddress) returns (
              uint256 vdIncentiveIntialSupply,
              uint256 vdIncentiveInflactionStart,
              uint256 vdIncentiveDecayRatio,
              uint128 vdIncentivesLastUpdateTimestamp, 
              uint256 vdTokenIncentivesIndex
          ) {
            reserveIncentiveData.vdIncentiveData = IncentiveData(
              vdIncentiveIntialSupply,
              vdIncentiveInflactionStart,
              vdIncentiveDecayRatio,
              vdIncentivesLastUpdateTimestamp,
              vdTokenIncentivesIndex,
              baseData.variableDebtTokenAddress,
              vdRewardToken,
              address(vdTokenIncentiveController),
              IERC20Detailed(vdRewardToken).decimals(),
              vdTokenIncentiveController.PRECISION()
            );
          } catch (
            bytes memory /*lowLevelData*/
          ) {
            (
              uint256 vdIncentiveIntialSupply,
              uint256 vdIncentiveInflactionStart,
              uint256 vdIncentiveDecayRatio,
              uint128 vdIncentivesLastUpdateTimestamp, 
              uint256 vdTokenIncentivesIndex
            ) = vdTokenIncentiveController.assets(baseData.variableDebtTokenAddress);

            reserveIncentiveData.vdIncentiveData = IncentiveData(
              vdIncentiveIntialSupply,
              vdIncentiveInflactionStart,
              vdIncentiveDecayRatio,
              vdIncentivesLastUpdateTimestamp,
              vdTokenIncentivesIndex,
              baseData.variableDebtTokenAddress,
              vdRewardToken,
              address(vdTokenIncentiveController),
              IERC20Detailed(vdRewardToken).decimals(),
              vdTokenIncentiveController.PRECISION()
            );
          }
        }
      } catch (
        bytes memory /*lowLevelData*/
      ) {
        // Will not get here
      }
    }
    return (reservesIncentiveData);
  }

  function getUserReservesIncentivesData(ILendingPoolAddressesProvider provider, address user)
    external
    view
    override
    returns (UserReserveIncentiveData[] memory)
  {
    return _getUserReservesIncentivesData(provider, user);
  }

  function _getUserReservesIncentivesData(ILendingPoolAddressesProvider provider, address user)
    private
    view
    returns (UserReserveIncentiveData[] memory)
  {
    ILendingPool lendingPool = ILendingPool(provider.getLendingPool());
    address[] memory reserves = lendingPool.getReservesList();

    UserReserveIncentiveData[] memory userReservesIncentivesData =
      new UserReserveIncentiveData[](user != address(0) ? reserves.length : 0);

    for (uint256 i = 0; i < reserves.length; i++) {
      DataTypes.ReserveData memory baseData = lendingPool.getReserveData(reserves[i]);

      // user reserve data
      userReservesIncentivesData[i].underlyingAsset = reserves[i];

      IUiIncentiveDataProviderV2.UserIncentiveData memory SUserIncentiveData;

      try ISToken(baseData.STokenAddress).getIncentivesController() returns (
        ISiO2IncentivesController STokenIncentiveController
      ) {
        if (address(STokenIncentiveController) != address(0)) {
          address sRewardToken = STokenIncentiveController.REWARD_TOKEN();
          SUserIncentiveData.tokenincentivesUserIndex = STokenIncentiveController.getUserAssetData(
            user,
            baseData.STokenAddress
          );
          SUserIncentiveData.userUnclaimedRewards = STokenIncentiveController
            .getUserUnclaimedRewards(user);
          SUserIncentiveData.tokenAddress = baseData.STokenAddress;
          SUserIncentiveData.rewardTokenAddress = sRewardToken;
          SUserIncentiveData.incentiveControllerAddress = address(STokenIncentiveController);
          SUserIncentiveData.rewardTokenDecimals = IERC20Detailed(sRewardToken).decimals();
        }
      } catch (
        bytes memory /*lowLevelData*/
      ) {}

      userReservesIncentivesData[i].STokenIncentivesUserData = SUserIncentiveData;

      UserIncentiveData memory vdUserIncentiveData;

      try IVariableDebtToken(baseData.variableDebtTokenAddress).getIncentivesController() returns (
        ISiO2IncentivesController vdTokenIncentiveController
      ) {
        if (address(vdTokenIncentiveController) != address(0)) {
          address vdRewardToken = vdTokenIncentiveController.REWARD_TOKEN();
          vdUserIncentiveData.tokenincentivesUserIndex = vdTokenIncentiveController
            .getUserAssetData(user, baseData.variableDebtTokenAddress);
          vdUserIncentiveData.userUnclaimedRewards = vdTokenIncentiveController
            .getUserUnclaimedRewards(user);
          vdUserIncentiveData.tokenAddress = baseData.variableDebtTokenAddress;
          vdUserIncentiveData.rewardTokenAddress = vdRewardToken;
          vdUserIncentiveData.incentiveControllerAddress = address(vdTokenIncentiveController);
          vdUserIncentiveData.rewardTokenDecimals = IERC20Detailed(vdRewardToken).decimals();
        }
      } catch (
        bytes memory /*lowLevelData*/
      ) {}

      userReservesIncentivesData[i].vdTokenIncentivesUserData = vdUserIncentiveData;

      UserIncentiveData memory sdUserIncentiveData;

      try IStableDebtToken(baseData.stableDebtTokenAddress).getIncentivesController() returns (
        ISiO2IncentivesController sdTokenIncentiveController
      ) {
        if (address(sdTokenIncentiveController) != address(0)) {
          address sdRewardToken = sdTokenIncentiveController.REWARD_TOKEN();
          sdUserIncentiveData.tokenincentivesUserIndex = sdTokenIncentiveController
            .getUserAssetData(user, baseData.stableDebtTokenAddress);
          sdUserIncentiveData.userUnclaimedRewards = sdTokenIncentiveController
            .getUserUnclaimedRewards(user);
          sdUserIncentiveData.tokenAddress = baseData.stableDebtTokenAddress;
          sdUserIncentiveData.rewardTokenAddress = sdRewardToken;
          sdUserIncentiveData.incentiveControllerAddress = address(sdTokenIncentiveController);
          sdUserIncentiveData.rewardTokenDecimals = IERC20Detailed(sdRewardToken).decimals();
        }
      } catch (
        bytes memory /*lowLevelData*/
      ) {}

      userReservesIncentivesData[i].sdTokenIncentivesUserData = sdUserIncentiveData;
    }

    return (userReservesIncentivesData);
  }
}
