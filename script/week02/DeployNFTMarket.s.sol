// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {NFTMarket} from "src/week02/NFTMarket.sol";

contract DeployNFTMarket is Script {
    NFTMarket public nFTMarket;

    function setUp() public {}

    function run() public {
        deployContract();
    }

    function deployContract() public returns (NFTMarket) {
        vm.startBroadcast();
        nFTMarket = new NFTMarket();
        vm.stopBroadcast();

        return nFTMarket;
    }
}
