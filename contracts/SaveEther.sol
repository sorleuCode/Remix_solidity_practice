// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract SaveEther {  // To save a native token, which is ether

    address public owner;

    struct userAccount{ // struct is use to group related data
        uint256 amount;
        uint256 duration;
    }

    mapping (address user => userAccount) userInfo;  // For every "user" must have amount, and duration of when they stake it.

    constructor(){
        owner = msg.sender;
    }

    event Transfer(address indexed user, uint256 _amount);

    // Gas optimization
    function onlyOwner() private view{    
        require(msg.sender == owner, "User not allowed");
    }
    
    function depositEther(uint32 _duration) public payable {
        // payable is used with method or variable that can received or send ethers(native token)
        require(msg.sender != address(0), "Not permitted");   // msg.sender will show the address of the sender
        require(msg.value >= 1 ether, "amount is too small");  // msg.value is the money you want to deposit

        // Initialize the Struct and pass in the real value
        // Instance of the account
        userAccount memory useracct;

        useracct.amount = msg.value;
        useracct.duration = block.timestamp + _duration;

        userInfo[msg.sender] = useracct; 
    }


    function withdrawEther() public payable  {
        require(msg.sender != address(0), "Not permitted");

        userAccount storage useracct = userInfo[msg.sender];  // we create another instance and we called it userAcount.

        require(useracct.amount >= 1 ether, "Balance is not enough");
        require(block.timestamp > useracct.duration, "Not yet due");

        uint256 bal = useracct.amount;

        useracct.amount = 0;
        useracct.duration = 0;

        (bool sent, ) = payable(msg.sender).call{value: bal}("");

        if (sent){
            emit Transfer(msg.sender, bal);
        }

    }

    function getContractBalance() public view returns (uint256) {
        onlyOwner();
        return address(this).balance;
    }

    function getDepositInfo() public view returns (uint256, uint256){
        userAccount storage userAcct = userInfo[msg.sender];
        return (userAcct.amount, userAcct.duration);
}
}
