// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMemeToken {
    function mintTo(address to) external;
    function price() external view returns (uint256);
    function perMint() external view returns (uint256);
    function maxSupply() external view returns (uint256);
    function minted() external view returns (uint256);
}
