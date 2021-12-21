// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../global/Types.sol';

interface INProxy {
  function batchBalanceAction(address account, BalanceAction[] memory actions) external payable;
  function batchBalanceAndTradeAction(address account, BalanceActionWithTrades[] memory actions) external;
  function nTokenClaimIncentives() external returns (uint256);
}
