// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {RegistryModuleOwnerCustom} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {RateLimiter} from "@ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";
import {IRouterClient} from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";

import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";

contract CrossChainTest is Test {
    Vault ethSepoliaVault;
    RebaseToken ethSepoliaToken;
    RebaseToken arbSepoliaToken;
    RebaseTokenPool ethSepoliaPool;
    RebaseTokenPool arbSepoliaPool;

    uint256 ethSepoliaFork;
    uint256 arbSepoliaFork;
    CCIPLocalSimulatorFork ccipLocalSimulatorFork;
    Register.NetworkDetails ethSepoliaNetworkDetails;
    Register.NetworkDetails arbSepoliaNetworkDetails;

    address OWNER = makeAddr("owner");
    address USER = makeAddr("user");
    uint256 constant SEND_VALUE = 1e5;

    function setUp() public {
        ethSepoliaFork = vm.createSelectFork("eth-sepolia");
        arbSepoliaFork = vm.createFork("arb-sepolia");

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        // ---- Source ---- Deploy and configure on ETH Sepolia
        ethSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(
            block.chainid
        );
        vm.startPrank(OWNER);
        // Deploying Token
        ethSepoliaToken = new RebaseToken();
        // Deploying the Vault
        ethSepoliaVault = new Vault(IRebaseToken(address(ethSepoliaToken)));
        // Deploying Token Pool. Essential for minting and burning tokens during cross-chain transfers. Each token will be linked to a pool, which will manage token transfers and ensure proper handling of assets across chains.
        ethSepoliaPool = new RebaseTokenPool(
            IERC20(address(ethSepoliaToken)),
            new address[](0),
            ethSepoliaNetworkDetails.rmnProxyAddress,
            ethSepoliaNetworkDetails.routerAddress
        );

        // STEP: Claiming Mint and Burn Roles. Allowing token pool and vault to control how tokens are minted and burned during cross-chain transfers.

        // Vault handles the following transactions on current chain (source):
        // deposit of ETH -> mint of RBT
        // redeem of ETH -> burn of RBT
        ethSepoliaToken.grantMintAndBurnRole(address(ethSepoliaVault));
        // Token pools are handling cross chain transfers:
        // Example: When there is a transfer from ethSepolia to arbSepolia
        // - ethSepolia token pool - execute burn
        // - arbSepolia token pool - execute mint
        ethSepoliaToken.grantMintAndBurnRole(address(ethSepoliaPool));

        // STEP: Claiming and Accepting the Admin Role (2 steps)
        // 1. Register the EOA as the token admin. This role is required to enable the token in CCIP.
        RegistryModuleOwnerCustom(
            ethSepoliaNetworkDetails.registryModuleOwnerCustomAddress
        ).registerAdminViaOwner(address(ethSepoliaToken));
        // 2. Once claimed, you call the TokenAdminRegistry contract's acceptAdminRole function to complete the registration process.
        TokenAdminRegistry(ethSepoliaNetworkDetails.tokenAdminRegistryAddress)
            .acceptAdminRole(address(ethSepoliaToken));

        // STEP: Linking Tokens to Pools to associate the token with its respective token pool
        TokenAdminRegistry(ethSepoliaNetworkDetails.tokenAdminRegistryAddress)
            .setPool(address(ethSepoliaToken), address(ethSepoliaPool));
        vm.stopPrank();

        // ---- Destination ARB Sepolia ----
        vm.selectFork(arbSepoliaFork);
        vm.startPrank(OWNER);
        arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(
            block.chainid
        );
        arbSepoliaToken = new RebaseToken();
        arbSepoliaPool = new RebaseTokenPool(
            IERC20(address(arbSepoliaToken)),
            new address[](0),
            arbSepoliaNetworkDetails.rmnProxyAddress,
            arbSepoliaNetworkDetails.routerAddress
        );

        arbSepoliaToken.grantMintAndBurnRole(address(arbSepoliaPool));
        RegistryModuleOwnerCustom(
            arbSepoliaNetworkDetails.registryModuleOwnerCustomAddress
        ).registerAdminViaOwner(address(arbSepoliaToken));
        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress)
            .acceptAdminRole(address(arbSepoliaToken));
        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress)
            .setPool(address(arbSepoliaToken), address(arbSepoliaPool));
        vm.stopPrank();

        // STEP: Configuring Token Pools steps. Configure the pool by setting cross-chain transfer parameters, such as token pool rate limits and enabled destination chains.
        // Local ETH Sepolia / Remote ARB Sepolia
        configureTokenPool(
            ethSepoliaFork,
            address(ethSepoliaPool),
            address(arbSepoliaPool),
            address(arbSepoliaToken),
            arbSepoliaNetworkDetails
        );
        // Local ARB Sepolia / Remote ETH Sepolia
        configureTokenPool(
            arbSepoliaFork,
            address(arbSepoliaPool),
            address(ethSepoliaPool),
            address(ethSepoliaToken),
            ethSepoliaNetworkDetails
        );
    }

    /**
     * Example of local-remote: if I am currently on ETH Sepolia
     * - Local - ETH Sepolia
     * - Remote - ARB Sepolia
     */
    function configureTokenPool(
        uint256 fork,
        address localPool,
        address remotePool,
        address remoteToken,
        Register.NetworkDetails memory remoteNetworkDetails
    ) public {
        vm.selectFork(fork);
        vm.startPrank(OWNER);
        TokenPool.ChainUpdate[] memory chains = new TokenPool.ChainUpdate[](1);
        chains[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteNetworkDetails.chainSelector,
            allowed: true,
            remotePoolAddress: abi.encode(remotePool),
            remoteTokenAddress: abi.encode(remoteToken),
            outboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: false,
                capacity: 0,
                rate: 0
            }),
            inboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: false,
                capacity: 0,
                rate: 0
            })
        });
        TokenPool(localPool).applyChainUpdates(chains);
        vm.stopPrank();
    }

    function bridgeTokens(
        uint256 amountToBridge,
        uint256 localFork,
        uint256 remoteFork,
        Register.NetworkDetails memory localNetworkDetails,
        Register.NetworkDetails memory remoteNetworkDetails,
        RebaseToken localToken,
        RebaseToken remoteToken
    ) public {
        vm.selectFork(localFork);

        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: address(localToken),
            amount: amountToBridge
        });

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(USER),
            data: "",
            tokenAmounts: tokenAmounts,
            extraArgs: "",
            feeToken: localNetworkDetails.linkAddress
        });

        uint256 fee = IRouterClient(localNetworkDetails.routerAddress).getFee(
            remoteNetworkDetails.chainSelector,
            message
        );

        ccipLocalSimulatorFork.requestLinkFromFaucet(USER, fee);

        vm.prank(USER);
        IERC20(localNetworkDetails.linkAddress).approve(
            localNetworkDetails.routerAddress,
            fee
        );

        // Approve more than we send, as we will also mint, might require fees, etc..
        vm.prank(USER);
        IERC20(address(localToken)).approve(
            localNetworkDetails.routerAddress,
            type(uint256).max
        );

        uint256 localBalanceBefore = localToken.balanceOf(USER);

        vm.prank(USER);
        // We get the tokens from the user on the source chain
        IRouterClient(localNetworkDetails.routerAddress).ccipSend(
            remoteNetworkDetails.chainSelector,
            message
        );
        assertEq(
            localToken.balanceOf(USER),
            localBalanceBefore - amountToBridge
        );

        uint256 localUserInterestRate = localToken.getUserInterestRate(USER);

        vm.selectFork(remoteFork);
        // Simulate tima passed on the destination and get the balance of the user, before tokens are brigged.
        vm.warp(block.timestamp + 20 minutes);
        uint256 remoteBalanceBefore = remoteToken.balanceOf(USER);

        vm.selectFork(localFork);
        // To be called after the sending of the cross-chain message (`ccipSend`) above. Goes through the list of past logs and looks for the `CCIPSendRequested` event. Switches to a destination network fork. Routes the sent cross-chain message on the destination network.
        ccipLocalSimulatorFork.switchChainAndRouteMessage(remoteFork);

        assertEq(
            remoteToken.balanceOf(USER),
            remoteBalanceBefore + amountToBridge
        );
        assertEq(localUserInterestRate, remoteToken.getUserInterestRate(USER));
    }

    function testBridgeAllToken() public {
        // ethSepoliaFork -> local
        vm.selectFork(ethSepoliaFork);
        vm.deal(USER, SEND_VALUE);
        vm.prank(USER);
        Vault(payable(address(ethSepoliaVault))).deposit{value: SEND_VALUE}();
        assertEq(ethSepoliaToken.balanceOf(USER), SEND_VALUE);
        bridgeTokens(
            SEND_VALUE, // amount to bridge
            ethSepoliaFork, // local
            arbSepoliaFork, // remote
            ethSepoliaNetworkDetails, // local
            arbSepoliaNetworkDetails, // remote
            ethSepoliaToken, // local
            arbSepoliaToken // remote
        );

        // arbSepoliaFork - local (bridge back the tokens)
        vm.selectFork(arbSepoliaFork);
        vm.warp(block.timestamp + 20 minutes);
        bridgeTokens(
            SEND_VALUE, // amount to bridge
            arbSepoliaFork, // local
            ethSepoliaFork, // remote
            arbSepoliaNetworkDetails, // local
            ethSepoliaNetworkDetails, // remote
            arbSepoliaToken, // local
            ethSepoliaToken // remote
        );
    }
}
