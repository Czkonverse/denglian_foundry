import { createPublicClient, http } from 'viem';
import { foundry } from 'viem/chains';

const client = createPublicClient({
  chain: foundry,
  transport: http('http://host.docker.internal:8545'), // 宿主机运行 anvil 时使用 host.docker.internal
});

const contractAddress = '0x5FbDB2315678afecb367f032d93F642f64180aa3';

const main = async () => {
  const lengthHex = await client.getStorageAt({
    address: contractAddress,
    slot: '0x0',
  });

  console.log('locks.length =', BigInt(lengthHex));
};

main();
