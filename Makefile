deployAndVerify:
	@source .env && \
	forge script script/DeployMyToken.s.sol:DeployMyToken \
		--rpc-url $$SEPOLIA_RPC_URL \
		--private-key $$PRIVATE_KEY \
		--broadcast \
		--verify

deploy:
	@source .env && \
	forge script script/DeployMyToken.s.sol:DeployMyToken \
		--rpc-url $$SEPOLIA_RPC_URL \
		--private-key $$PRIVATE_KEY \
		--broadcast

verify:
	@source .env && \
	forge verify-contract \
		--chain-id $$SEPOLIA_CHAIN_ID \
		--compiler-version v0.8.25+commit.4fc1097e \
		--num-of-optimizations 200 \
		0xecE0E48Ab0d07559eFdE7315340c81C21bf9F108 \
		src/MyToken.sol:MyToken \
		--etherscan-api-key $$ETHERSCAN_API_KEY

