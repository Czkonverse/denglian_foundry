// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "./Bank.sol";

contract BankTest is Test {
    Bank public bank;
    address public owner;
    address public user1;
    address public user2;

    // 测试事件
    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);

    // 添加 receive 函数以接收 ETH
    receive() external payable {}

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);

        // 部署 Bank 合约
        bank = new Bank();

        // 给测试用户一些 ETH
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }

    // 测试合约部署
    function testDeployment() public view {
        assertEq(bank.owner(), owner);
        assertEq(bank.totalDeposits(), 0);
        assertEq(bank.getContractBalance(), 0);
    }

    // 测试存款功能
    function testDeposit() public {
        uint256 depositAmount = 1 ether;

        vm.startPrank(user1);

        // 预期事件
        vm.expectEmit(true, false, false, true);
        emit Deposit(user1, depositAmount);

        // 执行存款
        bank.deposit{value: depositAmount}();

        vm.stopPrank();

        // 验证结果
        assertEq(bank.balances(user1), depositAmount);
        assertEq(bank.totalDeposits(), depositAmount);
        assertEq(bank.getContractBalance(), depositAmount);
        assertEq(bank.getBalance(user1), depositAmount);
    }

    // 测试多个用户存款
    function testMultipleDeposits() public {
        uint256 amount1 = 2 ether;
        uint256 amount2 = 3 ether;

        // User1 存款
        vm.prank(user1);
        bank.deposit{value: amount1}();

        // User2 存款
        vm.prank(user2);
        bank.deposit{value: amount2}();

        // 验证
        assertEq(bank.balances(user1), amount1);
        assertEq(bank.balances(user2), amount2);
        assertEq(bank.totalDeposits(), amount1 + amount2);
        assertEq(bank.getContractBalance(), amount1 + amount2);
    }

    // 测试零值存款应该失败
    function test_RevertWhen_DepositZero() public {
        vm.prank(user1);
        vm.expectRevert("Deposit amount must be greater than 0");
        bank.deposit{value: 0}();
    }

    // 测试提取功能
    function testWithdraw() public {
        uint256 depositAmount = 2 ether;
        uint256 withdrawAmount = 1 ether;

        // 先存款
        vm.startPrank(user1);
        bank.deposit{value: depositAmount}();

        uint256 balanceBefore = user1.balance;

        // 预期事件
        vm.expectEmit(true, false, false, true);
        emit Withdrawal(user1, withdrawAmount);

        // 执行提取
        bank.withdraw(withdrawAmount);
        vm.stopPrank();

        // 验证
        assertEq(bank.balances(user1), depositAmount - withdrawAmount);
        assertEq(bank.totalDeposits(), depositAmount - withdrawAmount);
        assertEq(bank.getContractBalance(), depositAmount - withdrawAmount);
        assertEq(user1.balance, balanceBefore + withdrawAmount);
    }

    // 测试提取超过余额应该失败
    function test_RevertWhen_WithdrawMoreThanBalance() public {
        uint256 depositAmount = 1 ether;
        uint256 withdrawAmount = 2 ether;

        vm.startPrank(user1);
        bank.deposit{value: depositAmount}();
        vm.expectRevert("Insufficient balance");
        bank.withdraw(withdrawAmount);
        vm.stopPrank();
    }

    // 测试提取零值应该失败
    function test_RevertWhen_WithdrawZero() public {
        vm.startPrank(user1);
        bank.deposit{value: 1 ether}();
        vm.expectRevert("Withdrawal amount must be greater than 0");
        bank.withdraw(0);
        vm.stopPrank();
    }

    // 测试紧急提取（仅 owner）
    function testEmergencyWithdraw() public {
        // 用户存款
        vm.prank(user1);
        bank.deposit{value: 3 ether}();

        uint256 ownerBalanceBefore = owner.balance;
        uint256 contractBalance = bank.getContractBalance();

        // Owner 执行紧急提取
        bank.emergencyWithdraw();

        // 验证
        assertEq(bank.getContractBalance(), 0);
        assertEq(owner.balance, ownerBalanceBefore + contractBalance);
    }

    // 测试非 owner 调用紧急提取应该失败
    function test_RevertIf_EmergencyWithdrawNotOwner() public {
        vm.prank(user1);
        bank.deposit{value: 1 ether}();

        vm.prank(user1);
        vm.expectRevert("Only owner can call this function");
        bank.emergencyWithdraw();
    }

    // 测试转移所有权
    function testTransferOwnership() public {
        address newOwner = address(0x123);

        bank.transferOwnership(newOwner);

        assertEq(bank.owner(), newOwner);
    }

    // 测试非 owner 转移所有权应该失败
    function test_RevertIf_TransferOwnershipNotOwner() public {
        vm.prank(user1);
        vm.expectRevert("Only owner can call this function");
        bank.transferOwnership(user2);
    }

    // 测试转移所有权到零地址应该失败
    function test_RevertWhen_TransferOwnershipToZeroAddress() public {
        vm.expectRevert("New owner cannot be zero address");
        bank.transferOwnership(address(0));
    }

    // 测试完整流程
    function testFullFlow() public {
        // User1 存款
        vm.prank(user1);
        bank.deposit{value: 5 ether}();

        // User2 存款
        vm.prank(user2);
        bank.deposit{value: 3 ether}();

        // User1 部分提取
        vm.prank(user1);
        bank.withdraw(2 ether);

        // 验证最终状态
        assertEq(bank.balances(user1), 3 ether);
        assertEq(bank.balances(user2), 3 ether);
        assertEq(bank.totalDeposits(), 6 ether);
        assertEq(bank.getContractBalance(), 6 ether);
    }

    // Fuzzing 测试 - 随机金额存款
    function testFuzzDeposit(uint256 amount) public {
        vm.assume(amount > 0 && amount <= 10 ether);

        vm.deal(user1, amount);
        vm.prank(user1);
        bank.deposit{value: amount}();

        assertEq(bank.balances(user1), amount);
        assertEq(bank.getContractBalance(), amount);
    }

    // Fuzzing 测试 - 随机金额提取
    function testFuzzWithdraw(uint256 depositAmount, uint256 withdrawAmount) public {
        vm.assume(depositAmount > 0 && depositAmount <= 10 ether);
        vm.assume(withdrawAmount > 0 && withdrawAmount <= depositAmount);

        vm.deal(user1, depositAmount);

        vm.startPrank(user1);
        bank.deposit{value: depositAmount}();
        bank.withdraw(withdrawAmount);
        vm.stopPrank();

        assertEq(bank.balances(user1), depositAmount - withdrawAmount);
        assertEq(bank.getContractBalance(), depositAmount - withdrawAmount);
    }
}
