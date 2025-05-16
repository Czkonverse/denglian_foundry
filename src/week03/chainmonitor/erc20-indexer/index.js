// 加载 .env 文件中的环境变量到 process.env，方便后续通过 process.env.变量名 获取配置
require('dotenv').config();
// 从 viem 库中导入创建客户端、HTTP 连接和 ABI 解析的函数
const { createPublicClient, http, parseAbiItem } = require('viem');
// 导入 viem 里内置的 foundry 链配置
const { foundry } = require('viem/chains');
// 导入自定义的 saveTransfer 函数，用于保存转账记录
const { saveTransfer } = require('./db');
// 导入 Node.js 的文件系统模块
const fs = require('fs');

// 读取本地 abi/ERC20.json 文件，解析为 JavaScript 对象（ABI 用于描述合约接口）
const abi = JSON.parse(fs.readFileSync('./abi/ERC20.json', 'utf-8'));

// 创建一个连接到 foundry 区块链的客户端，使用 .env 文件中的 RPC_URL 作为节点地址
const client = createPublicClient({
    chain: foundry,
    transport: http(process.env.ANALYTICS_RPC_URL),
});

// 从环境变量中获取代币合约地址，并转为小写（方便后续比较）
const tokenAddress = process.env.TOKEN_ADDRESS.toLowerCase();

// 监听区块链上的 ERC20 代币 Transfer 事件，并保存转账记录。
client.watchEvent({
    address: tokenAddress, // 要监听的代币合约地址
    event: parseAbiItem('event Transfer(address indexed from, address indexed to, uint256 value)'), // 监听 Transfer 事件
    onLogs: (logs) => { // 当有 Transfer 事件发生时会触发这个回调
        logs.forEach(log => {
            const { transactionHash, blockNumber, args } = log; // 获取交易哈希、区块号和事件参数
            const { from, to, value } = args; // 事件参数里有转出地址、转入地址和转账金额
            console.log(`📥 Transfer from ${from} to ${to} of ${value}`); // 打印转账信息
            saveTransfer({
                txHash: transactionHash, // 交易哈希
                blockNumber,             // 区块号
                from,                    // 转出地址
                to,                      // 转入地址
                amount: value,           // 转账金额
                token: tokenAddress      // 代币合约地址
            });
        });
    }
});