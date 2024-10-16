// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "./ICelo.sol";

contract SaveCelo{

    address celotoken;
    address owner;
    address newOwner;

    uint256 internal contractBalance;

    bool internal locked;

    struct UserAccount{
        uint256 amount;
        uint256 duration;
    }

    mapping (address => UserAccount[]) users;

    constructor(address _tokenAddress){
        celotoken = _tokenAddress;
        owner = msg.sender;
    }

    //modifiers
    modifier reentrancyGuard() {
        require(!locked, "Not allowed to re-enter");

        locked = true;
        _;
        locked = false;
    }
    modifier onlyOwner(){
        require(msg.sender == owner, "Only owner can access");
        _;
    }

    //event
    event DepositSuccessful(address indexed user, uint256 amount, uint256 time);
    event WithdrawalSuccessful(address indexed user, uint256 amount, uint256 time);

    function depositCelo(uint256 _amount, uint256 _duration) external reentrancyGuard {
        require(msg.sender != address(0), "Zero address not allowed");

        uint256 userBal = IERC20(celotoken).balanceOf(msg.sender);

        require(userBal >= _amount, "Your balance is not enough");

        uint256 allowedAmount = IERC20(celotoken).allowance(msg.sender, address(this));

        require(allowedAmount >= _amount, "Amount allowed is not enough"); 

        bool sent = IERC20(celotoken).transferFrom(msg.sender, address(this), _amount);

        require(sent, "Transfer not executed");

        contractBalance += _amount;

        UserAccount memory useracct;
        useracct.amount = _amount;
        useracct.duration = block.timestamp + _duration;

        users[msg.sender].push(useracct);

        emit DepositSuccessful(msg.sender, _amount, block.timestamp);

    }

    function withdrawFunds(uint8 _index) external reentrancyGuard {
        require(msg.sender != address(0), "Zero address not allowed");

        require(_index < users[msg.sender].length, "Out of bound");

        UserAccount storage useracct = users[msg.sender][_index];

        require(useracct.duration < block.timestamp, "Not yet due");

        uint256 userBal = useracct.amount;

        useracct.amount = 0;
        useracct.duration = 0; 

        contractBalance -= userBal;

        IERC20(celotoken).transfer(msg.sender, userBal);

        emit WithdrawalSuccessful(msg.sender, userBal, block.timestamp);

    }

    function getContractBalance() external view onlyOwner returns (uint256){
        return contractBalance;
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(msg.sender != address(0), "It can't be you");

        require(_newOwner != address(0), "new owner can't be zero address");
        
        newOwner = _newOwner;
    }

    function claimOwnership() external {
        require(msg.sender != address(0), "It can't be you");
        
        require(msg.sender == newOwner, "Not your turn yet");

        owner = newOwner;

        newOwner = address(0);
    }

}