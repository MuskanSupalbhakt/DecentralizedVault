// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title DecentralizedVault
 * @dev A secure decentralized vault for storing and managing Ether deposits
 * @author DecentralizedVault Team
 */
contract DecentralizedVault {
    // State variables
    mapping(address => uint256) private balances;
    mapping(address => uint256) private depositTimestamps;
    address public owner;
    uint256 public totalDeposits;
    uint256 public constant MIN_DEPOSIT = 0.001 ether;
    uint256 public constant WITHDRAWAL_DELAY = 1 hours; // Security delay
    
    // Events
    event Deposit(address indexed user, uint256 amount, uint256 timestamp);
    event Withdrawal(address indexed user, uint256 amount, uint256 timestamp);
    event EmergencyWithdrawal(address indexed owner, uint256 amount);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier validDeposit() {
        require(msg.value >= MIN_DEPOSIT, "Deposit amount too small");
        _;
    }
    
    modifier canWithdraw(uint256 amount) {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        require(
            block.timestamp >= depositTimestamps[msg.sender] + WITHDRAWAL_DELAY,
            "Withdrawal delay not met"
        );
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Core Function 1: Deposit Ether into the vault
     * @notice Users can deposit Ether with minimum amount restriction
     */
    function deposit() external payable validDeposit {
        balances[msg.sender] += msg.value;
        depositTimestamps[msg.sender] = block.timestamp;
        totalDeposits += msg.value;
        
        emit Deposit(msg.sender, msg.value, block.timestamp);
    }
    
    /**
     * @dev Core Function 2: Withdraw Ether from the vault
     * @param amount The amount of Ether to withdraw
     * @notice Users can withdraw their deposited Ether after security delay
     */
    function withdraw(uint256 amount) external canWithdraw(amount) {
        balances[msg.sender] -= amount;
        totalDeposits -= amount;
        
        // Transfer Ether to user
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
        
        emit Withdrawal(msg.sender, amount, block.timestamp);
    }
    
    /**
     * @dev Core Function 3: Get user balance and vault information
     * @param user The address to check balance for
     * @return userBalance The user's current balance
     * @return canWithdrawNow Whether user can withdraw immediately
     * @return timeUntilWithdrawal Time remaining until withdrawal is allowed
     */
    function getVaultInfo(address user) external view returns (
        uint256 userBalance,
        bool canWithdrawNow,
        uint256 timeUntilWithdrawal
    ) {
        userBalance = balances[user];
        
        if (block.timestamp >= depositTimestamps[user] + WITHDRAWAL_DELAY) {
            canWithdrawNow = true;
            timeUntilWithdrawal = 0;
        } else {
            canWithdrawNow = false;
            timeUntilWithdrawal = (depositTimestamps[user] + WITHDRAWAL_DELAY) - block.timestamp;
        }
        
        return (userBalance, canWithdrawNow, timeUntilWithdrawal);
    }
    
    /**
     * @dev Get user's current balance
     * @return The user's balance in the vault
     */
    function getBalance() external view returns (uint256) {
        return balances[msg.sender];
    }
    
    /**
     * @dev Get total contract balance
     * @return The total Ether stored in the contract
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev Emergency withdrawal function for owner only
     * @notice Only for emergency situations - withdraws all funds to owner
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 contractBalance = address(this).balance;
        require(contractBalance > 0, "No funds to withdraw");
        
        (bool success, ) = payable(owner).call{value: contractBalance}("");
        require(success, "Emergency withdrawal failed");
        
        emit EmergencyWithdrawal(owner, contractBalance);
    }
    
    /**
     * @dev Transfer ownership to a new address
     * @param newOwner The address of the new owner
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        owner = newOwner;
    }
    
    // Fallback function to receive Ether
    receive() external payable {
        // Automatically call deposit function
        if (msg.value >= MIN_DEPOSIT) {
            balances[msg.sender] += msg.value;
            depositTimestamps[msg.sender] = block.timestamp;
            totalDeposits += msg.value;
            emit Deposit(msg.sender, msg.value, block.timestamp);
        } else {
            revert("Deposit amount too small");
        }
    }
}
