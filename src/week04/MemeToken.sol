// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract MemeToken is ERC20, Initializable {
    // --- 自定义名称和符号（因为构造函数未设置 ERC20） ---
    string private _name;
    string private _symbol;

    address public owner; // Meme 发行者
    address public factory; // 工厂合约

    uint256 public maxSupply; // 最大发行量（最小单位计）
    uint256 public perMint; // 每次 mint 的数量（最小单位计）
    uint256 public price; // 每次 mint 所需支付的费用（wei）
    uint256 public minted; // 当前已铸造数量

    error NotFactory();
    error ExceedsMaxSupply();
    error InvalidParams();

    event MemeMinted(address indexed to, uint256 amount);

    /// @dev 构造函数留空，因为使用的是 clone+initialize 初始化方式
    constructor() ERC20("", "") {}

    /// @dev 初始化函数，仅可调用一次（通过 Initializable 保证）
    function initialize(
        string memory name_,
        string memory symbol_,
        address _owner,
        uint256 _maxSupply,
        uint256 _perMint,
        uint256 _price
    ) external initializer {
        if (_owner == address(0) || _maxSupply == 0 || _perMint == 0 || _price == 0 || _perMint > _maxSupply) {
            revert InvalidParams();
        }

        // 初始化 ERC20 名称和符号（通过自定义 name()/symbol() 返回）
        _name = name_;
        _symbol = symbol_;

        owner = _owner;
        maxSupply = _maxSupply;
        perMint = _perMint;
        price = _price;
        factory = msg.sender;
    }

    /// @dev 工厂合约调用，向用户 mint perMint 数量的 meme
    function mintTo(address to) external {
        if (msg.sender != factory) {
            revert NotFactory();
        }

        if (minted + perMint > maxSupply) {
            revert ExceedsMaxSupply();
        }

        minted += perMint;
        _mint(to, perMint);

        emit MemeMinted(to, perMint);
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }
}
