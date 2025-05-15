// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Test, console2} from "forge-std/Test.sol";
import {NFTMarket} from "src/week02/NFTMarket.sol";
import {ERC20StdOnlyOwner} from "src/token/ERC20StdOnlyOwner.sol";
import {ERC721Std} from "src/token/ERC721Std.sol";

contract NFTMarketInvariantTest is Test {
    NFTMarket public nftMarket;
    ERC20StdOnlyOwner public usdc;
    ERC721Std public nft;

    address public seller;
    address public buyer;

    function setUp() public {
        seller = vm.addr(1);
        buyer = vm.addr(2);
        vm.label(seller, "Seller");
        vm.label(buyer, "Buyer");

        nftMarket = new NFTMarket();
        usdc = new ERC20StdOnlyOwner("USDC", "USDC", 6);
        nft = new ERC721Std("NFT", "NFT");

        usdc.mint(buyer, 1_000_000 * 1e6);
        vm.prank(buyer);
        usdc.approve(address(nftMarket), type(uint256).max);

        for (uint256 i = 1; i <= 5; i++) {
            nft.mint(seller, i);
        }

        vm.prank(seller);
        nft.setApprovalForAll(address(nftMarket), true);

        // 限制 fuzzer 只模糊调用 nftMarket
        targetContract(address(nftMarket));
    }

    // 不变量：market 永远不应该有 token
    function invariantNoTokenInMarket() public view {
        uint256 marketBalance = usdc.balanceOf(address(nftMarket));
        assertEq(marketBalance, 0, "NFTMarket should never hold any Token");
    }

    // 让 fuzzer 调用 list + buy 流程
    function listAndBuy(uint256 id, uint256 priceRaw) public {
        vm.assume(seller != buyer); // 可选防御性限制

        id = bound(id, 1, 5);
        uint256 price = bound(priceRaw, 1e4, 1_000 * 1e6);

        vm.startPrank(seller);
        nftMarket.list(address(nft), id, address(usdc), price);
        vm.stopPrank();

        vm.prank(buyer);
        try nftMarket.buyNFT(address(nft), id) {
            // success
        } catch {
            // ignore failure
        }
    }
}
