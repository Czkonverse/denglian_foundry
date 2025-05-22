// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "src/week04/AirdopMerkleNFTMarket/AirdopMerkleNFTMarket.sol";
import {MockERC20Permit} from "src/week04/AirdopMerkleNFTMarket/MockERC20Permit.sol";
import {MockERC721} from "src/week04/AirdopMerkleNFTMarket/MockERC721.sol";
import {MerkleProof} from "src/week04/AirdopMerkleNFTMarket/MerkleProof.sol";

contract AirdropMerkleNFTMarketTest is Test {
    AirdropMerkleNFTMarket public market;
    MockERC20Permit public token;
    MockERC721 public nft;

    uint256 alicePrivateKey = 0x02;
    address alice = vm.addr(alicePrivateKey);

    uint256 bobPrivateKey = 0x03;
    address bob = vm.addr(bobPrivateKey);

    address owner = vm.addr(0x05);

    // 假设你已经链下生成了merkleRoot和proof，硬编码进来
    bytes32 public merkleRoot;
    bytes32[] public aliceProof;
    bytes32[] public bobProof;

    function setUp() public {
        // 给测试账户分配eth
        vm.deal(owner, 100 ether);
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);

        // 部署mock合约
        token = new MockERC20Permit("Test Token", "TTK");
        nft = new MockERC721("TestNFT", "TNFT");

        // mint测试token
        token.mint(alice, 10000 ether);
        token.mint(bob, 10000 ether);

        // mint NFT
        nft.mint(owner);
        nft.mint(owner);
        nft.mint(owner);

        // 构造白名单和 proof
        // 用 keccak256(abi.encodePacked(address)) 作为leaf
        // 例子：白名单为 [alice]
        address[] memory whitelist = new address[](1);
        whitelist[0] = alice;
        (merkleRoot, aliceProof) = buildMerkle(whitelist, alice);
        (, bobProof) = buildMerkle(whitelist, bob);

        // 部署market合约
        vm.prank(owner);
        market = new AirdropMerkleNFTMarket(merkleRoot);

        // owner approve NFT to market合约
        vm.prank(owner);
        nft.setApprovalForAll(address(market), true);
    }

    // ============ 测试用例 ============

    function testListNFT() public {
        vm.prank(owner);
        market.listNFT(address(nft), 0, address(token), 1000 ether);

        (address seller, address nftAddr, uint256 tokenId, address payToken, uint256 price, bool active) =
            market.listings(1);
        assertEq(seller, owner);
        assertEq(nftAddr, address(nft));
        assertEq(tokenId, 0);
        assertEq(payToken, address(token));
        assertEq(price, 1000 ether);
        assertTrue(active);
        assertEq(nft.ownerOf(0), address(market));
    }

    function testCancelListing() public {
        vm.prank(owner);
        market.listNFT(address(nft), 0, address(token), 1000 ether);

        vm.prank(owner);
        market.cancelListing(1);
        (,,,,, bool active) = market.listings(1);
        assertFalse(active);
        assertEq(nft.ownerOf(0), owner);
    }

    function testWhitelistBuyWithPermitAndMulticall() public {
        // 上架 tokenId 0
        vm.prank(owner);
        market.listNFT(address(nft), 0, address(token), 1000 ether);

        // 构造EIP-2612 permit 签名
        uint256 value = 500 ether; // 半价
        uint256 deadline = block.timestamp + 3600;
        (uint8 v, bytes32 r, bytes32 s) = getPermitSignature(
            alicePrivateKey, // 正确地传入 alice 的私钥
            alice, // owner
            address(market), // spender
            value,
            deadline
        );

        // permitPrePay的calldata
        bytes memory call1 =
            abi.encodeWithSelector(market.permitPrePay.selector, address(token), value, deadline, v, r, s);

        // claimNFT的calldata，listingId 是 1（第一个上架的 NFT）
        bytes memory call2 = abi.encodeWithSelector(market.claimNFT.selector, 1, aliceProof);

        // 合成 multicall
        bytes[] memory calls = new bytes[](2);
        calls[0] = call1;
        calls[1] = call2;

        vm.startPrank(alice);
        market.multiCall(calls);
        vm.stopPrank();

        // 检查 NFT 归属
        assertEq(nft.ownerOf(0), alice);
        // 检查 token 余额
        assertEq(token.balanceOf(owner), 500 ether);
        assertEq(token.balanceOf(alice), 9500 ether); // 10000 - 500
    }

    function testNonWhitelistFullPrice() public {
        // 上架
        vm.prank(owner);
        market.listNFT(address(nft), 0, address(token), 1000 ether);

        // 构造EIP-2612 permit 签名
        uint256 value = 1000 ether; // 全价
        uint256 deadline = block.timestamp + 3600;
        (uint8 v, bytes32 r, bytes32 s) = getPermitSignature(
            bobPrivateKey, // 正确地传入 bob 的私钥
            bob, // owner
            address(market), // spender
            value,
            deadline
        );
        // permitPrePay的calldata
        bytes memory call1 =
            abi.encodeWithSelector(market.permitPrePay.selector, address(token), value, deadline, v, r, s);
        // claimNFT的calldata
        bytes memory call2 = abi.encodeWithSelector(market.claimNFT.selector, 1, bobProof);
        bytes[] memory calls = new bytes[](2);
        calls[0] = call1;
        calls[1] = call2;

        vm.startPrank(bob);
        market.multiCall(calls);
        vm.stopPrank();

        assertEq(nft.ownerOf(0), bob);
        assertEq(token.balanceOf(owner), 1000 ether);
        assertEq(token.balanceOf(bob), 9000 ether);
    }

    // ============ 辅助方法 ============

    /// @dev 简易的merkle构造，单节点时proof为空
    function buildMerkle(address[] memory whitelist, address user) internal pure returns (bytes32, bytes32[] memory) {
        // keccak256(abi.encodePacked(addr))
        bytes32[] memory leaves = new bytes32[](whitelist.length);
        for (uint256 i = 0; i < whitelist.length; i++) {
            leaves[i] = keccak256(abi.encodePacked(whitelist[i]));
        }
        bytes32 root = leaves.length == 1 ? leaves[0] : bytes32(0); // 多节点略
        bytes32[] memory proof = new bytes32[](0); // 单节点proof为空
        return (root, proof);
    }

    /// @dev 构造 EIP-2612 permit 签名
    function getPermitSignature(uint256 privateKey, address owner, address spender, uint256 value, uint256 deadline)
        internal
        view
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        uint256 nonce = token.nonces(owner);

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                spender,
                value,
                nonce,
                deadline
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (v, r, s) = vm.sign(privateKey, digest);
    }
}
