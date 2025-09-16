// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {IRouter} from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouter.sol";
import {IRouterClient} from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";

contract BridgeTokensScript is Script {
    function send(
        address receiverAddress,
        uint64 destinationChainSelector,
        address tokenToSendAddress,
        uint256 amountToSend,
        address linkTokenAddress,
        address routerAddress
    ) public {
        vm.startBroadcast();
        Client.EVM2AnyMessage memory message = getMessage(
            receiverAddress,
            tokenToSendAddress,
            amountToSend,
            linkTokenAddress
        );
        IRouterClient(routerAddress).ccipSend(
            destinationChainSelector,
            message
        );
        vm.stopBroadcast();
    }

    function approveSend(
        address receiverAddress,
        uint64 destinationChainSelector,
        address tokenToSendAddress,
        uint256 amountToSend,
        address linkTokenAddress,
        address routerAddress
    ) public {
        vm.startBroadcast();
        Client.EVM2AnyMessage memory message = getMessage(
            receiverAddress,
            tokenToSendAddress,
            amountToSend,
            linkTokenAddress
        );
        uint256 ccipFee = IRouterClient(routerAddress).getFee(
            destinationChainSelector,
            message
        );
        IERC20(linkTokenAddress).approve(routerAddress, ccipFee);

        // Approve more than we send, as we will also mint, might require fees, etc..
        IERC20(tokenToSendAddress).approve(routerAddress, type(uint256).max);
        vm.stopBroadcast();
    }

    function getMessage(
        address receiverAddress,
        address tokenToSendAddress,
        uint256 amountToSend,
        address linkTokenAddress
    ) internal pure returns (Client.EVM2AnyMessage memory message) {
        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: tokenToSendAddress,
            amount: amountToSend
        });
        message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiverAddress),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: linkTokenAddress,
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 0}))
        });
    }
}
