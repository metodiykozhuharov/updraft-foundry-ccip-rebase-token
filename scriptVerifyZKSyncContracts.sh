#!/bin/bash
set -euo pipefail
source .env

# TODO - not successfully tested yet

ETHERSCAN_API_KEY=${ZKSYNC_ETHERSCAN_API_KEY}
CHAIN=300
COMPILER_VERSION="0.8.24+commit.e11b9ed9"

REBASE_TOKEN=${ZKSYNC_REBASE_TOKEN_ADDRESS}
REBASE_POOL=${ZKSYNC_POOL_ADDRESS}

TOKEN=$REBASE_TOKEN
ALLOWLIST="[]"                        
RMN_PROXY=0x3DA20FD3D8a8f8c1f1A5fD03648147143608C467
ROUTER=0xA1fdA8aa9A8C4b945C45aD30647b01f07D7A0B16

# ------------------------------------------------------
# Verify RebaseToken (no args constructor)
# ------------------------------------------------------
forge verify-contract \
  --chain $CHAIN \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --verifier zksync \
  --verifier-url "https://explorer.sepolia.era.zksync.dev/contract_verification" \
  $REBASE_TOKEN \
  src/RebaseToken.sol:RebaseToken \
  --constructor-args $(cast abi-encode "constructor()")

# ------------------------------------------------------
# Verify RebaseTokenPool
# constructor(address token, address[] allowlist, address rmnProxy, address router)
# ------------------------------------------------------
forge verify-contract \
  --chain $CHAIN \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --verifier zksync \
  --verifier-url "https://explorer.sepolia.era.zksync.dev/contract_verification" \
  $REBASE_POOL \
  src/RebaseTokenPool.sol:RebaseTokenPool \
  --constructor-args $(cast abi-encode "constructor(address,address[],address,address)" $TOKEN $ALLOWLIST $RMN_PROXY $ROUTER)