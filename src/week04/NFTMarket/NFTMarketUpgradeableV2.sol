// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract NFTMarketUpgradeableV2 is Initializable, ReentrancyGuardUpgradeable, UUPSUpgradeable, OwnableUpgradeable {
    using ECDSA for bytes32;

    // Custom errors
    error NFTMarket__NotOwner();
    error NFTMarket__NotApprovedForTransfer();
    error NFTMarket__NotListing();
    error NFTMarket__NotRequiredToken();
    error NFTMarket__NotEnoughAmountTokenToBuy();
    error NFTMarket__AlreadyListed();
    error NFTMarket__BuyerIsSeller();
    error NFTMarket__InvalidSignature();
    error NFTMarket__BuyERC20TransferFailed();
    error NFTMarket__PermitBuySignaturExpired();
    error NFTMarket__SignatureExpired();
    error NFTMarket__InvalidListingSignature();
    error NFTMarket__SignatureAlreadyUsed();

    struct Listing {
        address seller;
        address nftAddress;
        address erc20Token;
        uint256 price;
    }

    // State variables from V1
    mapping(address => mapping(uint256 => Listing)) public listings;
    mapping(address => uint256) public nonces;

    // New state variables for V2
    mapping(bytes32 => bool) public usedSignatures; // Track used listing signatures
    mapping(address => mapping(address => uint256)) public sellerNonces; // seller => nftAddress => nonce

    // Events from V1
    event ListingCreated(
        address indexed nftAddress, uint256 indexed tokenId, address indexed erc20Token, uint256 price
    );
    event ListingRemoved(address indexed nftAddress, uint256 indexed tokenId);
    event NFTPurchased(
        address indexed nftAddress, uint256 indexed tokenId, address buyer, address seller, uint256 price
    );

    // New events for V2
    event ListingCreatedWithSignature(
        address indexed nftAddress,
        uint256 indexed tokenId,
        address indexed seller,
        address erc20Token,
        uint256 price,
        bytes32 signatureHash
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initialize the contract (replaces constructor for upgradeable contracts)
     * @param initialOwner The initial owner of the contract
     */
    function initialize(address initialOwner) public initializer {
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        __Ownable_init(initialOwner);
    }

    /**
     * @dev List an NFT for sale (original method)
     * @param nftAddress The address of the NFT contract
     * @param tokenId The token ID to list
     * @param erc20Token The ERC20 token to accept as payment
     * @param price The price in ERC20 tokens
     */
    function listItem(address nftAddress, uint256 tokenId, address erc20Token, uint256 price) external {
        IERC721 nft = IERC721(nftAddress);

        if (nft.ownerOf(tokenId) != msg.sender) revert NFTMarket__NotOwner();
        if (!nft.isApprovedForAll(msg.sender, address(this)) && nft.getApproved(tokenId) != address(this)) {
            revert NFTMarket__NotApprovedForTransfer();
        }
        if (listings[nftAddress][tokenId].seller != address(0)) {
            revert NFTMarket__AlreadyListed();
        }

        listings[nftAddress][tokenId] = Listing(msg.sender, nftAddress, erc20Token, price);

        emit ListingCreated(nftAddress, tokenId, erc20Token, price);
    }

    /**
     * @dev List an NFT for sale using offline signature
     * @param nftAddress The address of the NFT contract
     * @param tokenId The token ID to list
     * @param erc20Token The ERC20 token to accept as payment
     * @param price The price in ERC20 tokens
     * @param deadline The signature expiration timestamp
     * @param signature The seller's signature
     */
    function listItemWithSignature(
        address nftAddress,
        uint256 tokenId,
        address erc20Token,
        uint256 price,
        uint256 deadline,
        bytes calldata signature
    ) external {
        if (block.timestamp > deadline) revert NFTMarket__SignatureExpired();
        if (listings[nftAddress][tokenId].seller != address(0)) {
            revert NFTMarket__AlreadyListed();
        }

        IERC721 nft = IERC721(nftAddress);
        address tokenOwner = nft.ownerOf(tokenId);

        // Verify the NFT contract has approved this market contract
        if (!nft.isApprovedForAll(tokenOwner, address(this))) {
            revert NFTMarket__NotApprovedForTransfer();
        }

        // Get current nonce
        uint256 currentNonce = sellerNonces[tokenOwner][nftAddress];

        // Create signature hash for listing
        bytes32 messageHash =
            _getListingMessageHash(tokenOwner, nftAddress, tokenId, erc20Token, price, deadline, currentNonce);

        bytes32 ethSignedHash = _toEthSignedMessageHash(messageHash);

        // Check if signature has been used
        if (usedSignatures[ethSignedHash]) revert NFTMarket__SignatureAlreadyUsed();

        // Verify signature
        address recovered = ethSignedHash.recover(signature);
        if (recovered != tokenOwner) revert NFTMarket__InvalidListingSignature();

        // Mark signature as used and increment nonce
        usedSignatures[ethSignedHash] = true;
        sellerNonces[tokenOwner][nftAddress] = currentNonce + 1;

        // Create listing
        listings[nftAddress][tokenId] = Listing(tokenOwner, nftAddress, erc20Token, price);

        emit ListingCreatedWithSignature(nftAddress, tokenId, tokenOwner, erc20Token, price, ethSignedHash);
    }

    /**
     * @dev Get the message hash for listing signature
     * @param seller The seller's address
     * @param nftAddress The NFT contract address
     * @param tokenId The token ID
     * @param erc20Token The payment token address
     * @param price The listing price
     * @param deadline The signature deadline
     * @param nonce The seller's nonce for this NFT contract
     * @return The message hash
     */
    function _getListingMessageHash(
        address seller,
        address nftAddress,
        uint256 tokenId,
        address erc20Token,
        uint256 price,
        uint256 deadline,
        uint256 nonce
    ) internal pure returns (bytes32) {
        // Split into two parts to avoid stack too deep
        bytes32 part1 = keccak256(abi.encodePacked("LIST_NFT", seller, nftAddress, tokenId));
        bytes32 part2 = keccak256(abi.encodePacked(erc20Token, price, deadline, nonce));
        return keccak256(abi.encodePacked(part1, part2));
    }

    /**
     * @dev Get the current nonce for a seller and NFT contract
     * @param seller The seller's address
     * @param nftAddress The NFT contract address
     * @return The current nonce
     */
    function getSellerNonce(address seller, address nftAddress) external view returns (uint256) {
        return sellerNonces[seller][nftAddress];
    }

    /**
     * @dev Check if a signature has been used
     * @param signatureHash The signature hash to check
     * @return Whether the signature has been used
     */
    function isSignatureUsed(bytes32 signatureHash) external view returns (bool) {
        return usedSignatures[signatureHash];
    }

    /**
     * @dev Generate the signature hash for frontend use
     * @param seller The seller's address
     * @param nftAddress The NFT contract address
     * @param tokenId The token ID
     * @param erc20Token The payment token address
     * @param price The listing price
     * @param deadline The signature deadline
     * @return The signature hash that should be signed
     */
    function getListingSignatureHash(
        address seller,
        address nftAddress,
        uint256 tokenId,
        address erc20Token,
        uint256 price,
        uint256 deadline
    ) external view returns (bytes32) {
        uint256 currentNonce = sellerNonces[seller][nftAddress];
        bytes32 messageHash =
            _getListingMessageHash(seller, nftAddress, tokenId, erc20Token, price, deadline, currentNonce);
        return _toEthSignedMessageHash(messageHash);
    }

    /**
     * @dev Remove an NFT listing
     * @param nftAddress The address of the NFT contract
     * @param tokenId The token ID to remove from listing
     */
    function removeItem(address nftAddress, uint256 tokenId) external {
        Listing memory listing = listings[nftAddress][tokenId];
        if (listing.seller != msg.sender) revert NFTMarket__NotOwner();

        delete listings[nftAddress][tokenId];
        emit ListingRemoved(nftAddress, tokenId);
    }

    /**
     * @dev Buy an NFT
     * @param nftAddress The address of the NFT contract
     * @param tokenId The token ID to buy
     */
    function buyItem(address nftAddress, uint256 tokenId) external nonReentrant {
        _buy(nftAddress, tokenId, msg.sender);
    }

    /**
     * @dev Internal function to handle NFT purchase
     * @param nftAddress The address of the NFT contract
     * @param tokenId The token ID to buy
     * @param buyer The buyer's address
     */
    function _buy(address nftAddress, uint256 tokenId, address buyer) internal {
        Listing memory listing = listings[nftAddress][tokenId];
        if (listing.seller == address(0)) revert NFTMarket__NotListing();
        if (buyer == listing.seller) revert NFTMarket__BuyerIsSeller();

        IERC20 token = IERC20(listing.erc20Token);
        if (token.allowance(buyer, address(this)) < listing.price) {
            revert NFTMarket__NotEnoughAmountTokenToBuy();
        }

        delete listings[nftAddress][tokenId];

        if (!token.transferFrom(buyer, listing.seller, listing.price)) {
            revert NFTMarket__BuyERC20TransferFailed();
        }

        IERC721(listing.nftAddress).safeTransferFrom(listing.seller, buyer, tokenId);

        emit NFTPurchased(nftAddress, tokenId, buyer, listing.seller, listing.price);
    }

    /**
     * @dev Convert hash to Ethereum signed message hash
     * @param hash The hash to convert
     * @return The Ethereum signed message hash
     */
    function _toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    /**
     * @dev Buy NFT with permit signature (original method)
     * @param nftAddress The address of the NFT contract
     * @param tokenId The token ID to buy
     * @param price The expected price
     * @param deadline The signature deadline
     * @param signature The seller's signature
     */
    function permitBuy(address nftAddress, uint256 tokenId, uint256 price, uint256 deadline, bytes calldata signature)
        external
        nonReentrant
    {
        if (block.timestamp > deadline) revert NFTMarket__PermitBuySignaturExpired();

        Listing memory listing = listings[nftAddress][tokenId];
        address tokenSeller = listing.seller;

        if (listing.price != price) revert NFTMarket__NotRequiredToken();

        bytes32 messageHash =
            keccak256(abi.encodePacked(msg.sender, nftAddress, tokenId, price, nonces[msg.sender], deadline));
        bytes32 ethSignedHash = _toEthSignedMessageHash(messageHash);

        address recovered = ethSignedHash.recover(signature);

        if (recovered != tokenSeller) {
            revert NFTMarket__InvalidSignature();
        }

        nonces[msg.sender]++;

        _buy(nftAddress, tokenId, msg.sender);
    }

    /**
     * @dev Get the version of the contract
     * @return The version string
     */
    function version() external pure returns (string memory) {
        return "2.0.0";
    }

    /**
     * @dev Override required by UUPS to authorize upgrades
     * @param newImplementation The new implementation address
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @dev Get implementation address (for transparency)
     * @return The implementation address
     */
    function getImplementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    // Reserved storage slots for future upgrades (reduced from 48 to 46 due to new variables)
    uint256[46] private __gap;
}
