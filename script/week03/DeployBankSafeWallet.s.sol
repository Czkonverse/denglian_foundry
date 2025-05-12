// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "../../src/week03/BankSafeWallet.sol";

contract DeployBankSafeWallet is Script {
    function run() external {
        vm.startBroadcast();

        // 读取环境变量中 Safe 地址
        address safe = vm.envAddress("SEPOLIA_SAFE_ADDRESS");
        console.log("Safe address:", safe);

        // 部署 Bank 合约并设 Safe 为管理员
        BankSafeWallet bank = new BankSafeWallet(safe);

        console.log("Bank contract deployed at:", address(bank));

        vm.stopBroadcast();
    }
}
