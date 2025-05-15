import express from 'express';
import cors from 'cors';
import { createPublicClient, http, parseAbiItem, formatEther } from 'viem';
import { mainnet } from 'viem/chains';
import { PrismaClient } from '@prisma/client';
import dotenv from 'dotenv';

dotenv.config();

const app = express();
const prisma = new PrismaClient();

// 配置中间件
app.use(cors());
app.use(express.json());

// 创建 Viem 客户端
const client = createPublicClient({
  chain: mainnet,
  transport: http(process.env.RPC_URL)
});

// ERC20 Transfer 事件的 ABI
const transferEventAbi = parseAbiItem('event Transfer(address indexed from, address indexed to, uint256 value)');

// 索引转账事件的函数
async function indexTransfers(tokenAddress: string, fromBlock: bigint) {
  try {
    const logs = await client.getLogs({
      address: tokenAddress as `0x${string}`,
      event: transferEventAbi,
      fromBlock,
      toBlock: 'latest'
    });

    for (const log of logs) {
      const block = await client.getBlock({ blockNumber: log.blockNumber });
      
      await prisma.transfer.create({
        data: {
          from: log.args.from as string,
          to: log.args.to as string,
          amount: formatEther(log.args.value as bigint),
          tokenAddress,
          txHash: log.transactionHash,
          blockNumber: Number(log.blockNumber),
          timestamp: new Date(Number(block.timestamp) * 1000)
        }
      });
    }
  } catch (error) {
    console.error('Error indexing transfers:', error);
  }
}

// API 路由
app.get('/api/transfers/:address', async (req, res) => {
  try {
    const { address } = req.params;
    const transfers = await prisma.transfer.findMany({
      where: {
        OR: [
          { from: address.toLowerCase() },
          { to: address.toLowerCase() }
        ]
      },
      orderBy: {
        timestamp: 'desc'
      }
    });
    res.json(transfers);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch transfers' });
  }
});

// 生成模拟转账数据
function generateMockTransfers(address: string) {
  interface MockTransfer {
    id: number;
    from: string;
    to: string;
    amount: string;
    tokenAddress: string;
    txHash: string;
    blockNumber: number;
    timestamp: Date;
    createdAt: Date;
  }

  const mockTransfers: MockTransfer[] = [];
  const now = Date.now();
  const targetAddress = '0xd535F107588040c3a9dcCc37743846EDCCbC7386';
  const tokenAddress = '0x1234567890123456789012345678901234567890'; // 你的代币地址

  // 只有当查询的是目标地址时才返回数据
  if (address.toLowerCase() === targetAddress.toLowerCase()) {
    // 模拟该地址的转账记录
    const transactions = [
      {
        from: targetAddress,
        to: '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D', // Uniswap V2 Router
        amount: '150.5',
        timestamp: now - 5 * 24 * 60 * 60 * 1000, // 5天前
        blockNumber: 19500000
      },
      {
        from: '0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45', // Uniswap V3 Router
        to: targetAddress,
        amount: '75.25',
        timestamp: now - 3 * 24 * 60 * 60 * 1000, // 3天前
        blockNumber: 19500500
      },
      {
        from: targetAddress,
        to: '0x1111111254EEB25477B68fb85Ed929f73A960582', // 1inch Router
        amount: '45.75',
        timestamp: now - 2 * 24 * 60 * 60 * 1000, // 2天前
        blockNumber: 19501000
      },
      {
        from: '0xDef1C0ded9bec7F1a1670819833240f027b25EfF', // 0x Protocol
        to: targetAddress,
        amount: '100',
        timestamp: now - 1 * 24 * 60 * 60 * 1000, // 1天前
        blockNumber: 19501500
      },
      {
        from: targetAddress,
        to: '0x881D40237659C251811CEC9c364ef91dC08D300C', // 某个用户地址
        amount: '25.5',
        timestamp: now - 12 * 60 * 60 * 1000, // 12小时前
        blockNumber: 19502000
      }
    ];

    // 生成模拟数据
    transactions.forEach((tx, index) => {
      mockTransfers.push({
        id: index + 1,
        from: tx.from,
        to: tx.to,
        amount: tx.amount,
        tokenAddress,
        txHash: `0x${Array.from(crypto.getRandomValues(new Uint8Array(32))).map(b => b.toString(16).padStart(2, '0')).join('')}`,
        blockNumber: tx.blockNumber,
        timestamp: new Date(tx.timestamp),
        createdAt: new Date()
      });
    });
  }

  return mockTransfers;
}

// 模拟数据路由
app.get('/api/mock-transfers/:address', async (req, res) => {
  const { address } = req.params;
  const mockTransfers = generateMockTransfers(address);
  res.json(mockTransfers);
});

// 启动服务器
const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  
  // 开始索引指定代币的转账
  const tokenAddress = process.env.TOKEN_ADDRESS;
  const startBlock = BigInt(process.env.START_BLOCK || '0');
  
  if (tokenAddress) {
    indexTransfers(tokenAddress, startBlock);
    // 每5分钟更新一次
    setInterval(() => {
      indexTransfers(tokenAddress, startBlock);
    }, 5 * 60 * 1000);
  }
}); 