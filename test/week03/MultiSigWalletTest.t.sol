// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../../src/week03/MultiSigWallet.sol";
import "../../src/week02/MyToken.sol";

contract MultiSigWalletTest is Test {
    MultiSigWallet public wallet;
    MyToken public token;

    address public alice;
    address public bob;
    address public charlie;
    address public dave;

    address[] public owners;

    function setUp() public {
        // 创建 4 个测试地址：3个是持有人，1个是非持有人
        alice = address(0xA1);
        bob = address(0xB2);
        charlie = address(0xC3);
        dave = address(0xD4); // 非持有人

        // 设置签名人和门槛
        owners = [alice, bob, charlie];
        wallet = new MultiSigWallet(owners, 2);

        // 部署 MyToken 测试代币，初始供应给 this 合约
        token = new MyToken("TestToken", "TT", 1000000 * 10 ** 6);

        // 给钱包转入一些 token
        token.transfer(address(wallet), 1000 * 10 ** 6);
    }

    function testOnlyOwnerCanSubmitProposal() public {
        vm.startPrank(alice);
        uint256 pid = wallet.submitProposal(
            address(token),
            dave,
            100 * 10 ** 6
        );
        assertEq(pid, 0);
        vm.stopPrank();

        vm.prank(dave);
        vm.expectRevert("Not an owner");
        wallet.submitProposal(address(token), dave, 100);
    }

    function testConfirmAndExecuteProposal() public {
        vm.prank(alice);
        uint256 pid = wallet.submitProposal(
            address(token),
            dave,
            100 * 10 ** 6
        );

        // Bob 确认
        vm.prank(bob);
        wallet.confirmProposal(pid);

        // 达到门槛，现在可以执行
        uint256 before = token.balanceOf(dave);

        vm.prank(charlie); // 谁执行无所谓
        wallet.executeProposal(pid);

        uint256 afterBalance = token.balanceOf(dave);
        assertEq(afterBalance - before, 100 * 10 ** 6);
    }

    function testCannotDoubleConfirmOrExecute() public {
        vm.prank(alice);
        uint256 pid = wallet.submitProposal(
            address(token),
            dave,
            100 * 10 ** 6
        );

        vm.prank(bob);
        wallet.confirmProposal(pid);

        // 再次确认应该失败
        vm.prank(bob);
        vm.expectRevert("Already confirmed");
        wallet.confirmProposal(pid);

        // 执行成功
        vm.prank(charlie);
        wallet.executeProposal(pid);

        // 重复执行应该失败
        vm.prank(alice);
        vm.expectRevert("Proposal already executed");
        wallet.executeProposal(pid);
    }

    function testNotEnoughConfirmations() public {
        vm.prank(alice);
        uint256 pid = wallet.submitProposal(
            address(token),
            dave,
            100 * 10 ** 6
        );

        // 只有一人确认，不足以执行
        vm.expectRevert("Not enough confirmations");
        vm.prank(bob);
        wallet.executeProposal(pid);
    }
}
