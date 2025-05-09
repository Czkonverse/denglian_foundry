// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {NFTMarket} from "src/week02/NFTMarket.sol";
import {DeployNFTMarket} from "script/week02/DeployNFTMarket.s.sol";
import {ERC20Std} from "src/token/ERC20Std.sol";
import {ERC721Std} from "src/token/ERC721Std.sol";

contract NFTMarketTest is Test {
    NFTMarket public nfTMarket;
    ERC20Std public usdc;
    ERC721Std public nft;

    address public seller;
    address public buyer;
    uint256 public tokenId = 1;
    uint256 public priceUint = 1 * 10 ** 6; // 1 USDC

    function setUp() public {
        seller = vm.addr(1);
        buyer = vm.addr(2);
        vm.label(seller, "Seller");
        vm.label(buyer, "Buyer");
        vm.deal(seller, 10 ether);
        vm.deal(buyer, 10 ether);

        // deploy
        // NFTMarket
        nfTMarket = new NFTMarket();
        // ERC20部署
        usdc = new ERC20Std("USDC", "USDC", 6);
        // ERC721部署
        nft = new ERC721Std("NFT", "NFT");

        // usdc mint to buyer
        usdc.mint(buyer, priceUint * 20000);
        // usdc approve NFTMarket
        vm.prank(buyer);
        usdc.approve(address(nfTMarket), priceUint * 10);

        // mint NFT
        vm.prank(address(this));
        nft.mint(seller, tokenId);

        // seller approve NFTMarket
        vm.prank(seller);
        nft.approve(address(nfTMarket), tokenId);
    }

    // 上架NFT：测试上架成功和失败情况，要求断言错误信息和上架事件。
    function testListNftSuccess() public {
        // 测试上架成功：拥有NFT、授权NFTMarket合约、Token价格大于0
        uint256 price = priceUint * 2;
        vm.prank(seller);
        nfTMarket.list(address(nft), tokenId, address(usdc), price);

        // 获取上架信息
        // 获取上架信息并断言正确性
        (
            address listSeller,
            address listNftAddr,
            address listToken,
            uint256 listPrice
        ) = nfTMarket.listings(address(nft), tokenId);

        assertEq(listSeller, seller);
        assertEq(listNftAddr, address(nft));
        assertEq(listToken, address(usdc));
        assertEq(listPrice, price);
    }

    // 测试上架失败：未授权、未拥有NFT、重复上架等情况
    function testListNftFail() public {
        // 铸一个新的币，但没有授权 NFTMarket·
        uint256 price = priceUint * 3;
        uint256 newTokenId = tokenId + 1;
        vm.prank(seller);
        nft.mint(seller, newTokenId);

        vm.prank(seller);
        vm.expectRevert(NFTMarket.NFTMarket__NotApprovedForTransfer.selector);
        nfTMarket.list(address(nft), newTokenId, address(usdc), price);

        // 2. 未拥有NFT
        vm.prank(buyer);
        vm.expectRevert(NFTMarket.NFTMarket__NotOwner.selector);
        nfTMarket.list(address(nft), newTokenId, address(usdc), price);

        // // 3. 重复上架
        // 先上架一次
        vm.prank(seller);
        nfTMarket.list(address(nft), tokenId, address(usdc), price);
        vm.prank(seller);
        vm.expectRevert(NFTMarket.NFTMarket__AlreadyListed.selector);
        nfTMarket.list(address(nft), tokenId, address(usdc), price);
    }

    // 购买NFT：测试购买成功、自己购买自己的NFT、NFT被重复购买、支付Token过多或者过少情况，要求断言错误信息和购买事件。
    function testBuyNftSuccess() public {
        // seller上架
        vm.prank(seller);
        nfTMarket.list(address(nft), tokenId, address(usdc), priceUint);

        // 购买NFT
        vm.prank(buyer);
        nfTMarket.buyNFT(address(nft), tokenId);
        address nowOnwer = nft.ownerOf(tokenId);
        assertEq(nowOnwer, buyer);
    }

    function testBuySellerOwnNFT() public {
        // seller上架
        vm.prank(seller);
        nfTMarket.list(address(nft), tokenId, address(usdc), priceUint);

        // 给 seller 自己也 mint 一些 usdc 以便能购买
        usdc.mint(seller, priceUint * 2);
        vm.prank(seller);
        usdc.approve(address(nfTMarket), priceUint * 2);

        // 尝试由 seller 自己购买自己上架的 NFT，应该失败
        vm.prank(seller);
        vm.expectRevert(NFTMarket.NFTMarket__BuyerIsSeller.selector);
        nfTMarket.buyNFT(address(nft), tokenId);
    }

    function testBuyNftTwiceShouldFail() public {
        // seller上架
        vm.prank(seller);
        nfTMarket.list(address(nft), tokenId, address(usdc), priceUint);

        // 购买NFT
        vm.prank(buyer);
        nfTMarket.buyNFT(address(nft), tokenId);

        // 再次购买同一NFT，应该失败
        vm.prank(buyer);
        vm.expectRevert(NFTMarket.NFTMarket__NotListing.selector);
        nfTMarket.buyNFT(address(nft), tokenId);
    }

    function testBuyNftPayLessShouldFail() public {
        // seller上架
        vm.prank(seller);
        nfTMarket.list(address(nft), tokenId, address(usdc), priceUint * 30000);

        // 购买NFT，支付的Token数量少于上架价格，应该失败
        vm.prank(buyer);
        vm.expectRevert(
            NFTMarket.NFTMarket__NotEnoughAmountTokenToBuy.selector
        );
        nfTMarket.buyNFT(address(nft), tokenId);
    }

    function testBuyNftPayMoreThanPrice() public {
        // seller上架
        vm.prank(seller);
        nfTMarket.list(address(nft), tokenId, address(usdc), priceUint);

        // 购买NFT，买家的token多于上架价格
        uint256 buyerBalanceBefore = usdc.balanceOf(buyer);

        vm.prank(buyer);
        nfTMarket.buyNFT(address(nft), tokenId);

        // 获取买家余额
        uint256 buyerBalance = usdc.balanceOf(buyer);
        assertEq(buyerBalance, buyerBalanceBefore - priceUint);
    }

    // 模糊测试：测试随机使用 0.01-10000 Token价格上架NFT，并随机使用任意Address购买NFT
    function testFuzzListAndBuyNFT(uint96 rawPrice, uint160 buyerPk) public {
        vm.assume(buyerPk != 0);

        uint256 price = bound(uint256(rawPrice), 1e4, 10_000 * 1e6); // USDC with 6 decimals

        address randomBuyer = vm.addr(buyerPk);
        vm.assume(randomBuyer != seller);
        vm.assume(randomBuyer != address(0));

        // 使用唯一 tokenId
        uint256 fuzzTokenId = (uint256(
            keccak256(abi.encodePacked(rawPrice, buyerPk))
        ) % 1e6) + 1;
        nft.mint(seller, fuzzTokenId);

        // 上架
        vm.prank(seller);
        nft.approve(address(nfTMarket), fuzzTokenId);
        vm.prank(seller);
        nfTMarket.list(address(nft), fuzzTokenId, address(usdc), price);

        // buyer 准备资金
        usdc.mint(randomBuyer, price);
        vm.startPrank(randomBuyer);
        usdc.approve(address(nfTMarket), price);

        // 购买 NFT
        nfTMarket.buyNFT(address(nft), fuzzTokenId);

        // 验证 NFT 转移
        assertEq(nft.ownerOf(fuzzTokenId), randomBuyer);

        // 验证资金转移
        assertEq(usdc.balanceOf(seller), price);

        vm.stopPrank();
    }

    // 不变量测试：测试无论如何买卖，NFTMarket合约中都不可能有 Token 持仓
}
