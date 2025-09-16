# 🏗️ Foundry Cross Chain Rebase Token

**[⭐️ Updraft Advance Foundry | Cross Chain Rebase Token](https://updraft.cyfrin.io/courses/advanced-foundry/cross-chain-rebase-token/introduction)**

## About  
**Cross-Chain Rebase Token** is an ERC20 token that grows user balances over time and can be bridged across chains. Users deposit into a vault on Ethereum Sepolia and receive rebasing tokens that accrue interest individually, based on the protocol’s global rate at the time of deposit. Using CCIP, tokens can be bridged to ZKSync Sepolia, following a burn-on-source and mint-on-destination approach. Tested with unit, integration, fork and fuzz testing, and comes with automated scripts for contracts deployment and verification along with interactions (deposit, and bridging).

⚠️ This is an **educational project**, and the code is adapted from course materials for learning purposes.

### ✅ Proof of Execution  

ЕTH Sepolia
- [Contract: Rebase Token](https://sepolia.etherscan.io/address/0xE71735b19A6eE778b5B31124c6C261D8Fb22183F)  
- [Contract: Rebase Token Pool](https://sepolia.etherscan.io/address/0x49545fe6ecab58328663cbdc851e22efb0e0366d) 
- [Contract: Vault](https://sepolia.etherscan.io/address/0xb7D54F1cDFea24FaeE4Ff4BDc4B798b83e9B506F)  

ZKSync Sepolia
- [Contract: Rebase Token](https://sepolia.explorer.zksync.io/address/0x4C2d938b3394117f2333Be29b8458f8804f1B93C)  
- [Contract: Rebase Token Pool](https://sepolia.explorer.zksync.io/address/0x3EBCD3F1223238dfaf7b3abC2DC34712d15e0A23) 

Transactions:
- [CCIP Message](https://ccip.chain.link/#/side-drawer/msg/0xf03cfe2e3b31d866fb66cc239038de6d030bba46eb9779259a5945df175a88a9)
  - ⚠️ TODO: Investigate why it stuck at status “Ready for manual execution”


## ⚙️ Setup  

```bash
git clone https://github.com/metodiykozhuharov/updraft-foundry-ccip-rebase-token.git
cd updraft-foundry-ccip-rebase-token 
make install
```

## 🔐 Environment Variables

Create a .env file in the project root with the following content:

```ini
# Local network (Anvil)
LOC_PRIVATE_KEY=<one of Anvil keys>
LOC_RPC_URL=http://127.0.0.1:8545

# Sepolia
ETH_SEPOLIA_RPC_URL=
ARB_SEPOLIA_RPC_URL=
ZKSYNC_SEPOLIA_RPC_URL=

ETHERSCAN_API_KEY=
ZKSYNC_ETHERSCAN_API_KEY=
```
⚠️ Important: Do not commit .env to git. Always use test accounts / fake ETH for local and Sepolia testing.

## 🏗️🧪 Build & Test

```bash
forge build

# Run tests locally
make local-test

# Run tests against Sepolia fork
make sepolia-test
```

## 🚀 Deploy and interact
```bash
# Import your wallet, so that you do not use private keys
cast wallet import my-sepolia-account --interactive
# Make the script executable
chmod +x ./scriptDeployAndBridgeToZksync
# This script will deploy contracts, deposit and bridge tokens
./scriptDeployAndBridgeToZksync
```

##  Extra Scripts
```bash
# Deposit and bridge tokens
./scriptBridgeToZksync.sh

# Verify contracts on ETH Sepolia
./scriptVerifySepoliaContracts.sh

# Verify contracts on ZKSync Sepolia (to be tested)
./scriptVerifyZKSyncContracts.sh
```


In order to use those, first add some extra information in .env file:
```ini
# Contracts created
ZKSYNC_REBASE_TOKEN_ADDRESS=
ZKSYNC_POOL_ADDRESS=

SEPOLIA_REBASE_TOKEN_ADDRESS=
SEPOLIA_POOL_ADDRESS=
VAULT_ADDRESS=
```