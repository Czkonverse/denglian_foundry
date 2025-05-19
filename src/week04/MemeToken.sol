// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/// @title MemeToken
/// @notice ERC20 token contract for meme tokens, designed to be deployed via minimal proxy (clone) pattern.
/// @dev Uses OpenZeppelin's ERC20 and Initializable for upgradability and initialization control.
contract MemeToken is ERC20, Initializable {
    // --- Custom name and symbol storage (since ERC20 constructor is not used) ---
    string private _name; // Token name, set during initialization
    string private _symbol; // Token symbol, set during initialization

    address public owner; // The creator/owner of the meme token
    address public factory; // The factory contract that deploys and manages MemeToken clones

    uint256 public maxSupply; // Maximum total supply of the token (in smallest units)
    uint256 public perMint; // Amount minted per mint operation (in smallest units)
    uint256 public price; // Cost (in wei) required to mint perMint tokens
    uint256 public minted; // Current total minted amount

    // --- Custom errors for gas-efficient revert reasons ---
    error NotFactory(); // Thrown when a non-factory address calls restricted functions
    error ExceedsMaxSupply(); // Thrown when minting would exceed maxSupply
    error InvalidParams(); // Thrown when initialization parameters are invalid

    // --- Events ---
    /// @notice Emitted when tokens are minted to a user
    /// @param to The address receiving the minted tokens
    /// @param amount The amount of tokens minted
    event MemeMinted(address indexed to, uint256 amount);

    /// @dev Empty constructor since the contract is initialized via `initialize` (for clone pattern)
    constructor() ERC20("", "") {}

    /// @notice Initializes the MemeToken contract (can only be called once)
    /// @dev Sets token metadata and minting parameters. Only callable once due to Initializable.
    /// @param name_ The name of the token
    /// @param symbol_ The symbol of the token
    /// @param _owner The owner/creator of the token
    /// @param _maxSupply The maximum supply of the token
    /// @param _perMint The amount minted per mint operation
    /// @param _price The cost (in wei) to mint perMint tokens
    function initialize(
        string memory name_,
        string memory symbol_,
        address _owner,
        uint256 _maxSupply,
        uint256 _perMint,
        uint256 _price
    ) external initializer {
        // Validate parameters: owner must not be zero, supply/mint/price must be nonzero, perMint <= maxSupply
        if (_owner == address(0) || _maxSupply == 0 || _perMint == 0 || _price == 0 || _perMint > _maxSupply) {
            revert InvalidParams();
        }

        // Store custom name and symbol (since ERC20 constructor is not used)
        _name = name_;
        _symbol = symbol_;

        owner = _owner;
        maxSupply = _maxSupply;
        perMint = _perMint;
        price = _price;
        factory = msg.sender; // The caller (factory contract) is stored for access control
    }

    /// @notice Mints `perMint` tokens to a specified address
    /// @dev Only callable by the factory contract. Ensures maxSupply is not exceeded.
    /// @param to The address to receive the minted tokens
    function mintTo(address to) external {
        if (msg.sender != factory) {
            revert NotFactory();
        }

        // Ensure minting does not exceed the maximum supply
        if (minted + perMint > maxSupply) {
            revert ExceedsMaxSupply();
        }

        minted += perMint;
        _mint(to, perMint);

        emit MemeMinted(to, perMint);
    }

    /// @notice Returns the name of the token
    /// @return The token name
    function name() public view override returns (string memory) {
        return _name;
    }

    /// @notice Returns the symbol of the token
    /// @return The token symbol
    function symbol() public view override returns (string memory) {
        return _symbol;
    }
}
