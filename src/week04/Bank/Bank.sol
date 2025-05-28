// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Bank
 * @dev 一个简单的银行合约，允许用户存款和查询余额
 */
contract Bank {
    // 状态变量
    address public owner;
    uint256 public totalDeposits;

    // 用户余额映射
    mapping(address => uint256) public balances;

    // 事件
    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);
    event TransferToOwner(uint256 amount);

    // 修饰符
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    /**
     * @dev 构造函数，设置合约部署者为 owner
     */
    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev 存款函数
     */
    function deposit() public payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");

        balances[msg.sender] += msg.value;
        totalDeposits += msg.value;

        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @dev 查询用户余额
     * @param user 要查询的用户地址
     * @return 用户的存款余额
     */
    function getBalance(address user) public view returns (uint256) {
        return balances[user];
    }

    /**
     * @dev 查询合约总余额
     * @return 合约中的总存款
     */
    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev 用户提取自己的存款
     * @param amount 要提取的金额
     */
    function withdraw(uint256 amount) public {
        require(amount > 0, "Withdrawal amount must be greater than 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        balances[msg.sender] -= amount;
        totalDeposits -= amount;

        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        emit Withdrawal(msg.sender, amount);
    }

    /**
     * @dev 紧急提取函数，仅 owner 可调用
     * 用于紧急情况下提取合约中的所有资金
     */
    function emergencyWithdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success,) = owner.call{value: balance}("");
        require(success, "Transfer failed");
    }

    /**
     * @dev 更改 owner 地址
     * @param newOwner 新的 owner 地址
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        owner = newOwner;
    }
}
