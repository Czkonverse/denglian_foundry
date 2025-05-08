// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {console} from "forge-std/console.sol";

contract Bank {
    error Bank__SendZeroMoney();
    error Bank__NotOwner();
    error Bank__WithdrawMoneyFailed();

    address public immutable i_owner;
    uint256 public constant LEAST_MONEY = 0 ether;

    uint private s_userNumber = 0;
    uint256 private s_mimimumDeposit = 0;
    mapping(address payer => uint money) private s_records;
    address[] public s_top3Users;

    event BankDeposit(address indexed payer);
    event Top3Updated(address[] top3Users);

    constructor() {
        // onwer
        i_owner = msg.sender;
    }

    function deposit() public payable {
        // deposit money > 0
        if (msg.value <= LEAST_MONEY) {
            revert Bank__SendZeroMoney();
        }

        if (s_records[msg.sender] == 0) {
            s_userNumber++;
        }

        s_records[msg.sender] += msg.value;
        emit BankDeposit(msg.sender);

        updateTop3(msg.sender);
    }

    function updateTop3(address user) public {
        if (s_userNumber == 0) {
            // 没有用户，直接return
            return;
        } else if (s_userNumber == 1) {
            // 只有一个用户，直接添加
            s_top3Users.push(user);
        } else {
            // 2个及2个以上用户，需要排序，取出top3
            s_top3Users.push(user);
            uint256[] memory candidatesMoney = new uint256[](
                s_top3Users.length
            );
            for (uint256 i = 0; i < s_top3Users.length; i++) {
                candidatesMoney[i] = s_records[s_top3Users[i]];
            }

            uint256[] memory sortedIndices = sortIndicesByDescendingValue(
                candidatesMoney
            );

            // 取出前 3 名用户
            uint256 topCountLength = s_top3Users.length;
            if (s_top3Users.length > 3) {
                topCountLength = 3;
            }
            address[] memory new_topUsers = new address[](topCountLength);
            for (uint8 i = 0; i < topCountLength; i++) {
                new_topUsers[i] = s_top3Users[sortedIndices[i]];
            }

            s_top3Users = new address[](topCountLength);
            for (uint8 i = 0; i < topCountLength; i++) {
                s_top3Users[i] = new_topUsers[i];
            }
        }
    }

    function sortIndicesByDescendingValue(
        uint256[] memory values
    ) public pure returns (uint256[] memory) {
        uint256 length = values.length;
        uint256[] memory indices = new uint256[](length);

        // 初始化索引数组：0, 1, 2, ..., length-1
        for (uint256 i = 0; i < length; i++) {
            indices[i] = i;
        }

        // 使用简单的选择排序（从大到小）
        for (uint256 i = 0; i < length; i++) {
            uint256 maxIndex = i;
            for (uint256 j = i + 1; j < length; j++) {
                if (values[indices[j]] > values[indices[maxIndex]]) {
                    maxIndex = j;
                }
            }

            // 交换索引位置
            if (maxIndex != i) {
                uint256 temp = indices[i];
                indices[i] = indices[maxIndex];
                indices[maxIndex] = temp;
            }
        }

        return indices;
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert Bank__NotOwner();
        }
        _;
    }

    function withdraw() public onlyOwner {
        // Withdraw logic
        (bool callSuccess, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        if (!callSuccess) {
            revert Bank__WithdrawMoneyFailed();
        }
    }

    // Getter functions
    function getUserDeposit(address user) public view returns (uint256) {
        return s_records[user];
    }

    function getUserNumber() public view returns (uint256) {
        return s_userNumber;
    }

    function getTop3Users() public view returns (address[] memory) {
        return s_top3Users;
    }
}
