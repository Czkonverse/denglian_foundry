// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "src/week03/TokenBankMultiTokenPermit.sol";
import "src/week02/MyToken.sol";

contract TokenBankPermitTest is Test {
    MyToken public token;
    TokenBankMultiTokenPermit public bank;
    IPermit2 public permit2;
    address public user;
    uint256 public userPrivateKey;

    function setUp() public {
        // 创建测试账户
        userPrivateKey = 0xBEEF;
        user = vm.addr(userPrivateKey);

        token = new MyToken("MyToken", "MTK", 0);
        bank = new TokenBankMultiTokenPermit(address(permit2));

        token.mint(user, 1000e6); // 6位小数

        vm.prank(user);
        token.approve(address(bank), 1000e6); // for normal deposit test
    }

    function testPermitDeposit() public {
        uint256 amount = 100e6;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(user);

        // 构造 EIP-712 typed data hash
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(
                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                ),
                user,
                address(bank),
                amount,
                nonce,
                deadline
            )
        );

        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);

        // 调用 permitDeposit
        vm.prank(user);
        bank.permitDeposit(address(token), amount, deadline, v, r, s);

        // 验证
        uint256 deposited = bank.balanceOf(user, address(token));
        assertEq(deposited, amount);
        assertEq(token.balanceOf(address(bank)), amount);
        assertEq(token.balanceOf(user), 900e6);
    }
}
