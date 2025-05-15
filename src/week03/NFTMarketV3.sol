// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract NFTMarketV3 is ReentrancyGuard {
    using ECDSA for bytes32;

    error NFTMarket__NotOwner();
    error NFTMarket__NotApprovedForTransfer();
    error NFTMarket__NotListing();
    error NFTMarket__NotRequiredToken();
    error NFTMarket__NotEnoughAmountTokenToBuy();
    error NFTMarket__AlreadyListed();
    error NFTMarket__BuyerIsSeller();
    error NFTMarket__InvalidSignature();

    struct Listing {
        address seller;
        address nftAddress;
        address erc20Token;
        uint256 price;
    }

    mapping(address => mapping(uint256 => Listing)) public listings;
    mapping(address => uint256) public nonces;

    event ListingCreated(
        address indexed nftAddress,
        uint256 indexed tokenId,
        address indexed erc20Token,
        uint256 price
    );
    event ListingRemoved(address indexed nftAddress, uint256 indexed tokenId);
    event NFTPurchased(
        address indexed nftAddress,
        uint256 indexed tokenId,
        address buyer,
        address seller,
        uint256 price
    );

    function listItem(
        address nftAddress,
        uint256 tokenId,
        address erc20Token,
        uint256 price
    ) external {
        IERC721 nft = IERC721(nftAddress);

        if (nft.ownerOf(tokenId) != msg.sender) revert NFTMarket__NotOwner();
        if (nft.getApproved(tokenId) != address(this))
            revert NFTMarket__NotApprovedForTransfer();
        if (listings[nftAddress][tokenId].seller != address(0))
            revert NFTMarket__AlreadyListed();

        listings[nftAddress][tokenId] = Listing(
            msg.sender,
            nftAddress,
            erc20Token,
            price
        );

        emit ListingCreated(nftAddress, tokenId, erc20Token, price);
    }

    function removeItem(address nftAddress, uint256 tokenId) external {
        Listing memory listing = listings[nftAddress][tokenId];
        if (listing.seller != msg.sender) revert NFTMarket__NotOwner();

        delete listings[nftAddress][tokenId];
        emit ListingRemoved(nftAddress, tokenId);
    }

    function buyItem(
        address nftAddress,
        uint256 tokenId
    ) external nonReentrant {
        _buy(nftAddress, tokenId, msg.sender);
    }

    function _buy(address nftAddress, uint256 tokenId, address buyer) internal {
        Listing memory listing = listings[nftAddress][tokenId];
        if (listing.seller == address(0)) revert NFTMarket__NotListing();
        if (buyer == listing.seller) revert NFTMarket__BuyerIsSeller();

        IERC20 token = IERC20(listing.erc20Token);
        if (token.allowance(buyer, address(this)) < listing.price) {
            revert NFTMarket__NotEnoughAmountTokenToBuy();
        }

        delete listings[nftAddress][tokenId];

        require(
            token.transferFrom(buyer, listing.seller, listing.price),
            "ERC20 transfer failed"
        );

        IERC721(listing.nftAddress).safeTransferFrom(
            listing.seller,
            buyer,
            tokenId
        );

        emit NFTPurchased(
            nftAddress,
            tokenId,
            buyer,
            listing.seller,
            listing.price
        );
    }

    function _toEthSignedMessageHash(
        bytes32 hash
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
            );
    }

    function permitBuy(
        address nftAddress,
        uint256 tokenId,
        uint256 price,
        uint256 deadline,
        bytes calldata signature
    ) external nonReentrant {
        if (block.timestamp > deadline) revert("Signature expired");

        Listing memory listing = listings[nftAddress][tokenId];
        address tokenSeller = listing.seller;

        if (listing.price != price) revert NFTMarket__NotRequiredToken();

        bytes32 messageHash = keccak256(
            abi.encodePacked(
                msg.sender,
                nftAddress,
                tokenId,
                price,
                nonces[msg.sender],
                deadline
            )
        );
        bytes32 ethSignedHash = _toEthSignedMessageHash(messageHash);

        address recovered = ethSignedHash.recover(signature);

        if (recovered != tokenSeller) {
            revert NFTMarket__InvalidSignature();
        }

        nonces[msg.sender]++;

        _buy(nftAddress, tokenId, msg.sender);
    }
}
