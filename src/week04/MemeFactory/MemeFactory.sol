// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./MemeToken.sol";
import "./IMemeToken.sol";

/// @title MemeFactory
/// @notice Factory contract for deploying and minting MemeToken contracts using the minimal proxy (clone) pattern.
/// @dev Handles deployment, minting, and fee distribution for MemeToken clones.
contract MemeFactory {
    using Clones for address;

    /// @notice Emitted when a new MemeToken is deployed
    /// @param token The address of the deployed MemeToken contract
    /// @param owner The address of the token creator/owner
    event MemeDeployed(address indexed token, address indexed owner);

    /// @notice Emitted when a user mints meme tokens
    /// @param token The address of the MemeToken contract
    /// @param user The address of the user who minted tokens
    /// @param amount The amount of tokens minted
    /// @param price The price paid for minting
    event MemeMinted(address indexed token, address indexed user, uint256 amount, uint256 price);

    /// @notice The address of the MemeToken implementation contract (used for cloning)
    address public immutable implementation;

    /// @notice The address that receives platform fees
    address payable public immutable platformFeeRecipient;

    /// @notice Platform fee percentage (1%)
    uint256 public constant PLATFORM_FEE_PERCENT = 1;

    /// @notice Mapping to check if an address is a MemeToken clone deployed by this factory
    mapping(address => bool) public isMemeToken;

    /// @notice Mapping from MemeToken address to its creator/owner
    mapping(address => address) public memeTokenToOwner;

    /// @param _implementation The address of the MemeToken implementation contract
    /// @param _platformFeeRecipient The address to receive platform fees
    constructor(address _implementation, address payable _platformFeeRecipient) {
        implementation = _implementation;
        platformFeeRecipient = _platformFeeRecipient;
    }

    /// @notice Deploys a new MemeToken contract clone with the specified parameters
    /// @dev Uses OpenZeppelin's Clones library for minimal proxy deployment.
    ///      The new token is initialized with the provided parameters.
    /// @param symbol The symbol of the new meme token
    /// @param totalSupply The maximum total supply of the token
    /// @param perMint The amount minted per mint operation
    /// @param price The cost (in wei) to mint perMint tokens
    /// @return clone The address of the newly deployed MemeToken contract
    function deployInscription(string memory symbol, uint256 totalSupply, uint256 perMint, uint256 price)
        external
        returns (address clone)
    {
        // Deploy a new clone of the MemeToken implementation
        clone = implementation.clone();

        // Construct the token name as "Meme: <symbol>"
        string memory name = string.concat("Meme: ", symbol);

        // Initialize the new MemeToken clone with the provided parameters
        MemeToken(clone).initialize(name, symbol, msg.sender, totalSupply, perMint, price);

        // Register the clone as a valid MemeToken and record its owner
        isMemeToken[clone] = true;
        memeTokenToOwner[clone] = msg.sender;

        // Emit event for deployment
        emit MemeDeployed(clone, msg.sender);
    }

    /// @notice Allows users to mint meme tokens by paying the required ETH
    /// @dev Verifies the token is a valid MemeToken, checks payment, mints tokens,
    ///      and splits the payment between the platform and the token issuer.
    /// @param tokenAddr The address of the MemeToken contract to mint from
    function mintInscription(address tokenAddr) external payable {
        // Ensure the token address is a valid MemeToken deployed by this factory
        require(isMemeToken[tokenAddr], "Not a MemeToken");

        IMemeToken token = IMemeToken(tokenAddr);
        uint256 required = token.price();
        // Check that the correct amount of ETH is sent
        require(msg.value == required, "Incorrect ETH");

        // Mint tokens to the sender
        token.mintTo(msg.sender);

        // Calculate platform fee and issuer share
        uint256 fee = (msg.value * PLATFORM_FEE_PERCENT) / 100;
        uint256 toIssuer = msg.value - fee;

        // Transfer platform fee to the platformFeeRecipient
        (bool s1,) = platformFeeRecipient.call{value: fee}("");
        require(s1, "platform fee transfer failed");

        // Transfer the remaining amount to the token issuer/owner
        (bool s2,) = payable(memeTokenToOwner[tokenAddr]).call{value: toIssuer}("");
        require(s2, "issuer transfer failed");

        // Emit event for minting
        emit MemeMinted(tokenAddr, msg.sender, token.perMint(), msg.value);
    }
}
