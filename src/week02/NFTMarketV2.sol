// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFTMarket is ReentrancyGuard {
    error NFTMarket__NotOwner();
    error NFTMarket__NotApprovedForTransfer();
    error NFTMarket__NotListing();
    error NFTMarket__NotRequiredToken();
    error NFTMarket__NotEnoughAmountTokenToBuy();
    error NFTMarket__AlreadyListed();
    error NFTMarket__BuyerIsSeller();

    struct Listing {
        address seller;
        address nftAddress;
        address erc20Token;
        uint256 price;
    }

    mapping(address => mapping(uint256 => Listing)) public listings;

    event ListingCreated(
        address indexed nftAddress,
        uint256 indexed nftTokenId,
        address indexed erc20Token,
        uint256 price
    );
    event ListingRemoved(
        address indexed nftAddress,
        uint256 indexed nftTokenId
    );
    event NFTPurchased(
        address indexed buyer,
        address indexed nftAddress,
        uint256 indexed tokenId,
        address erc20Token,
        uint256 price
    );

    function list(
        address _nftAddress,
        uint256 _nftTokenId,
        address _tokenAddress,
        uint256 _price
    ) external {
        IERC721 nft = IERC721(_nftAddress);

        if (nft.ownerOf(_nftTokenId) != msg.sender) {
            revert NFTMarket__NotOwner();
        }

        if (
            nft.getApproved(_nftTokenId) != address(this) &&
            !nft.isApprovedForAll(msg.sender, address(this))
        ) {
            revert NFTMarket__NotApprovedForTransfer();
        }

        if (listings[_nftAddress][_nftTokenId].price != 0) {
            revert NFTMarket__AlreadyListed();
        }

        nft.transferFrom(msg.sender, address(this), _nftTokenId);

        listings[_nftAddress][_nftTokenId] = Listing({
            seller: msg.sender,
            nftAddress: _nftAddress,
            erc20Token: _tokenAddress,
            price: _price
        });

        emit ListingCreated(_nftAddress, _nftTokenId, _tokenAddress, _price);
    }

    function cancelListing(address _nftAddress, uint256 _nftTokenId) external {
        Listing memory listing = listings[_nftAddress][_nftTokenId];
        if (listing.price == 0) revert NFTMarket__NotListing();
        if (listing.seller != msg.sender) revert NFTMarket__NotOwner();

        IERC721(_nftAddress).transferFrom(
            address(this),
            msg.sender,
            _nftTokenId
        );

        delete listings[_nftAddress][_nftTokenId];
        emit ListingRemoved(_nftAddress, _nftTokenId);
    }

    function buyNFT(
        address _nftAddress,
        uint256 _nftTokenId
    ) external nonReentrant {
        Listing memory listing = listings[_nftAddress][_nftTokenId];
        if (listing.price == 0) revert NFTMarket__NotListing();
        if (listing.seller == msg.sender) revert NFTMarket__BuyerIsSeller();

        IERC20 erc20 = IERC20(listing.erc20Token);
        if (erc20.balanceOf(msg.sender) < listing.price)
            revert NFTMarket__NotEnoughAmountTokenToBuy();

        delete listings[_nftAddress][_nftTokenId];

        require(
            erc20.transferFrom(msg.sender, listing.seller, listing.price),
            "Transfer failed"
        );
        IERC721(listing.nftAddress).transferFrom(
            address(this),
            msg.sender,
            _nftTokenId
        );

        emit ListingRemoved(_nftAddress, _nftTokenId);
        emit NFTPurchased(
            msg.sender,
            _nftAddress,
            _nftTokenId,
            listing.erc20Token,
            listing.price
        );
    }

    function tokensReceived(
        address _from,
        uint256 _amount,
        bytes calldata _data
    ) external nonReentrant {
        (address nftAddress, uint256 tokenId) = abi.decode(
            _data,
            (address, uint256)
        );
        Listing memory listing = listings[nftAddress][tokenId];

        if (listing.price == 0) revert NFTMarket__NotListing();
        if (msg.sender != listing.erc20Token)
            revert NFTMarket__NotRequiredToken();
        if (_amount < listing.price)
            revert NFTMarket__NotEnoughAmountTokenToBuy();

        delete listings[nftAddress][tokenId];

        require(
            IERC20(msg.sender).transfer(listing.seller, listing.price),
            "Transfer failed"
        );
        IERC721(nftAddress).transferFrom(address(this), _from, tokenId);

        emit ListingRemoved(nftAddress, tokenId);
        emit NFTPurchased(
            _from,
            nftAddress,
            tokenId,
            msg.sender,
            listing.price
        );
    }

    function getListing(
        address _nftAddress,
        uint256 _nftTokenId
    ) external view returns (Listing memory) {
        return listings[_nftAddress][_nftTokenId];
    }
}
