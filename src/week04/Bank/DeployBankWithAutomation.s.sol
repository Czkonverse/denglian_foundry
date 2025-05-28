// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "./BankWithAutomation.sol";

contract DeployBankWithAutomation is Script {
    function run() external returns (BankWithAutomation) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // 配置参数
        uint256 threshold = 0.1 ether; // 0.1 ETH 作为测试阈值
        address recipient = vm.envAddress("RECIPIENT_ADDRESS"); // 从环境变量读取

        vm.startBroadcast(deployerPrivateKey);

        BankWithAutomation bank = new BankWithAutomation(threshold, recipient);

        console.log("BankWithAutomation deployed to:", address(bank));
        console.log("Owner:", bank.owner());
        console.log("Threshold:", threshold);
        console.log("Recipient:", recipient);

        vm.stopBroadcast();

        return bank;
    }
}
