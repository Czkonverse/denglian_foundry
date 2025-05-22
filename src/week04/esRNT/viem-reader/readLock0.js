// 导入 viem 库中的函数：
// - createPublicClient: 用于创建与以太坊节点交互的客户端
// - http: 用于指定节点的网络地址
// - keccak256: 用于计算哈希（以太坊常用的哈希算法）
// - encodePacked: 用于将数据打包成字节流（以太坊存储槽计算需要）
// - parseAbi: 这里虽然导入了，但本文件未使用
import { createPublicClient, http, keccak256, encodePacked, parseAbi } from 'viem';

// 导入 foundry 链配置，代表本地开发链（如 anvil）
import { foundry } from 'viem/chains';

// 创建一个客户端对象，用于和本地以太坊节点通信
// - chain: foundry 表示使用本地测试链
// - transport: http(...) 指定节点的网络地址（这里是本机的 8545 端口）
const client = createPublicClient({
  chain: foundry,
  transport: http('http://host.docker.internal:8545'), // 宿主机运行 anvil
});

// 指定要读取的智能合约地址（本地部署的合约）
const contractAddress = '0x5FbDB2315678afecb367f032d93F642f64180aa3';

// 定义主函数，负责读取并解析 locks[0] 结构体
const main = async () => {
  // 1. 计算 locks[0] 的 baseSlot
  //    Solidity 中，结构体数组 locks 的第 0 个元素的存储槽位置为 keccak256(encodePacked(0))
  //    encodePacked(['uint256'], [0n]) 把数字 0 编码成字节流
  //    keccak256 计算哈希，得到 baseSlot
  const baseSlot = BigInt(keccak256(encodePacked(['uint256'], [0n])));

  // 2. 依次读取结构体的 3 个字段（每个字段占用一个 slot）
  //    userRaw: locks[0] 的第一个字段（user 地址），存储在 baseSlot
  //    startTimeRaw: locks[0] 的第二个字段（startTime），存储在 baseSlot + 1
  //    amountRaw: locks[0] 的第三个字段（amount），存储在 baseSlot + 2
  const userRaw = await client.getStorageAt({ address: contractAddress, slot: baseSlot });
  const startTimeRaw = await client.getStorageAt({ address: contractAddress, slot: baseSlot + 1n });
  const amountRaw = await client.getStorageAt({ address: contractAddress, slot: baseSlot + 2n });

  // 3. 解析每个字段的值
  //    user 字段是以太坊地址，占 20 字节，存储在 32 字节槽的低 20 字节
  //    slice(26) 是取最后 20 字节（40 个十六进制字符），并加上 '0x' 前缀
  const user = '0x' + userRaw.slice(26);
  //    startTime 和 amount 是整数，直接转成 BigInt 类型
  const startTime = BigInt(startTimeRaw);
  const amount = BigInt(amountRaw);

  // 4. 打印结果到控制台
  //    显示 locks[0] 结构体的所有字段内容
  console.log(`locks[0]: user: ${user}, startTime: ${startTime}, amount: ${amount}`);
};

// 调用主函数，开始执行脚本
main();