// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/week03/IPermit2.sol";

contract TokenBankMultiTokenPermit {
    error TokenBank__AmountMustBeGreaterThanZero();
    error TokenBank__NotEnoughBalance();
    error TokenBank__AllowanceTooLow();
    error TokenBank__TransferFailed();
    error TokenBank__InvalidSpender();

    IPermit2 public immutable permit2;

    // user => token => amount
    mapping(address => mapping(address => uint256)) public s_deposits;

    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdraw(address indexed user, address indexed token, uint256 amount);

    constructor(address _permit2) {
        permit2 = IPermit2(_permit2);
    }

    function deposit(address token, uint256 amount) external {
        if (amount == 0) revert TokenBank__AmountMustBeGreaterThanZero();
        if (IERC20(token).allowance(msg.sender, address(this)) < amount)
            revert TokenBank__AllowanceTooLow();

        bool success = IERC20(token).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        if (!success) revert TokenBank__TransferFailed();

        s_deposits[msg.sender][token] += amount;
        emit Deposit(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount) external {
        if (s_deposits[msg.sender][token] < amount)
            revert TokenBank__NotEnoughBalance();

        s_deposits[msg.sender][token] -= amount;
        bool success = IERC20(token).transfer(msg.sender, amount);
        if (!success) revert TokenBank__TransferFailed();

        emit Withdraw(msg.sender, token, amount);
    }

    /// @notice 使用签名授权并完成存款
    function permitDeposit(
        address token,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        if (amount == 0) revert TokenBank__AmountMustBeGreaterThanZero();

        // 第一步：调用 token 合约的 permit 授权自己
        IERC20Permit(token).permit(
            msg.sender,
            address(this),
            amount,
            deadline,
            v,
            r,
            s
        );

        // 第二步：执行转账
        bool success = IERC20(token).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        if (!success) revert TokenBank__TransferFailed();

        s_deposits[msg.sender][token] += amount;
        emit Deposit(msg.sender, token, amount);
    }

    /// @notice 使用 Permit2 进行签名授权并完成存款
    function depositWithPermit2(
        IPermit2.PermitTransferFrom calldata permit,
        IPermit2.SignatureTransferDetails calldata transferDetails,
        bytes calldata signature
    ) external {
        // 验证转账金额大于0
        if (transferDetails.requestedAmount == 0)
            revert TokenBank__AmountMustBeGreaterThanZero();

        // 验证接收地址是本合约
        if (transferDetails.to != address(this))
            revert TokenBank__InvalidSpender();

        // 调用 Permit2 合约的 permitTransferFrom 进行授权转账
        permit2.permitTransferFrom(
            permit,
            transferDetails,
            msg.sender,
            signature
        );

        // 更新存款金额
        s_deposits[msg.sender][permit.permitted.token] += transferDetails
            .requestedAmount;

        emit Deposit(
            msg.sender,
            permit.permitted.token,
            transferDetails.requestedAmount
        );
    }

    function balanceOf(
        address user,
        address token
    ) external view returns (uint256) {
        return s_deposits[user][token];
    }
}
