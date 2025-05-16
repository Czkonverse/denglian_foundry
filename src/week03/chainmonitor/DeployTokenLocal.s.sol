// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "src/token/ERC20StdOnlyOwner.sol";

contract DeployTokenLocal is Script {
    function run() external {
        // 从环境变量中读取部署者私钥
        uint256 deployerKey = vm.envUint("PRIVATE_KEY_ANVIL_ONE");
        address deployer = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);

        // 根据你的合约构造函数写法，传入名称、符号、初始总量
        ERC20StdOnlyOwner token = new ERC20StdOnlyOwner(
            "MyToken",
            "MTK",
            6,
            1000000 * 10 ** 6 // 1000000 tokens with 6 decimals
        );
        token.transfer(deployer, 1000000 * 10 ** 6); // Transfer all tokens to deployer

        console.log("MyToken deployed at:", address(token));

        vm.stopBroadcast();
    }
}
