// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {console} from "forge-std/console.sol";

interface IERC721 {
    function transferFrom(address from, address to, uint256 tokenId) external;

    function ownerOf(uint256 tokenId) external view returns (address);

    function isApprovedForAll(
        address owner,
        address operator
    ) external view returns (bool);

    function getApproved(uint256 tokenId) external view returns (address);
}

interface IERC20 {
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

interface IERC20Receiver {
    function tokensReceived(
        address from,
        uint256 amount,
        bytes calldata data
    ) external;
}

contract NFTMarket {
    // errors
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

    // NFT address => NFT tokenId => Listing
    mapping(address => mapping(uint256 => Listing)) public listings;

    // event
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

    // function
    function list(
        address _nftAddress,
        uint256 _nftTokenId,
        address _tokenAddress,
        uint256 _price
    ) external {
        // ERC721 check
        IERC721 nft = IERC721(_nftAddress);

        // Check if the caller is the owner of the NFT
        if (nft.ownerOf(_nftTokenId) != msg.sender) {
            revert NFTMarket__NotOwner();
        }
        // 确保NFT市场合约 NFTMarket 有权转移卖家的 NFT
        if (nft.getApproved(_nftTokenId) != address(this)) {
            revert NFTMarket__NotApprovedForTransfer();
        }
        // 确保没有重复上架
        if (listings[_nftAddress][_nftTokenId].price != 0) {
            revert NFTMarket__AlreadyListed();
        }

        // Create a new listing
        Listing memory listing = Listing({
            seller: msg.sender,
            nftAddress: _nftAddress,
            erc20Token: _tokenAddress,
            price: _price
        });

        listings[_nftAddress][_nftTokenId] = listing;

        emit ListingCreated(_nftAddress, _nftTokenId, _tokenAddress, _price);
    }

    function cancelListing(address _nftAddress, uint256 _nftTokenId) external {
        // Check if the caller is the owner of the NFT
        Listing memory listing = listings[_nftAddress][_nftTokenId];
        if (listing.price == 0) {
            revert NFTMarket__NotListing();
        }
        if (listing.seller != msg.sender) {
            revert NFTMarket__NotOwner();
        }

        // Delete the listing
        delete listings[_nftAddress][_nftTokenId];
        emit ListingRemoved(_nftAddress, _nftTokenId);
    }

    function buyNFT(address _nftAddress, uint256 _nftTokenId) external {
        // Check if the listing exists
        // 没有上架的话，会返回默认值：Listing(seller=0x0, nftAddress=0x0, ..., price=0)，所以可以用price=0来判断是否上架
        Listing memory listing = listings[_nftAddress][_nftTokenId];
        if (listing.price == 0) {
            revert NFTMarket__NotListing();
        }

        // 不能购买自己的NFT
        if (listing.seller == msg.sender) {
            revert NFTMarket__BuyerIsSeller();
        }

        // ERC20 token
        IERC20 erc20 = IERC20(listing.erc20Token);
        if (erc20.balanceOf(msg.sender) < listing.price) {
            revert NFTMarket__NotEnoughAmountTokenToBuy();
        }
        erc20.transferFrom(msg.sender, listing.seller, listing.price);
        // ERC721 nft transfer
        IERC721 nft = IERC721(listing.nftAddress);
        nft.transferFrom(listing.seller, msg.sender, _nftTokenId);

        // Delete the listing
        delete listings[_nftAddress][_nftTokenId];
        emit ListingRemoved(_nftAddress, _nftTokenId);
    }

    function tokensReceived(
        address _from,
        uint256 _amount,
        bytes calldata _data
    ) external {
        (address nftAddress, uint256 tokenId) = abi.decode(
            _data,
            (address, uint256)
        );

        Listing memory listing = listings[nftAddress][tokenId];
        // check if the token is listed
        if (listing.price == 0) {
            revert NFTMarket__NotListing();
        }
        // check if the token is the required token
        if (msg.sender != listing.erc20Token) {
            revert NFTMarket__NotRequiredToken();
        }
        // check if the amount is enough
        if (_amount < listing.price) {
            revert NFTMarket__NotEnoughAmountTokenToBuy();
        }

        // transfer the NFT to the buyer
        IERC721(nftAddress).transferFrom(address(this), _from, tokenId);
        // transfer the token to the seller
        IERC20(listing.erc20Token).transferFrom(
            address(this),
            listing.seller,
            listing.price
        );

        // delete the listing
        delete listings[nftAddress][tokenId];
        emit ListingRemoved(nftAddress, tokenId);
    }

    function getListing(
        address _nftAddress,
        uint256 _nftTokenId
    ) external view returns (Listing memory) {
        return listings[_nftAddress][_nftTokenId];
    }
}
