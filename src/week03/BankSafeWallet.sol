// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BankSafeWallet {
    address public admin;

    constructor(address _admin) {
        admin = _admin;
    }

    /// @notice 任何人都可以将任意 ERC20 Token 存入合约
    function deposit(address token, uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        require(
            IERC20(token).transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );
    }

    /// @notice 仅管理员（Safe）可提取 ERC20 Token
    function withdraw(address token, address to, uint256 amount) external {
        require(msg.sender == admin, "Only admin can withdraw");
        require(IERC20(token).transfer(to, amount), "Transfer failed");
    }

    /// @notice 查询合约中某个 Token 的余额
    function balanceOf(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function getAdmin() external view returns (address) {
        return admin;
    }
}
