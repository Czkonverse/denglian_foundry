// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Bank.sol";

// Chainlink Automation 接口
interface AutomationCompatibleInterface {
    function checkUpkeep(bytes calldata checkData) external returns (bool upkeepNeeded, bytes memory performData);
    function performUpkeep(bytes calldata performData) external;
}

/**
 * @title BankWithAutomation
 * @dev Bank 合约的升级版，集成 Chainlink Automation
 * 当存款超过设定阈值时，自动转移一半到指定地址
 */
contract BankWithAutomation is Bank, AutomationCompatibleInterface {
    // 状态变量
    uint256 public threshold; // 触发自动转账的阈值
    address public recipient; // 接收自动转账的地址
    uint256 public lastTransferTime; // 上次自动转账时间
    uint256 public minInterval = 60; // 最小间隔时间（秒）

    // 事件
    event AutomatedTransfer(uint256 amount, address recipient, uint256 timestamp);
    event ThresholdUpdated(uint256 newThreshold);
    event RecipientUpdated(address newRecipient);

    /**
     * @dev 构造函数
     * @param _threshold 初始阈值
     * @param _recipient 初始接收地址
     */
    constructor(uint256 _threshold, address _recipient) {
        require(_threshold > 0, "Threshold must be greater than 0");
        require(_recipient != address(0), "Recipient cannot be zero address");

        threshold = _threshold;
        recipient = _recipient;
        lastTransferTime = block.timestamp;
    }

    /**
     * @dev Chainlink Keeper 调用此函数检查是否需要执行自动化任务
     * @return upkeepNeeded 是否需要执行
     * @return performData 传递给 performUpkeep 的数据
     */
    function checkUpkeep(bytes calldata /* checkData */ )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        upkeepNeeded = shouldTransfer();
        performData = "";
    }

    /**
     * @dev 检查是否满足转账条件
     */
    function shouldTransfer() public view returns (bool) {
        return (
            address(this).balance > threshold && (block.timestamp - lastTransferTime) >= minInterval
                && recipient != address(0)
        );
    }

    /**
     * @dev Chainlink Keeper 在 checkUpkeep 返回 true 时调用此函数
     */
    function performUpkeep(bytes calldata /* performData */ ) external override {
        // 再次检查条件（防止重入攻击）
        require(shouldTransfer(), "Conditions not met");

        // 计算转账金额（合约余额的一半）
        uint256 transferAmount = address(this).balance / 2;

        // 更新最后转账时间
        lastTransferTime = block.timestamp;

        // 执行转账
        (bool success,) = recipient.call{value: transferAmount}("");
        require(success, "Transfer failed");

        // 触发事件
        emit AutomatedTransfer(transferAmount, recipient, block.timestamp);
    }

    /**
     * @dev 更新阈值（仅 owner）
     * @param _newThreshold 新的阈值
     */
    function updateThreshold(uint256 _newThreshold) external onlyOwner {
        require(_newThreshold > 0, "Threshold must be greater than 0");
        threshold = _newThreshold;
        emit ThresholdUpdated(_newThreshold);
    }

    /**
     * @dev 更新接收地址（仅 owner）
     * @param _newRecipient 新的接收地址
     */
    function updateRecipient(address _newRecipient) external onlyOwner {
        require(_newRecipient != address(0), "Recipient cannot be zero address");
        recipient = _newRecipient;
        emit RecipientUpdated(_newRecipient);
    }

    /**
     * @dev 更新最小间隔时间（仅 owner）
     * @param _newInterval 新的间隔时间（秒）
     */
    function updateMinInterval(uint256 _newInterval) external onlyOwner {
        minInterval = _newInterval;
    }

    /**
     * @dev 获取自动化状态信息
     */
    function getAutomationInfo()
        external
        view
        returns (
            uint256 currentBalance,
            uint256 currentThreshold,
            address currentRecipient,
            uint256 timeSinceLastTransfer,
            bool readyToTransfer
        )
    {
        return (address(this).balance, threshold, recipient, block.timestamp - lastTransferTime, shouldTransfer());
    }
}
