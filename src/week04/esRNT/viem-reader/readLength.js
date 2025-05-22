// Import the 'createPublicClient' and 'http' functions from the 'viem' library.
// These are used to set up a connection to an Ethereum node.
import { createPublicClient, http } from 'viem';

// Import the 'foundry' chain configuration from 'viem/chains'.
// 'foundry' is a local Ethereum test network, often used for development.
import { foundry } from 'viem/chains';

// Create a client object to interact with the Ethereum network.
// - 'chain: foundry' tells the client to use the local test network.
// - 'transport: http(...)' specifies the URL of the Ethereum node to connect to.
//   'host.docker.internal' allows a Docker container to access the host machine's network.
//   ':8545' is the default port for local Ethereum nodes like Anvil.
const client = createPublicClient({
  chain: foundry,
  transport: http('http://host.docker.internal:8545'), // Use this address when Anvil runs on the host machine
});

// Specify the address of the smart contract you want to interact with.
// This is a sample address where the contract is deployed on the local network.
const contractAddress = '0x5FbDB2315678afecb367f032d93F642f64180aa3';

// Define the main function that will perform the reading operation.
const main = async () => {
  // Use the client to read the value stored at slot 0 of the contract's storage.
  // In Solidity, slot 0 is often used for things like the length of an array.
  const lengthHex = await client.getStorageAt({
    address: contractAddress, // The contract to read from
    slot: '0x0',              // The storage slot to read (slot 0)
  });

  // Convert the hexadecimal value returned from the blockchain into a BigInt (a large integer).
  // Then print it to the console with a label.
  console.log('locks.length =', BigInt(lengthHex));
};

// Call the main function to start the script.
main();