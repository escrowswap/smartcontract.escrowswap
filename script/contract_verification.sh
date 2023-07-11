source .env

# GOERLI
forge verify-contract \
    --verifier-url https://api-goerli.etherscan.io/api/ \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --chain-id 1 \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address)" $W_GOERLI) \
    --compiler-version v0.8.18+commit.87f61d96 \
    0x77c045E0a320aA25dFc750787E253822f94eaAe5 \
    src/escrowswap_v1.0.sol:EscrowswapV1

# POLYGON
forge verify-contract \
    --verifier-url https://api.polygonscan.com/api/ \
    --etherscan-api-key $POLYGONSCAN_API_KEY \
    --chain-id 137 \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address)" $W_POLYGON) \
    --compiler-version v0.8.18+commit.87f61d96 \
    0x77c045E0a320aA25dFc750787E253822f94eaAe5 \
    src/escrowswap_v1.0.sol:EscrowswapV1

# POLYGON MUMBAI
forge verify-contract \
    --verifier-url https://api-testnet.polygonscan.com/api/ \
    --etherscan-api-key $POLYGONSCAN_API_KEY \
    --chain-id 80001 \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address)" $W_POLYGON_MUMBAI) \
    --compiler-version v0.8.18+commit.87f61d96 \
    0x77c045E0a320aA25dFc750787E253822f94eaAe5 \
    src/escrowswap_v1.0.sol:EscrowswapV1

# BSC
forge verify-contract \
    --verifier-url https://api.bscscan.com/api/ \
    --etherscan-api-key $BSCSCAN_API_KEY \
    --chain-id 56 \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address)" $W_BSC) \
    --compiler-version v0.8.18+commit.87f61d96 \
    0x77c045E0a320aA25dFc750787E253822f94eaAe5 \
    src/escrowswap_v1.0.sol:EscrowswapV1

# BSC TESTNET
forge verify-contract \
    --verifier-url https://api-testnet.bscscan.com/api/ \
    --etherscan-api-key $BSCSCAN_API_KEY \
    --chain-id 56 \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address)" $W_BSC_TESTNET) \
    --compiler-version v0.8.18+commit.87f61d96 \
    0x77c045E0a320aA25dFc750787E253822f94eaAe5 \
    src/escrowswap_v1.0.sol:EscrowswapV1

# OPTIMISM
forge verify-contract \
    --verifier-url https://api-optimistic.etherscan.io/api/ \
    --etherscan-api-key $OPTIMISMSCAN_API_KEY \
    --chain-id 10 \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address)" $W_OPTIMISM) \
    --compiler-version v0.8.18+commit.87f61d96 \
    0x77c045E0a320aA25dFc750787E253822f94eaAe5 \
    src/escrowswap_v1.0.sol:EscrowswapV1

# OPTIMISM TESTNET
forge verify-contract \
    --verifier-url https://api-goerli-optimistic.etherscan.io/api/ \
    --etherscan-api-key $OPTIMISMSCAN_API_KEY \
    --chain-id 420 \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address)" $W_OPTIMISM_TESTNET) \
    --compiler-version v0.8.18+commit.87f61d96 \
    0x77c045E0a320aA25dFc750787E253822f94eaAe5 \
    src/escrowswap_v1.0.sol:EscrowswapV1

# ARBITRUM
forge verify-contract \
    --verifier-url https://api.arbiscan.io/api/ \
    --etherscan-api-key $ARBISCAN_API_KEY \
    --chain-id 42161 \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address)" $W_ARBITRUM) \
    --compiler-version v0.8.18+commit.87f61d96 \
    0x77c045E0a320aA25dFc750787E253822f94eaAe5 \
    src/escrowswap_v1.0.sol:EscrowswapV1

# ARBITRUM TESTNET
forge verify-contract \
    --verifier-url https://api-goerli.arbiscan.io/api/ \
    --etherscan-api-key $ARBISCAN_API_KEY \
    --chain-id 421613 \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address)" $W_ARBITRUM_TESTNET) \
    --compiler-version v0.8.18+commit.87f61d96 \
    0x77c045E0a320aA25dFc750787E253822f94eaAe5 \
    src/escrowswap_v1.0.sol:EscrowswapV1