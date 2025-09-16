// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Pool} from "@ccip/contracts/src/v0.8/ccip/libraries/Pool.sol";

//
import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract RebaseTokenPool is TokenPool {
    ////////////////////////////
    // Functions
    ////////////////////////////
    constructor(
        IERC20 token,
        address[] memory allowlist,
        address rmnProxy,
        address router
    ) TokenPool(token, allowlist, rmnProxy, router) {}

    ////////////////////////////
    // Public & External
    ////////////////////////////

    /**
     * @notice Handles the source-side of bridging: validates input and burns tokens from the pool
     * @dev This function is called by the **onRamp** (router) contract on the source chain.
     * @dev User tokens are transferred into the pool beforehand by the onRamp; the pool then calls burn(address(this), amount) to remove them from circulation on the source chain.
     * @dev The resulting message is sent through CCIP to the **offRamp** on the destination chain, where `releaseOrMint` will be called.
     * @param lockOrBurnIn burn data
     */
    function lockOrBurn(
        Pool.LockOrBurnInV1 calldata lockOrBurnIn
    ) external returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut) {
        _validateLockOrBurn(lockOrBurnIn);
        // Burn the tokens on the source chain.
        uint256 userInterestRate = IRebaseToken(address(i_token))
            .getUserInterestRate(lockOrBurnIn.originalSender);

        IRebaseToken(address(i_token)).burn(address(this), lockOrBurnIn.amount);

        lockOrBurnOut = Pool.LockOrBurnOutV1({
            destTokenAddress: getRemoteToken(lockOrBurnIn.remoteChainSelector),
            destPoolData: abi.encode(userInterestRate)
        });
    }

    /**
     * @notice Handles the destination-side of bridging: validates input and mints tokens for the user
     * @dev This function is called by the **offRamp** contract on the destination chain.
     * @dev The pool receives proof of the burn/lock based on the message received from the **onRamp** on the source chain, and then mints new tokens directly to the user’s address on the destination chain.
     * @param releaseOrMintIn -
     */
    function releaseOrMint(
        Pool.ReleaseOrMintInV1 calldata releaseOrMintIn
    ) external returns (Pool.ReleaseOrMintOutV1 memory) {
        _validateReleaseOrMint(releaseOrMintIn);
        address receiver = releaseOrMintIn.receiver;
        uint256 userInterestRate = abi.decode(
            releaseOrMintIn.sourcePoolData,
            (uint256)
        );
        // Mint tokens to the receiver on the destination chain
        IRebaseToken(address(i_token)).mint(
            receiver,
            releaseOrMintIn.amount,
            userInterestRate
        );

        return
            Pool.ReleaseOrMintOutV1({
                destinationAmount: releaseOrMintIn.amount
            });
    }
}
