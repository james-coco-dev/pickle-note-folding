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

  mapping(address => bool) public keepers;
  uint _maxSlippage = 95;

  modifier onlyKeeppers() {
    require(
      keepers[msg.sender] ||
      msg.sender == address(this)
    );
    _;
  }

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

  function setKeeper(address _keeper, bool yesOrNo) external onlyOwner {
    keepers[_keeper] = yesOrNo;
  }

  function deposit(uint256 _pid, uint256 _amount) public payable {
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

  function getSuppliedUnleveraged() public view returns (uint256 unleveraged) {
    
  }

  function getLeveragedSupplyTarget(uint _amount) internal view returns (uint256 supply) {

  }

  function getSupplied() internal view returns (uint256 supplied) {

  }

  function getBorrowable() internal view returns (uint256 borrowable) {
    
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

  function borrow(uint _pid, uint _amount) public onlyKeeppers returns (uint) {
    PoolInfo storage pool = pools[_pid];
    BalanceActionWithTrades memory action;
    action.actionType = DepositActionType.DepositUnderlyingAndMintNToken;
    action.currencyId = pool.currencyId;
    action.depositActionAmount = _amount;
    bytes32 trade = bytes32(abi.encode(TradeActionType.Borrow, 1, _amount, 0, _maxSlippage));
    bytes32[] memory trades = new bytes32[](1);
    trades[0] = trade;
    action.trades = trades;
    BalanceActionWithTrades[] memory actions = new BalanceActionWithTrades[](1);
    actions[0] = action;
    INProxy(nProxy).batchBalanceAndTradeAction(address(this), actions);
  }

  function harvest() external {
    INProxy(nProxy).nTokenClaimIncentives();
  }

  function leverageUntil(uint256 _pid, uint256 _amount) public onlyKeeppers {
    uint256 supplied = getSupplied();
    uint256 _borrowAndSupply;

    while(supplied < _amount) {
      _borrowAndSupply = getBorrowable();
      uint borrowed = borrow(_pid, _borrowAndSupply);
      deposit(_pid, borrowed);
    }
  }

  function leverageToMax(uint256 _pid) external {
    uint unleveraged = getSuppliedUnleveraged();
    uint ideaSupply = getLeveragedSupplyTarget(unleveraged);
    leverageUntil(_pid, ideaSupply);
  }
}
