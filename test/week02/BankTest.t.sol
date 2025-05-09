// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {Bank} from "src/week02/Bank.sol";
import {DeployBank} from "script/week02/DeployBank.s.sol";

contract BankTest is Test {
    Bank public bank;

    address public constant USER_TEST = address(1);
    address[] public prankUsers;
    uint256[] public prankUsersDepositAmounts;

    function setUp() public {
        DeployBank deployBank = new DeployBank();
        bank = deployBank.deployContract();
    }

    // 断言检查存款前后用户在 Bank 合约中的存款额更新是否正确。
    function testDeposit() public {
        vm.deal(USER_TEST, 10 ether);

        uint256 userBalanceBefore = bank.getUserDeposit(USER_TEST);

        vm.prank(USER_TEST);
        uint256 userDepositAmount = 1 ether;
        bank.deposit{value: userDepositAmount}();

        uint256 userBalanceAfterDeposit = bank.getUserDeposit(USER_TEST);

        assertEq(
            userBalanceBefore + userDepositAmount,
            userBalanceAfterDeposit
        );
    }

    // 检查存款金额的前 3 名用户是否正确，分别检查有1个、2个、3个、4 个用户
    function testTop3UserWithDifferentUsers() public {
        testTop3UserInDifferentScenarios(10);
    }

    function testTop3UserInDifferentScenarios(uint prankUsersNumber) public {
        prankUsersNumber = (prankUsersNumber % 4) + 1;

        // 检查有I个用户存款的情况下，top3存款用户是否正确
        for (uint256 i = 1; i <= prankUsersNumber; i++) {
            address userTmp = address(
                uint160(uint256(keccak256(abi.encodePacked(i + 1, i + 10))))
            );
            uint256 userDepositAmount = (10 + i + i) * 1 ether;
            vm.deal(userTmp, userDepositAmount);
            vm.startPrank(userTmp);
            bank.deposit{value: userDepositAmount}();

            prankUsers.push(userTmp);
            prankUsersDepositAmounts.push(userDepositAmount);

            vm.stopPrank();
        }

        // 当前prankUsers按照存款数量排序的Index
        uint256[] memory topAmountSortIdx = bank.sortIndicesByDescendingValue(
            prankUsersDepositAmounts
        );

        // 当前Bnk合约中的top3用户
        address[] memory nowBankTop3Users = bank.getTop3Users();

        uint256 prankUsersNumberMax = prankUsersNumber;
        if (prankUsersNumber > 3) {
            prankUsersNumberMax = 3;
        }
        for (uint256 k = 0; k < prankUsersNumberMax; k++) {
            address topUserPrank = prankUsers[topAmountSortIdx[k]];
            assertEq(topUserPrank, nowBankTop3Users[k]);
        }
    }

    // 检查同一个用户多次存款的情况。
    function testOneUserDepositMultipleTimes() public {
        // 检查同一个用户多次存款的情况下，top3存款用户是否正确
        address userTmp = address(
            uint160(
                uint256(keccak256(abi.encodePacked(uint256(1), uint256(2))))
            )
        );
        uint256 userDepositTimes = 5;
        uint256 userDepositAmountOnce = 2 ether;
        vm.deal(userTmp, userDepositAmountOnce * userDepositTimes);
        vm.startPrank(userTmp);

        // 多次存款，每次都一定的数额
        for (uint256 i = 0; i < userDepositTimes; i++) {
            bank.deposit{value: userDepositAmountOnce}();
        }

        assertEq(
            bank.getUserDeposit(userTmp),
            userDepositAmountOnce * userDepositTimes
        );

        vm.stopPrank();
    }
}
