// script/DeployTokenBank.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "src/week02/MyToken.sol";
import "src/week02/TokenBankMultiToken.sol";

contract DeployTokenBankMultiToken is Script {
    function run() external {
        // 从环境变量中读取部署者私钥
        uint256 deployerKey = vm.envUint("PRIVATE_KEY_LOCAL");
        address deployer = vm.addr(deployerKey);

        // 开始广播交易（部署）
        vm.startBroadcast(deployerKey);

        // 1 部署 ERC20 测试代币：MyToken - 1
        MyToken token = new MyToken("MyToken", "MTK", 1000 * 10 ** 18);
        console.log("MyToken address:", address(token));
        // 分配给部署者 1000 个代币
        token.transfer(deployer, 1000 * 10 ** 18);

        // 2 部署 ERC20 测试代币：KToken - 2
        MyToken kToken = new MyToken("KToken", "KTK", 500 * 10 ** 18);
        console.log("KToken address:", address(kToken));
        // 分配给部署者 500 个 KToken
        kToken.transfer(deployer, 500 * 10 ** 18);

        // 3 部署 TokenBankMultiToken
        TokenBankMultiToken bank = new TokenBankMultiToken();
        console.log("TokenBankMultiToken address:", address(bank));

        vm.stopBroadcast();
    }
}
