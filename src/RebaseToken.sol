// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {ERC20} from "@openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin-contracts/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin-contracts/contracts/access/AccessControl.sol";

/**
 * @title RebaseToken
 * @author Metodiy Kozhuharov
 * @notice This is a cross-chain rebase token that incentivises users to deposit into a vault and gain interest in rewards.
 * @notice The interest rate in the smart contract can only decrease
 * @notice Each will user will have their own interest rate that is the global interest rate at the time of depositing.
 * @notice The Total Supply of the token will show only the Minted tokens, excluding any Accrued Interest.
 * @notice Known vulnarability is that the owner can grant MINT_AND_BURN_ROLE to anyone.
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    ////////////////////////////
    // Error Codes
    ////////////////////////////
    error RebaseToken__InterestRateCanOnlyDecrease(
        uint256 oldInterestRate,
        uint256 newInterestRate
    );
    error RebaseToken__NotOwner();
    error RebaseToken__NotZeroAddress();
    error RebaseToken__MustBeMoreThanZero();

    ////////////////////////////
    // State variables
    ////////////////////////////
    uint256 private constant PRECISION = 1e18;
    bytes32 private constant MINT_AND_BURN_ROLE =
        keccak256("MINT_AND_BURN_ROLE");
    uint256 private s_interestRate = 5e10; // 0,0000000005% or 0,00000005 as decimal per second
    mapping(address user => uint interestRate) private s_usersInterestRate;
    mapping(address user => uint lastTimeAccruedInterestMinted)
        private s_usersLastTimeAccruedInterestMinted;

    ////////////////////////////
    // Events
    ////////////////////////////
    event RebaseToken__InterestRateChanged(
        uint256 indexed oldInterestRate,
        uint256 indexed newInterestRate
    );
    event RebaseToken__MintedAccruedInterest(
        address user,
        uint256 balanceIncrease
    );

    ////////////////////////////
    // Modifiers
    ////////////////////////////
    modifier notZeroAddress(address _to) {
        if (_to == address(0)) {
            revert RebaseToken__NotZeroAddress();
        }
        _;
    }
    modifier mustBeMoreThanZero(uint256 _amount) {
        if (_amount <= 0) {
            revert RebaseToken__MustBeMoreThanZero();
        }
        _;
    }

    ////////////////////////////
    // Functions
    ////////////////////////////
    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender) {}

    ////////////////////////////
    // Public & External
    ////////////////////////////
    function grantMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    /**
     * Set new interest rate.
     * @param _newInterestRate The new interest rate we want to apply
     */
    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        if (_newInterestRate >= s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(
                s_interestRate,
                _newInterestRate
            );
        }
        s_interestRate = _newInterestRate;
        emit RebaseToken__InterestRateChanged(s_interestRate, _newInterestRate);
    }

    /**
     * @notice Along with minting the requested amount of tokens, we use the transaction to mint also the Accrued Interest (if any).
     * This function is allowed only for Vault and RebaseTokenPool as those have MINT_AND_BURN_ROLE
     * @param _to The address we want to mint tokens to.
     * @param _amount The amount of tokens to mint.
     * @param _userInterestRate The new interest rate we want to set for the user
     */
    function mint(
        address _to,
        uint256 _amount,
        uint256 _userInterestRate
    )
        external
        notZeroAddress(_to)
        mustBeMoreThanZero(_amount)
        onlyRole(MINT_AND_BURN_ROLE)
    {
        // Before user mint by himself, the protocol mints the Accrued Interest.
        _mintAccruedInterest(_to);

        // Interest rate is changed once the user mints new tokens.
        s_usersInterestRate[_to] = _userInterestRate;
        _mint(_to, _amount);
    }

    /**
     * @notice Burn the user tokens when they withdraw from the voult
     * @param _from The user to burn the tokens from
     * @param _amount The amount of tokens to burn
     */
    function burn(
        address _from,
        uint256 _amount
    )
        external
        notZeroAddress(_from)
        mustBeMoreThanZero(_amount)
        onlyRole(MINT_AND_BURN_ROLE)
    {
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    /**
     * @notice During transfer we also mint the Accrued Interest
     * @notice A know functionality is, that while transfers, we do not update the interest, which might result in situation, where a user deposit in a very early stage, has high interest, and later on, he creates second account and transfers lump amount of tokens to his initial account, where he will benefit of the high interest.
     * @param _to transfer to address
     * @param _amount amount to transfer
     */
    function transfer(
        address _to,
        uint256 _amount
    )
        public
        override
        notZeroAddress(_to)
        mustBeMoreThanZero(_amount)
        returns (bool)
    {
        // Accumulates the balance of the user so it is up to date with any interest accumulated.
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        _transferMintAccruedInterest(msg.sender, _to);
        return super.transfer(_to, _amount);
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    )
        public
        override
        notZeroAddress(_from)
        notZeroAddress(_to)
        mustBeMoreThanZero(_amount)
        returns (bool)
    {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _transferMintAccruedInterest(_from, _to);
        _spendAllowance(_from, msg.sender, _amount);
        return super.transferFrom(_from, _to, _amount);
    }

    ////////////////////////////
    // Internal & Private
    ////////////////////////////
    /**
     * Mint Accrued Interest
     * @param _user The user we want to mint the accrued interest
     */
    function _mintAccruedInterest(address _user) private {
        uint256 principalBalance = super.balanceOf(_user);
        uint256 totalBalance = balanceOf(_user);
        uint256 balanceIncrease = totalBalance - principalBalance;

        s_usersLastTimeAccruedInterestMinted[_user] = block.timestamp;

        if (balanceIncrease > 0) {
            emit RebaseToken__MintedAccruedInterest(_user, balanceIncrease);
            _mint(_user, balanceIncrease);
        }
    }

    /**
     * Calculate user accumulated interest sinceLast update
     * @param _user User address
     */
    function _calculateUserAccumulatedInterestSinceLastUpdate(
        address _user
    ) internal view returns (uint256 accumulatedInterest) {
        uint256 timeElapsed = block.timestamp -
            s_usersLastTimeAccruedInterestMinted[_user];

        accumulatedInterest =
            (s_usersInterestRate[_user] * timeElapsed) +
            PRECISION;
    }

    function _transferMintAccruedInterest(address _from, address _to) private {
        _mintAccruedInterest(_from);
        _mintAccruedInterest(_to);

        // Check if reciever has balance and if not, set interest rate, and timestamp so it can start accumulating interest.
        if (balanceOf(_to) == 0) {
            s_usersInterestRate[_to] = s_usersInterestRate[_from];
        }
    }

    ////////////////////////////
    // View & Pure
    ////////////////////////////
    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    function getUserInterestRate(
        address _user
    ) external view returns (uint256) {
        return s_usersInterestRate[_user];
    }

    /**
     * We override the ERC20 balance functions, so that we return the principal + interest accumulate (if any).
     * @param _user The user we check the balance
     */
    function balanceOf(address _user) public view override returns (uint256) {
        uint256 userPrincipalBalance = super.balanceOf(_user);
        uint256 accumulatedInterest = _calculateUserAccumulatedInterestSinceLastUpdate(
                _user
            );

        // We devide by PRECISION as late as possible to achieve as better as possible precision.
        return (userPrincipalBalance * accumulatedInterest) / PRECISION;
    }

    /**
     * @notice Returns the current principal balance which is the total amount of RBT minted. It excludes any Accrued Interest since last time the user interacted with the Protocol.
     * @param _user the address of the user for which we want to see the principal balance
     * @return principalBalance
     */
    function principalBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }
}
