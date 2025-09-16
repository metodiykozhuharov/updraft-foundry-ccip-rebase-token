// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract Vault {
    ////////////////////////////
    // Error Codes
    ////////////////////////////
    error Vault__MustBeMoreThanZero();
    error Vault__RedeemFailed(address user, uint256 amount);

    ////////////////////////////
    // Type declarations
    ////////////////////////////
    ////////////////////////////
    // State variables
    ////////////////////////////
    IRebaseToken private immutable i_rebaseToken;

    ////////////////////////////
    // Events
    ////////////////////////////
    event Vault__Deposit(address indexed user, uint256 indexed amount);
    event Vault__Redeem(address indexed user, uint256 indexed amount);

    ////////////////////////////
    // Modifiers
    ////////////////////////////
    modifier mustBeMoreThanZero(uint256 _amount) {
        if (_amount <= 0) {
            revert Vault__MustBeMoreThanZero();
        }
        _;
    }

    ////////////////////////////
    // Functions
    ////////////////////////////
    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    ////////////////////////////
    // Receive & Fallbak
    ////////////////////////////
    /**
     * Receive function
     * Allows users to deposit ETH into the Vault and mint RBT return
     */
    function deposit() external payable {
        uint256 interestRate = i_rebaseToken.getInterestRate();
        i_rebaseToken.mint(msg.sender, msg.value, interestRate);
        emit Vault__Deposit(msg.sender, msg.value);
    }

    /**
     * Fallback
     * Allows the contract to receive rewards
     */
    receive() external payable {}

    ////////////////////////////
    // Public & External
    ////////////////////////////
    /**
     * Allows users to redeem ETH by burning owned by them RBT
     * @param _amount amount ETH to redeem
     */
    function redeem(uint256 _amount) external mustBeMoreThanZero(_amount) {
        // Accumulates the balance of the user so it is up to date with any interest accumulated.
        if (_amount == type(uint256).max) {
            _amount = i_rebaseToken.balanceOf(msg.sender);
        }
        i_rebaseToken.burn(msg.sender, _amount);
        (bool success, ) = payable(msg.sender).call{value: _amount}("");

        if (!success) {
            revert Vault__RedeemFailed(msg.sender, _amount);
        }

        emit Vault__Redeem(msg.sender, _amount);
    }

    ////////////////////////////
    // Internal & Private
    ////////////////////////////
    ////////////////////////////
    // View & Pure
    ////////////////////////////
    /**
     * @return address the address of the RebaseToken
     */
    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rebaseToken);
    }
}
