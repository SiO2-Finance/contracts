// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {ILendingPoolAddressesProvider} from '../../interfaces/ILendingPoolAddressesProvider.sol';

interface IUiIncentiveDataProviderV2 {
  struct AggregatedReserveIncentiveData {
    address underlyingAsset;
    IncentiveData sIncentiveData;
    IncentiveData vdIncentiveData;
    IncentiveData sdIncentiveData;
  }

  struct IncentiveData {
    uint256 incentiveIntialSupply;
    uint256 incentiveInflactionStart;
    uint256 incentiveDecayRatio;
    uint256 incentivesLastUpdateTimestamp;
    uint256 tokenIncentivesIndex;
    address tokenAddress;
    address rewardTokenAddress;
    address incentiveControllerAddress;
    uint8 rewardTokenDecimals;
    uint8 precision;
  }

  struct UserReserveIncentiveData {
    address underlyingAsset;
    UserIncentiveData STokenIncentivesUserData;
    UserIncentiveData vdTokenIncentivesUserData;
    UserIncentiveData sdTokenIncentivesUserData;
  }

  struct UserIncentiveData {
    uint256 tokenincentivesUserIndex;
    uint256 userUnclaimedRewards;
    address tokenAddress;
    address rewardTokenAddress;
    address incentiveControllerAddress;
    uint8 rewardTokenDecimals;
  }

  function getReservesIncentivesData(ILendingPoolAddressesProvider provider)
    external
    view
    returns (AggregatedReserveIncentiveData[] memory);

  function getUserReservesIncentivesData(ILendingPoolAddressesProvider provider, address user)
    external
    view
    returns (UserReserveIncentiveData[] memory);

  // generic method with full data
  function getFullReservesIncentiveData(ILendingPoolAddressesProvider provider, address user)
    external
    view
    returns (AggregatedReserveIncentiveData[] memory, UserReserveIncentiveData[] memory);
}
