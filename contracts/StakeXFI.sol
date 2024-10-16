// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./IERC20.sol";

contract StakeXFI {
    IERC20 public XFIContract;
    IERC20 public MPXContract;

    address internal owner;
    address internal newOwner;

    bool locked;

    uint256 immutable MINIMUM_STAKE_AMOUNT = 1_000 * (10**18);
    uint256 immutable MAXIMUM_STAKE_AMOUNT = 100_000 * (10**18);
    

    struct Staking {
        uint256 amount;
        uint256 startTime;
        uint256 duration;
        bool hasWithdrawn;
    }

    mapping (address => Staking[]) stakers;


    constructor(address _xfiAddress, address _mpxAddress) {
        XFIContract = IERC20(_xfiAddress);
        MPXContract = IERC20(_mpxAddress);

        owner = msg.sender;

    }

//events
    event DepositSuccessful(address indexed staker, uint256 amount, uint256 indexed startTime);
    event WithdrawalSuccessful(address indexed staker, uint256 amount, uint256 indexed reward);
    event OwnershipTransfered(address indexed previousOwner, address newOwner);

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


    function stake (uint256 _amount, uint256 _duration) external  reentrancyGuard {
        require(msg.sender != address(0), "Zero address not allowed");

        require(_amount >= MINIMUM_STAKE_AMOUNT && _amount <= MAXIMUM_STAKE_AMOUNT, "Amount is out of range");
        
        require(_duration > 0, "Duration is too short");

        require(XFIContract.balanceOf(msg.sender) >= _amount, "You don't have enough");

        require(XFIContract.allowance(msg.sender, address(this)) >= _amount, "Amount allowed is not enough");

        XFIContract.transferFrom(msg.sender, address(this), _amount);

        Staking memory staking;

        staking.amount = _amount;
        staking.duration = block.timestamp + _duration;
        staking.startTime = block.timestamp;

        stakers[msg.sender].push(staking);
    }


    function withdrawStake (uint256 _index) external  reentrancyGuard returns(bool) {
        require(msg.sender != address(0), "Zero not allowed");

        require(_index < stakers[msg.sender].length, "Out of range");

        Staking storage staking = stakers[msg.sender][_index];

        require(block.timestamp > staking.duration, "Not yet time");

        uint256 amountStaked_ = staking.amount;
        uint256 rewardAmount_ = calculateReward(block.timestamp, staking.duration, staking.amount);


        staking.hasWithdrawn = true;
        staking.amount = 0;
        staking.startTime = 0;
        staking.duration = 0;


        XFIContract.transfer(msg.sender, amountStaked_);
        MPXContract.transfer(msg.sender, rewardAmount_);

        emit WithdrawalSuccessful(msg.sender, amountStaked_, rewardAmount_);

        return true;
    }


    function getStakerInfo (uint8 _index) external view returns (Staking memory) {
         require(msg.sender != address(0), "Zero not allowed");

        require(_index < stakers[msg.sender].length, "Out of range");

        Staking storage staking = stakers[msg.sender][_index];

        return staking;
    }

    function getContractXFIBalance () external onlyOwner view returns (uint256) {
        uint256 bal = XFIContract.balanceOf(address(this));

        return bal;
    }

    function getContractMPXBalance () external onlyOwner view returns (uint256) {
        uint256 bal = MPXContract.balanceOf(address(this));

        return bal;
    }

    function TransferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Zero not allowed" );
        newOwner = _newOwner;
    }
    function claimOwnership() external onlyOwner {
        require(msg.sender != address(0), "Zero not allowed" );
        require (msg.sender == newOwner, "Not your turn");

        emit OwnershipTransfered(owner, newOwner);

        owner = newOwner;
        newOwner = address(0);
    }

    function calculateReward(uint256 _startTime, uint256 _endTime, uint256 _amount ) private pure returns(uint256) {
        uint256 stakeDuration = _endTime - _startTime;

        uint256 totalReward = (1000000 * _amount * stakeDuration) * 1e7;
        return totalReward;

    }


}