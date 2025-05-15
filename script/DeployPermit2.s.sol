// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";
import {Permit2} from "permit2/src/Permit2.sol";

contract DeployPermit2Script is Script {
    function run() external returns (address) {
        vm.startBroadcast();
        
        // 部署 Permit2 合约
        Permit2 permit2 = new Permit2();
        
        vm.stopBroadcast();
        
        return address(permit2);
    }
} 