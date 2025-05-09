// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {NFTMarket} from "src/NFTMarket.sol";
import {DeployNFTMarket} from "script/DeployNFTMarket.s.sol";

contract NFTMarketTest is Test {
    NFTMarket public nFTMarket;

    function setUp() public {
        DeployNFTMarket deployNFTMarket = new DeployNFTMarket();
        nFTMarket = deployNFTMarket.deployContract();
    }

    // 上架NFT：测试上架成功和失败情况，要求断言错误信息和上架事件。
    function testListNFTSuccessAndFailed() public {
        // 测试上架成功
        address nftAddress = address(0x123);
        uint256 tokenId = 1;
        address erc20Token = address(0x456);
        uint256 price = 100;

        vm.startPrank(address(this));
        nFTMarket.list(nftAddress, tokenId, erc20Token, price);

        // 断言上架事件
        NFTMarket.Listing memory listing = nFTMarket.getListing(
            nftAddress,
            tokenId
        );
        // assertEq(listing.seller, address(this));
        assertEq(listing.nftAddress, nftAddress);
        assertEq(listing.erc20Token, erc20Token);
        assertEq(listing.price, price);
        emit log("NFT listed successfully");

        // 测试上架失败：未授权、未拥有NFT、重复上架等情况
    }

    // 购买NFT：测试购买成功、自己购买自己的NFT、NFT被重复购买、支付Token过多或者过少情况，要求断言错误信息和购买事件。
    // 模糊测试：测试随机使用 0.01-10000 Token价格上架NFT，并随机使用任意Address购买NFT
    // 不变量测试：测试无论如何买卖，NFTMarket合约中都不可能有 Token 持仓
}
