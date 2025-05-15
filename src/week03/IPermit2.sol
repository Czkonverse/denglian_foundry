// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IPermit2 - Standardized token permissions interface
/// @notice Interface for EIP-2612 style permit and batch transfer operations
interface IPermit2 {
    /// @notice Struct for a single permit
    struct PermitDetails {
        address token; // Token to be permitted
        uint160 amount; // Amount to permit
        uint48 expiration; // Permit expiration timestamp
        uint48 nonce; // Nonce for the permit
    }

    /// @notice Struct for a permit transfer
    struct PermitTransferFrom {
        PermitDetails permitted; // Details of the permitted transfer
        address spender; // Authorized spender
        uint256 deadline; // Signature deadline
    }

    /// @notice Struct for a permit batch transfer
    struct PermitBatchTransferFrom {
        PermitDetails[] permitted; // Array of permitted transfers
        address spender; // Authorized spender
        uint256 deadline; // Signature deadline
    }

    /// @notice Struct for signature transfer details
    struct SignatureTransferDetails {
        address to; // Recipient of the transfer
        uint256 requestedAmount; // Amount to transfer
    }

    /// @notice Emitted when a nonce is invalidated
    event NonceInvalidation(
        address indexed owner,
        address indexed token,
        uint48 nonce
    );

    /// @notice Allows a spender to transfer tokens from the owner
    /// @param permit Permit details including token, amount, expiration, and nonce
    /// @param owner Owner of the tokens
    /// @param signature EIP-712 signature
    function permit(
        PermitTransferFrom memory permit,
        address owner,
        bytes calldata signature
    ) external;

    /// @notice Allows a spender to transfer multiple tokens from the owner
    /// @param permit Batch permit details
    /// @param owner Owner of the tokens
    /// @param signature EIP-712 signature
    function permitBatch(
        PermitBatchTransferFrom memory permit,
        address owner,
        bytes calldata signature
    ) external;

    /// @notice Transfers tokens using a signed permit
    /// @param permit Permit details
    /// @param owner Owner of the tokens
    /// @param transferDetails Transfer details including recipient and amount
    /// @param signature EIP-712 signature
    function transferFrom(
        PermitTransferFrom memory permit,
        address owner,
        SignatureTransferDetails calldata transferDetails,
        bytes calldata signature
    ) external;

    /// @notice Transfers multiple tokens using a signed batch permit
    /// @param permit Batch permit details
    /// @param owner Owner of the tokens
    /// @param transferDetails Array of transfer details
    /// @param signature EIP-712 signature
    function batchTransferFrom(
        PermitBatchTransferFrom memory permit,
        address owner,
        SignatureTransferDetails[] calldata transferDetails,
        bytes calldata signature
    ) external;

    /// @notice Invalidates a nonce for a specific token
    /// @param token Token address
    /// @param nonce Nonce to invalidate
    function invalidateNonce(address token, uint48 nonce) external;

    /// @notice Returns the current nonce for an owner and token
    /// @param owner Owner address
    /// @param token Token address
    /// @return nonce Current nonce
    function nonceBitmap(
        address owner,
        address token
    ) external view returns (uint48 nonce);

    function permitTransferFrom(
        PermitTransferFrom calldata permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external;
}
