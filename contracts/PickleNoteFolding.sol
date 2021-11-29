// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import './global/Types.sol';
import './interfaces/INProxy.sol';

contract PickNoteFolding is Ownable {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  struct PoolInfo {
    uint16 currencyId;
    address asset;
  }

  struct UserInfo {
    uint256 amount;
  }

  PoolInfo[] pools;
  mapping(uint256 => mapping(address => UserInfo)) users;

  address nProxy;

  constructor(address _nProxy) {
    nProxy = _nProxy;
  }

  function addPool(uint16 _currencyId, address _asset) external onlyOwner {
    pools.push(PoolInfo({
      currencyId: _currencyId,
      asset: _asset
    }));

    IERC20(_asset).safeApprove(nProxy, ~uint256(0));
  }

  function setPool(uint256 _pid, uint16 _currencyId, address _asset) external onlyOwner payable {
    PoolInfo storage pool = pools[_pid];
    pool.currencyId = _currencyId;
    pool.asset = _asset;
    IERC20(_asset).safeApprove(nProxy, ~uint256(0));
  }

  function deposit(uint256 _pid, uint256 _amount) external payable {
    PoolInfo storage pool = pools[_pid];
    UserInfo storage user = users[_pid][_msgSender()];
    BalanceAction memory action;
    action.actionType = DepositActionType.DepositUnderlyingAndMintNToken;
    action.currencyId = pool.currencyId;
    action.depositActionAmount = _amount;
    BalanceAction[] memory actions = new BalanceAction[](1);
    actions[0] = action;
    if (pool.currencyId == 1) { // if ETH deposit
      INProxy(nProxy).batchBalanceAction{value: msg.value}(address(this), actions);
    } else {
      IERC20(pool.asset).safeTransferFrom(_msgSender(), address(this), _amount);
      INProxy(nProxy).batchBalanceAction(address(this), actions);
    }
    user.amount = user.amount.add(_amount);
  }

  function withdraw(uint256 _pid, uint256 _amount) external {
    PoolInfo storage pool = pools[_pid];
    UserInfo storage user = users[_pid][_msgSender()];

    require(user.amount >= _amount, 'exceed amount');

    BalanceAction memory action;
    action.actionType = DepositActionType.DepositUnderlyingAndMintNToken;
    action.currencyId = pool.currencyId;
    action.withdrawAmountInternalPrecision = _amount;
    BalanceAction[] memory actions = new BalanceAction[](1);
    actions[0] = action;

    INProxy(nProxy).batchBalanceAction(address(this), actions);
    user.amount = user.amount.sub(_amount);
  }

  function harvest() external {
    INProxy(nProxy).nTokenClaimIncentives();
  }
}
