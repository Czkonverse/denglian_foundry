// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {MerkleProof} from "./MerkleProof.sol"; // 引入 MerkleProof 库
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}

interface IERC20 {
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface IERC20Permit {
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;
}

contract AirdropMerkleNFTMarket is ReentrancyGuard {
    // 合约管理员
    address public owner;

    // 白名单的 Merkle Root
    bytes32 public merkleRoot;

    // 事件：Merkle根更新
    event MerkleRootUpdated(bytes32 newMerkleRoot);

    // 事件：管理员转移
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // NFT上架事件
    event NFTListed(
        uint256 indexed listingId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        address paymentToken,
        uint256 price
    );

    event ListingCanceled(uint256 indexed listingId, address indexed seller);

    event NFTPurchased(
        uint256 indexed listingId,
        address indexed buyer,
        address indexed seller,
        address paymentToken,
        uint256 pricePaid,
        bool isWhitelist
    );

    // 挂单结构
    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        address paymentToken;
        uint256 price;
        bool active;
    }

    uint256 private _listingIdCounter;
    mapping(uint256 => Listing) public listings;
    // 只允许管理员调用的修饰器

    modifier onlyOwner() {
        require(msg.sender == owner, "Not contract owner");
        _;
    }

    // 构造函数，设置初始管理员与白名单根
    constructor(bytes32 _merkleRoot) {
        owner = msg.sender;
        merkleRoot = _merkleRoot;
        emit OwnershipTransferred(address(0), msg.sender);
        emit MerkleRootUpdated(_merkleRoot);
    }

    // 设置新的Merkle Root（管理员权限）
    function setMerkleRoot(bytes32 newRoot) external onlyOwner {
        merkleRoot = newRoot;
        emit MerkleRootUpdated(newRoot);
    }

    // 转移管理员权限
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner is zero");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function listNFT(address nftContract, uint256 tokenId, address paymentToken, uint256 price) external nonReentrant {
        require(price > 0, "Price must be > 0");
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "Not NFT owner");

        // 将NFT转入合约托管
        IERC721(nftContract).safeTransferFrom(msg.sender, address(this), tokenId);

        // 创建Listing记录
        _listingIdCounter += 1;
        listings[_listingIdCounter] = Listing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            paymentToken: paymentToken,
            price: price,
            active: true
        });

        emit NFTListed(_listingIdCounter, msg.sender, nftContract, tokenId, paymentToken, price);
    }

    function cancelListing(uint256 listingId) external nonReentrant {
        require(listings[listingId].seller != address(0), "Listing does not exist");

        Listing storage listing = listings[listingId];

        require(listing.active, "Listing not active");
        require(listing.seller != address(0), "Invalid listing");

        // 只能卖家本人 或 管理员 取消
        require(msg.sender == listing.seller || msg.sender == owner, "Not authorized");

        // 标记为无效
        listings[listingId].active = false;
        // 把NFT退还给卖家
        IERC721(listing.nftContract).safeTransferFrom(address(this), listing.seller, listing.tokenId);

        emit ListingCanceled(listingId, listing.seller);
    }

    function permitPrePay(address token, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
        nonReentrant
    {
        // 使用 EIP-2612 permit 授权 Market 合约支配 value 数量的 token
        IERC20Permit(token).permit(
            msg.sender, // 授权人
            address(this), // 授权给本市场合约
            value,
            deadline,
            v,
            r,
            s
        );
    }

    function claimNFT(uint256 listingId, bytes32[] calldata merkleProof) external nonReentrant {
        require(listings[listingId].seller != address(0), "Listing does not exist");

        Listing storage listing = listings[listingId];

        require(listing.active, "Listing inactive");
        require(listing.seller != address(0), "Invalid listing");
        require(msg.sender != listing.seller, "Seller cannot buy own NFT");

        // 标记为无效，防止重入或重复购买

        listings[listingId].active = false;

        // 判断白名单资格（Keccak256打包地址）
        bool isWhitelist = false;
        if (merkleRoot != bytes32(0)) {
            bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
            isWhitelist = MerkleProof.verify(merkleProof, merkleRoot, leaf);
        }

        // 半价 or 原价
        uint256 priceToPay = isWhitelist ? listing.price / 2 : listing.price;

        // 从买家账户转 token 到卖家
        require(
            IERC20(listing.paymentToken).transferFrom(msg.sender, listing.seller, priceToPay), "Token transfer failed"
        );

        // 转出NFT
        IERC721(listing.nftContract).safeTransferFrom(address(this), msg.sender, listing.tokenId);

        emit NFTPurchased(listingId, msg.sender, listing.seller, listing.paymentToken, priceToPay, isWhitelist);
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        pure
        returns (bytes4)
    {
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }

    function multiCall(bytes[] calldata calls) external returns (bytes[] memory results) {
        results = new bytes[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory ret) = address(this).delegatecall(calls[i]);
            require(success, "multiCall: subcall failed");
            results[i] = ret;
        }
    }
}
