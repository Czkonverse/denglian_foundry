include ../../../.env
export

deploy:
	forge script src/week03/viem/DeployTokenLocal.s.sol:DeployTokenLocal \
	--rpc-url $(RPC_URL_LOCAL_ANVIL) \
	--private-key $(PRIVATE_KEY_ANVIL_ONE) \
	--broadcast \
	-vvvv

transfer:
	cast send 0x5FbDB2315678afecb367f032d93F642f64180aa3 "transfer(address,uint256)" \
	0xd535f107588040c3a9dccc37743846edccbc7386 500 \
	--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
	--rpc-url http://127.0.0.1:8545
