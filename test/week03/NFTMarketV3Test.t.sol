// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "src/week03/NFTMarketV3.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 1e24);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockERC721 is ERC721 {
    uint256 public nextTokenId = 1;

    constructor() ERC721("Mock NFT", "MNFT") {}

    function mint(address to) external returns (uint256) {
        uint256 tokenId = nextTokenId++;
        _mint(to, tokenId);
        return tokenId;
    }
}

contract NFTMarketV3Test is Test {
    NFTMarketV3 public market;
    MockERC20 public token;
    MockERC721 public nft;

    address buyer;
    uint256 buyerKey;
    address seller;
    uint256 sellerKey;

    function setUp() public {
        buyerKey = 0xB0B;
        buyer = vm.addr(buyerKey);
        sellerKey = 0xA11CE;
        seller = vm.addr(sellerKey);

        market = new NFTMarketV3();
        token = new MockERC20();
        nft = new MockERC721();

        token.mint(buyer, 1e21);

        // Seller mints NFT and lists it
        vm.startPrank(seller);
        uint256 tokenId = nft.mint(seller);
        nft.approve(address(market), tokenId);
        market.listItem(address(nft), tokenId, address(token), 1e18);
        vm.stopPrank();
    }

    function testPermitBuy() public {
        uint256 tokenId = 1;
        uint256 price = 1e18;

        // Seller signs permit for buyer
        bytes32 messageHash = keccak256(
            abi.encodePacked(buyer, address(nft), tokenId, price)
        );
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            sellerKey,
            ethSignedMessageHash
        );
        bytes memory signature = abi.encodePacked(r, s, v);

        // Buyer approves token
        vm.prank(buyer);
        token.approve(address(market), price);

        // Buyer executes permitBuy
        vm.prank(buyer);
        market.permitBuy(address(nft), tokenId, price, signature);

        // Verify post-conditions
        assertEq(nft.ownerOf(tokenId), buyer);
        assertEq(token.balanceOf(seller), price);
    }

    function testCannotPermitBuyWithInvalidSignature() public {
        uint256 tokenId = 1;
        uint256 price = 1e18;

        // 假冒者签名（不是 seller）
        uint256 fakeSignerKey = 0xBADBAD;

        bytes32 messageHash = keccak256(
            abi.encodePacked(buyer, address(nft), tokenId, price)
        );
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            fakeSignerKey,
            ethSignedMessageHash
        );
        bytes memory fakeSignature = abi.encodePacked(r, s, v);

        // Buyer approves token
        vm.prank(buyer);
        token.approve(address(market), price);

        // Buyer tries to execute permitBuy with invalid signature
        vm.expectRevert(NFTMarketV3.NFTMarket__InvalidSignature.selector);
        vm.prank(buyer);
        market.permitBuy(address(nft), tokenId, price, fakeSignature);
    }
}
