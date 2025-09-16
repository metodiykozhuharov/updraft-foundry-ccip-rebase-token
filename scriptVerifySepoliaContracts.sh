#!/bin/bash
set -euo pipefail
source .env

ETHERSCAN_API_KEY=${ETHERSCAN_API_KEY}
CHAIN=sepolia

REBASE_TOKEN=${SEPOLIA_REBASE_TOKEN_ADDRESS}
REBASE_POOL=${SEPOLIA_POOL_ADDRESS}
VAULT=${VAULT_ADDRESS}

# ------------------------------------------------------
# Verify RebaseToken
# ------------------------------------------------------
forge verify-contract \
  --chain $CHAIN \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  $REBASE_TOKEN \
  src/RebaseToken.sol:RebaseToken \
  --constructor-args $(cast abi-encode "constructor()")

# ------------------------------------------------------
# Verify RebaseTokenPool
# constructor(IERC20 token, address[] memory allowlist, address rmnProxy, address router)
# ------------------------------------------------------
TOKEN=$REBASE_TOKEN
ALLOWLIST="[]"                
RMN_PROXY=0xba3f6251de62dED61Ff98590cB2fDf6871FbB991 # Sepolia RMNProxy 
ROUTER=0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59   # Sepolia Router

forge verify-contract \
  --chain $CHAIN \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  $REBASE_POOL \
  src/RebaseTokenPool.sol:RebaseTokenPool \
  --constructor-args $(cast abi-encode "constructor(address,address[],address,address)" $TOKEN "$ALLOWLIST" $RMN_PROXY $ROUTER)

# ------------------------------------------------------
# Verify Vault
# constructor(IRebaseToken _rebaseToken)
# ------------------------------------------------------
forge verify-contract \
  --chain $CHAIN \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  $VAULT \
  src/Vault.sol:Vault \
  --constructor-args $(cast abi-encode "constructor(address)" $REBASE_TOKEN)
