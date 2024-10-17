// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./IERC20.sol";

contract StakeXFI{
    IERC20 public XFIContract;
    IERC20 public MPXContract;

    address internal owner;
    address internal newOwner;

    bool internal locked;

    uint256 immutable MINIMUM_STAKE_AMOUNT = 1000 * (10**18);
    uint256 immutable MAXIMUM_STAKE_AMOUNT = 100000 * (10**18);

    uint32 internal constant REWARD_PER_SECOND = 1000000; // 0.000001% 10e11

    struct Staking{
        uint256 amount;
        uint256 startTime;
        uint256 duration;
        bool hasWithdrawn;
    }

    mapping (address => Staking[]) stakers;

    constructor(address _xfiAddress, address _mpxAddress){
        XFIContract = IERC20(_xfiAddress);
        MPXContract = IERC20(_mpxAddress);

        owner = msg.sender;
    }

    event DepositSuccessful(address indexed  staker, uint256 amount, uint256 indexed startTime);
    event WithdrawalSuccessful(address indexed staker, uint256 amount, uint256 indexed reward);
    event OwnershipTransfered(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner(){
        require(msg.sender == owner, "No Access");
        _;
    }

    modifier reentrancyGuard() {
        require(!locked, "Not allowed to re-enter");
        locked = true;
        _;
        locked = false;
    }

    function stake(uint256 _amount, uint256 _duration) external reentrancyGuard {
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

        emit DepositSuccessful(msg.sender, _amount, block.timestamp);
    } 


    function withdrawStake(uint8 _index) external reentrancyGuard returns (bool) {
        require(msg.sender != address(0), "Zero address not allowed");
        require(_index < stakers[msg.sender].length, "Out of range");

        Staking storage staking = stakers[msg.sender][_index];

        require(block.timestamp > staking.duration, "Not yet time");
        require(!staking.hasWithdrawn, "Stake already withdrawn");

        uint256 amountStaked_ = staking.amount;
        uint256 rewardAmount_ = calculateReward(staking.startTime, staking.duration);

        staking.hasWithdrawn = true;
        staking.amount = 0;
        staking.startTime = 0;
        staking.duration = 0;

        XFIContract.transfer(msg.sender, amountStaked_);
        MPXContract.transfer(msg.sender, rewardAmount_);

        emit WithdrawalSuccessful(msg.sender, amountStaked_, rewardAmount_);

        return true;
    }


    function getStakerInfo(uint8 _index) external view returns (Staking memory){
        require(msg.sender != address(0), "Zero address not allowed");

        require(_index < stakers[msg.sender].length, "Out of range");

        Staking memory staking = stakers[msg.sender][_index];
        return staking;
    }

    function getContractMPXBalance() external onlyOwner view returns (uint256){
        uint256 bal = MPXContract.balanceOf(address(this));
        return bal;
    }

    function getContractXFIBalance() external onlyOwner view returns (uint256){
        uint256 bal = XFIContract.balanceOf(address(this));
        return bal;
    }

    function transferOwnership(address _newOwner) external onlyOwner{
        require(_newOwner != address(0), "Zero address not allowed");

        newOwner = _newOwner;
    }

    function claimOwnership() external {
        require(msg.sender != address(0), "Zero address not allowed");
        require(msg.sender == newOwner, "Not your turn");

        emit OwnershipTransfered(owner, newOwner);

        owner = newOwner;
        newOwner = address(0);
    }

    function calculateReward(uint256 _startTime, uint256 _endTime) private pure returns (uint256){
    uint256 stakeDuration = _endTime - _startTime;
    return stakeDuration * REWARD_PER_SECOND;
    }

}