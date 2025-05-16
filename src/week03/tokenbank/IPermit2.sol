// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Interface for Uniswap's Permit2 smart contract.
interface IPermit2 {
    // ========== Structs ==========

    struct TokenPermissions {
        address token;
        uint256 amount;
    }

    struct PermitTransferFrom {
        TokenPermissions permitted;
        uint256 nonce;
        uint256 deadline;
    }

    struct SignatureTransferDetails {
        address to;
        uint256 requestedAmount;
    }

    struct PermitBatchTransferFrom {
        TokenPermissions[] permitted;
        uint256 nonce;
        uint256 deadline;
    }

    struct SignatureBatchTransferDetails {
        address to;
        uint256[] requestedAmounts;
    }

    struct NonceInvalidation {
        uint256 word;
        uint256 mask;
    }

    // ========== Functions ==========

    /// @notice Permit-based single token transfer
    function permitTransferFrom(
        PermitTransferFrom calldata permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external;

    /// @notice Permit-based batch transfer for multiple tokens
    function permitBatchTransferFrom(
        PermitBatchTransferFrom calldata permit,
        SignatureBatchTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external;

    /// @notice Invalidate multiple nonces for a user (bitmask)
    function invalidateNonces(
        address token,
        address owner,
        uint256 wordPos,
        uint256 mask
    ) external;

    /// @notice Lock specific nonces from being reused
    function lockdown(address[] calldata tokens, address owner) external;

    // ========== Events ==========

    event NonceInvalidated(
        address indexed owner,
        address indexed token,
        uint256 word,
        uint256 mask
    );
    event Lockdown(address indexed owner, address[] tokens);
}
