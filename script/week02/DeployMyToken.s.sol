// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {MyToken} from "../src/MyToken.sol";

contract DeployMyToken is Script {
    MyToken public myToken;

    string public name = "KunverseTokenERC20";
    string public symbol = "KTK";

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        vm.deal(address(this), 1e18);
        myToken = new MyToken(name, symbol);

        vm.stopBroadcast();
    }
}
