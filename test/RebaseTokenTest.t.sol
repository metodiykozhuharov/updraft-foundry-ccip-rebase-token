// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";

contract RebaseTokenTest is Test {
    RebaseToken public rebaseToken;
    Vault public vault;

    address public USER = makeAddr("user");
    address public OWNER = makeAddr("owner");
    uint public constant VAULT_REWARD = 1e18;
    uint256 public SEND_VALUE = 1e5;

    function setUp() public {
        vm.startPrank(OWNER);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        addRewardsToVault(VAULT_REWARD);
        vm.stopPrank();
    }

    /* Helper Functions*/
    function addRewardsToVault(uint256 amount) public {
        // send some rewards to the vault using the receive function
        (bool success, ) = payable(address(vault)).call{value: amount}("");
    }

    function testDepositLinear(uint256 amount) public {
        // Arrange / Act
        // Deposit funds
        amount = bound(amount, 1e5, type(uint96).max);

        // 1. deposit
        vm.startPrank(USER);
        vm.deal(USER, amount);
        vault.deposit{value: amount}();

        // 2. our rebase token balance
        uint256 startBalance = rebaseToken.balanceOf(USER);

        // 3. warp the time
        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebaseToken.balanceOf(USER);

        // 4. warp the time again by the same amount
        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseToken.balanceOf(USER);
        vm.stopPrank();

        // Assert
        assertEq(startBalance, amount);
        assertGt(middleBalance, startBalance);
        assertGt(endBalance, middleBalance);
        assertApproxEqAbs(
            endBalance - middleBalance,
            middleBalance - startBalance,
            1
        );
    }

    function testRedeemStraightAway(uint256 amount) public {
        // Arrange
        amount = bound(amount, 1e5, type(uint96).max);

        // Deposit funds
        vm.startPrank(USER);
        vm.deal(USER, amount);
        vault.deposit{value: amount}();

        // Act
        // Redeem funds
        vault.redeem(amount);
        vm.stopPrank();

        // Assert
        uint256 endingBalance = rebaseToken.balanceOf(USER);
        assertEq(endingBalance, 0);
    }

    function testRedeemAfterTimeHasPassed(
        uint256 depositAmount,
        uint256 time
    ) public {
        // Arrange
        time = bound(time, 1000, type(uint96).max); // this is a crazy number of years - 2^96 seconds is a lot
        depositAmount = bound(depositAmount, 1e5, type(uint96).max); // this is an Ether value of max 2^78 which is crazy

        // Deposit funds
        vm.deal(USER, depositAmount);
        vm.prank(USER);
        vault.deposit{value: depositAmount}();

        // check the balance has increased after some time has passed
        vm.warp(time);

        // Get balance after time has passed
        uint256 balance = rebaseToken.balanceOf(USER);

        // Add rewards to the vault
        vm.deal(OWNER, balance - depositAmount);
        vm.prank(OWNER);
        addRewardsToVault(balance - depositAmount);

        // Act
        // Redeem funds
        vm.prank(USER);
        vault.redeem(balance);

        uint256 ethBalance = address(USER).balance;

        // Assert
        assertEq(balance, ethBalance);
        assertGt(balance, depositAmount);
    }

    function testCannotCallMint() public {
        // Deposit funds
        uint256 interestRate = rebaseToken.getInterestRate();
        vm.startPrank(USER);
        vm.expectRevert();
        rebaseToken.mint(USER, SEND_VALUE, interestRate);
        vm.stopPrank();
    }

    function testCannotCallBurn() public {
        // Deposit funds
        vm.startPrank(USER);
        vm.expectRevert();
        rebaseToken.burn(USER, SEND_VALUE);
        vm.stopPrank();
    }

    function testCannotWithdrawMoreThanBalance() public {
        // Deposit funds
        vm.startPrank(USER);
        vm.deal(USER, SEND_VALUE);
        vault.deposit{value: SEND_VALUE}();
        vm.expectRevert();
        vault.redeem(SEND_VALUE + 1);
        vm.stopPrank();
    }

    function testDeposit(uint256 amount) public {
        amount = bound(amount, 1e3, type(uint96).max);
        vm.deal(USER, amount);
        vm.prank(USER);
        vault.deposit{value: amount}();
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5 + 1e3, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e3);

        vm.deal(USER, amount);
        vm.prank(USER);
        vault.deposit{value: amount}();

        address userTwo = makeAddr("userTwo");
        uint256 userBalance = rebaseToken.balanceOf(USER);
        uint256 userTwoBalance = rebaseToken.balanceOf(userTwo);
        assertEq(userBalance, amount);
        assertEq(userTwoBalance, 0);

        // Update the interest rate so we can check the user interest rates are different after transferring.
        vm.prank(OWNER);
        rebaseToken.setInterestRate(4e10);

        // Send half the balance to another user
        vm.prank(USER);
        rebaseToken.transfer(userTwo, amountToSend);
        uint256 userBalanceAfterTransfer = rebaseToken.balanceOf(USER);
        uint256 userTwoBalancAfterTransfer = rebaseToken.balanceOf(userTwo);
        assertEq(userBalanceAfterTransfer, userBalance - amountToSend);
        assertEq(userTwoBalancAfterTransfer, userTwoBalance + amountToSend);
        // After some time has passed, check the balance of the two users has increased
        vm.warp(block.timestamp + 1 days);
        uint256 userBalanceAfterWarp = rebaseToken.balanceOf(USER);
        uint256 userTwoBalanceAfterWarp = rebaseToken.balanceOf(userTwo);
        // check their interest rates are as expected
        // since user two hadn't minted before, their interest rate should be the same as in the contract
        uint256 userTwoInterestRate = rebaseToken.getUserInterestRate(userTwo);
        assertEq(userTwoInterestRate, 5e10);
        // since user had minted before, their interest rate should be the previous interest rate
        uint256 userInterestRate = rebaseToken.getUserInterestRate(USER);
        assertEq(userInterestRate, 5e10);

        assertGt(userBalanceAfterWarp, userBalanceAfterTransfer);
        assertGt(userTwoBalanceAfterWarp, userTwoBalancAfterTransfer);
    }

    function testSetInterestRate(uint256 newInterestRate) public {
        // bound the interest rate to be less than the current interest rate
        newInterestRate = bound(
            newInterestRate,
            0,
            rebaseToken.getInterestRate() - 1
        );
        // Update the interest rate
        vm.startPrank(OWNER);
        rebaseToken.setInterestRate(newInterestRate);
        uint256 interestRate = rebaseToken.getInterestRate();
        assertEq(interestRate, newInterestRate);
        vm.stopPrank();

        // check that if someone deposits, this is their new interest rate
        vm.startPrank(USER);
        vm.deal(USER, SEND_VALUE);
        vault.deposit{value: SEND_VALUE}();
        uint256 userInterestRate = rebaseToken.getUserInterestRate(USER);
        vm.stopPrank();
        assertEq(userInterestRate, newInterestRate);
    }

    function testCannotSetInterestRate(uint256 newInterestRate) public {
        // Update the interest rate
        vm.startPrank(USER);
        vm.expectRevert();
        rebaseToken.setInterestRate(newInterestRate);
        vm.stopPrank();
    }
}
