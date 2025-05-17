// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "solmate/utils/SafeTransferLib.sol";
import "solmate/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IPermit2} from "src/week03/tokenbank/IPermit2.sol";

contract TokenBankMultiTokenPermit is ReentrancyGuard {
    using SafeTransferLib for address;

    error TokenBankMultiTokenPermit__AmountMustBeGreaterThanZero();
    error TokenBankMultiTokenPermit__TransferFailed();

    // 用户 => 代币地址 => 余额
    mapping(address => mapping(address => uint256)) public balances;

    // Permit2合约地址
    IPermit2 public immutable permit2;

    // 事件定义
    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdraw(address indexed user, address indexed token, uint256 amount);

    constructor(address _permit2) {
        require(_permit2 != address(0), "invalid permit2 address");

        permit2 = IPermit2(_permit2);
    }

    /// 用户存款函数
    function deposit(address token, uint256 amount) external {
        require(amount > 0, "amount must > 0");

        IERC20(token).transferFrom(msg.sender, address(this), amount);
        balances[msg.sender][token] += amount;

        emit Deposit(msg.sender, token, amount);
    }

    /// 用户取款函数
    function withdraw(address token, uint256 amount) external nonReentrant {
        require(amount > 0, "amount must > 0");
        require(balances[msg.sender][token] >= amount, "insufficient balance");

        balances[msg.sender][token] -= amount;
        IERC20(token).transfer(msg.sender, amount);

        emit Withdraw(msg.sender, token, amount);
    }

    // 使用Permit授权方式进行存款
    function permitDeposit(address token, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
        if (amount == 0) {
            revert TokenBankMultiTokenPermit__AmountMustBeGreaterThanZero();
        }

        // 第一步：调用 token 合约的 permit 授权自己
        IERC20Permit(token).permit(msg.sender, address(this), amount, deadline, v, r, s);

        // 第二步：执行转账
        bool success = IERC20(token).transferFrom(msg.sender, address(this), amount);
        if (!success) revert TokenBankMultiTokenPermit__TransferFailed();

        balances[msg.sender][token] += amount;
        emit Deposit(msg.sender, token, amount);
    }

    /// 使用Permit2授权方式进行存款
    function depositWithPermit2(
        IPermit2.PermitTransferFrom calldata permit,
        IPermit2.SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external {
        require(permit.permitted.amount > 0, "amount must > 0");
        require(permit.deadline >= block.timestamp, "expired");
        require(transferDetails.to == address(this), "must send to contract");

        permit2.permitTransferFrom(permit, transferDetails, owner, signature);
        balances[owner][permit.permitted.token] += permit.permitted.amount;

        emit Deposit(owner, permit.permitted.token, permit.permitted.amount);
    }
}
