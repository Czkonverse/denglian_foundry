// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./MemeToken.sol";
import "./IMemeToken.sol";

contract MemeFactory {
    using Clones for address;

    event MemeDeployed(address indexed token, address indexed owner);
    event MemeMinted(address indexed token, address indexed user, uint256 amount, uint256 price);

    address public immutable implementation;
    address payable public immutable platformFeeRecipient;

    uint256 public constant PLATFORM_FEE_PERCENT = 1;

    mapping(address => bool) public isMemeToken;
    mapping(address => address) public memeTokenToOwner;

    constructor(address _implementation, address payable _platformFeeRecipient) {
        implementation = _implementation;
        platformFeeRecipient = _platformFeeRecipient;
    }

    /// @notice 创建一个新的 MemeToken 合约实例
    function deployInscription(string memory symbol, uint256 totalSupply, uint256 perMint, uint256 price)
        external
        returns (address clone)
    {
        clone = implementation.clone();

        string memory name = string.concat("Meme: ", symbol);

        MemeToken(clone).initialize(name, symbol, msg.sender, totalSupply, perMint, price);

        isMemeToken[clone] = true;
        memeTokenToOwner[clone] = msg.sender;

        emit MemeDeployed(clone, msg.sender);
    }

    /// @notice 购买 meme token，会按比例把费用转给平台和发行者
    function mintInscription(address tokenAddr) external payable {
        require(isMemeToken[tokenAddr], "Not a MemeToken");

        IMemeToken token = IMemeToken(tokenAddr);
        uint256 required = token.price();
        require(msg.value == required, "Incorrect ETH");

        // 铸币
        token.mintTo(msg.sender);

        // 分账
        uint256 fee = (msg.value * PLATFORM_FEE_PERCENT) / 100;
        uint256 toIssuer = msg.value - fee;

        (bool s1,) = platformFeeRecipient.call{value: fee}("");
        require(s1, "platform fee transfer failed");

        (bool s2,) = payable(memeTokenToOwner[tokenAddr]).call{value: toIssuer}("");
        require(s2, "issuer transfer failed");

        emit MemeMinted(tokenAddr, msg.sender, token.perMint(), msg.value);
    }
}
