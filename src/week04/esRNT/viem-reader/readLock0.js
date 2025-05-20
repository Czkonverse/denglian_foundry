import { createPublicClient, http, keccak256, encodePacked, parseAbi } from 'viem';
import { foundry } from 'viem/chains';

const client = createPublicClient({
  chain: foundry,
  transport: http('http://host.docker.internal:8545'), // 宿主机运行 anvil
});

const contractAddress = '0x5FbDB2315678afecb367f032d93F642f64180aa3';

const main = async () => {
  // 1. 获取 baseSlot = keccak256(encodePacked(0))
  const baseSlot = BigInt(keccak256(encodePacked(['uint256'], [0n])));

  // 2. 读取 3 个 slot
  const userRaw = await client.getStorageAt({ address: contractAddress, slot: baseSlot });
  const startTimeRaw = await client.getStorageAt({ address: contractAddress, slot: baseSlot + 1n });
  const amountRaw = await client.getStorageAt({ address: contractAddress, slot: baseSlot + 2n });

  // 3. 解析字段
  const user = '0x' + userRaw.slice(26); // address 占低 20 字节
  const startTime = BigInt(startTimeRaw);
  const amount = BigInt(amountRaw);

  // 4. 打印
  console.log(`locks[0]: user: ${user}, startTime: ${startTime}, amount: ${amount}`);
};

main();
