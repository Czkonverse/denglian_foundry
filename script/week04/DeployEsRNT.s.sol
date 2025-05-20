// script/DeployEsRNT.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {esRNT} from "src/week04/esRNT/esRNT.sol";

contract DeployEsRNT is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY_ANVIL_ONE");

        vm.startBroadcast(deployerKey);
        esRNT instance = new esRNT();
        console.log("esRNT deployed at:", address(instance));
        vm.stopBroadcast();
    }
}
