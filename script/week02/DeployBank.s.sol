// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {Bank} from "../src/Bank.sol";

contract DeployBank is Script {
    Bank public bank;

    function setUp() public {}

    function run() public {
        deployContract();
    }

    function deployContract() public returns (Bank) {
        vm.startBroadcast();
        bank = new Bank();
        vm.stopBroadcast();

        return bank;
    }
}
