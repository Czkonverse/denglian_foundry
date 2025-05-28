// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "./BankWithAutomation.sol";

contract BankWithAutomationTest is Test {
    BankWithAutomation public bank;
    address public owner;
    address public user1;
    address public user2;
    address public recipient;

    uint256 constant THRESHOLD = 10 ether;

    // 添加 receive 函数以接收 ETH
    receive() external payable {}

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        recipient = address(0x3);

        // 给测试地址一些 ETH
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);

        // 部署合约
        bank = new BankWithAutomation(THRESHOLD, recipient);
    }

    // 测试初始化
    function testInitialization() public view {
        assertEq(bank.threshold(), THRESHOLD);
        assertEq(bank.recipient(), recipient);
        assertEq(bank.owner(), owner);
    }

    // 测试 checkUpkeep - 余额不足
    function testCheckUpkeepBalanceBelowThreshold() public {
        // 存入少于阈值的金额
        vm.prank(user1);
        bank.deposit{value: 5 ether}();

        (bool upkeepNeeded,) = bank.checkUpkeep("");
        assertFalse(upkeepNeeded);
    }

    // 测试 checkUpkeep - 余额超过阈值
    function testCheckUpkeepBalanceAboveThreshold() public {
        // 存入超过阈值的金额
        vm.prank(user1);
        bank.deposit{value: 15 ether}();

        // 推进时间，确保超过最小间隔
        vm.warp(block.timestamp + 61);

        (bool upkeepNeeded,) = bank.checkUpkeep("");
        assertTrue(upkeepNeeded);
    }

    // 测试 performUpkeep
    function testPerformUpkeep() public {
        // 存入超过阈值的金额
        vm.prank(user1);
        bank.deposit{value: 20 ether}();

        // 推进时间
        vm.warp(block.timestamp + 61);

        uint256 recipientBalanceBefore = recipient.balance;
        uint256 contractBalanceBefore = address(bank).balance;

        // 执行自动转账
        bank.performUpkeep("");

        // 验证转账金额（一半）
        assertEq(recipient.balance, recipientBalanceBefore + contractBalanceBefore / 2);
        assertEq(address(bank).balance, contractBalanceBefore / 2);
    }

    // 测试时间间隔限制
    function testMinIntervalRestriction() public {
        // 第一次存款
        vm.prank(user1);
        bank.deposit{value: 20 ether}();

        // 推进时间超过最小间隔
        vm.warp(block.timestamp + 61);

        // 第一次转账应该成功
        bank.performUpkeep("");

        // 立即再次存款
        vm.prank(user1);
        bank.deposit{value: 20 ether}();

        // 应该不满足条件（时间间隔不足）
        (bool upkeepNeeded,) = bank.checkUpkeep("");
        assertFalse(upkeepNeeded);

        // 尝试执行应该失败
        vm.expectRevert("Conditions not met");
        bank.performUpkeep("");

        // 快进时间
        vm.warp(block.timestamp + 61);

        // 现在应该满足条件
        (upkeepNeeded,) = bank.checkUpkeep("");
        assertTrue(upkeepNeeded);

        // 现在执行应该成功
        bank.performUpkeep("");
    }

    // 测试更新阈值
    function testUpdateThreshold() public {
        uint256 newThreshold = 20 ether;
        bank.updateThreshold(newThreshold);
        assertEq(bank.threshold(), newThreshold);
    }

    // 测试更新接收地址
    function testUpdateRecipient() public {
        address newRecipient = address(0x456);
        bank.updateRecipient(newRecipient);
        assertEq(bank.recipient(), newRecipient);
    }

    // 测试非 owner 不能更新配置
    function test_RevertWhen_NonOwnerUpdatesThreshold() public {
        vm.prank(user1);
        vm.expectRevert("Only owner can call this function");
        bank.updateThreshold(20 ether);
    }

    // 测试零地址接收者
    function test_RevertWhen_RecipientIsZeroAddress() public {
        vm.expectRevert("Recipient cannot be zero address");
        new BankWithAutomation(THRESHOLD, address(0));
    }

    // 测试完整流程
    function testFullAutomationFlow() public {
        // 多个用户存款
        vm.prank(user1);
        bank.deposit{value: 8 ether}();

        // 推进时间
        vm.warp(block.timestamp + 61);

        // 检查未达到阈值
        (bool upkeepNeeded,) = bank.checkUpkeep("");
        assertFalse(upkeepNeeded);

        // 继续存款，超过阈值
        vm.prank(user2);
        bank.deposit{value: 5 ether}();

        // 现在应该需要执行
        (upkeepNeeded,) = bank.checkUpkeep("");
        assertTrue(upkeepNeeded);

        // 执行自动转账
        uint256 balanceBefore = address(bank).balance;
        bank.performUpkeep("");

        // 验证转了一半
        assertEq(address(bank).balance, balanceBefore / 2);
        assertEq(recipient.balance, balanceBefore / 2);
    }
}
