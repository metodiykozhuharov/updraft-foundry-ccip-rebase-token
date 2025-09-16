-include .env

.PHONY: all test deploy local

install :
		forge install foundry-rs/forge-std && forge install Cyfrin/foundry-devops && forge install OpenZeppelin/openzeppelin-contracts && forge install smartcontractkit/chainlink-brownie-contracts && forge install smartcontractkit/ccip@@v2.17.0-ccip1.5.16 && forge install smartcontractkit/chainlink-local

#### LOCAL ####

local-test : 
		forge test

#### SEPOLIA ####

sepolia-test : 
		forge test --fork-url $(ETH_SEPOLIA_RPC_URL)