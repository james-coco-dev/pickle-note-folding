// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../global/Types.sol';

interface INProxy {
  function batchBalanceAction(address account, BalanceAction[] memory actions) external payable;
  function nTokenClaimIncentives() external returns (uint256);
}
