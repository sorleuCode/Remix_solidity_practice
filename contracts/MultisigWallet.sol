// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

contract Multisig {

    address[] public signers;
    uint256 quorum;
    uint256 txCount;

    address owner;
    address nextOwner;

    struct Transaction {
        uint256 id;
        uint256 amount;
        address receiver;
        uint256 signersCount;
        bool isExecuted;
        address txCreator;
    }


    Transaction[] allTransactions;

    mapping(uint256 => mapping(address => bool)) hasSigned;

    mapping (uint256 => Transaction) transactions;
    mapping (address => bool) isValidSigner;
    

    constructor(address[] memory _validSigners, uint256 _quorum) payable  {

        owner = msg.sender;
        signers = _validSigners;
        quorum = _quorum;

        for (uint i = 0; i < _validSigners.length; i++) {
            require(_validSigners[i] != address(0), "Get out");

            isValidSigner[_validSigners[i]] = true;
        }
    }


    function initiateTransaction(uint256 _amount, address _receiver) external  {
        require(msg.sender != address(0), "Zero address not allowed");

        require(_amount > 0, "Zero value not allowed");

        onlyValidSigner();


        uint256 _txId = txCount + 1;

        Transaction storage tns = transactions[_txId];

        tns.id = _txId;
        tns.amount = _amount;
        tns.receiver = _receiver;
        tns.signersCount = tns.signersCount + 1;
        tns.txCreator = msg.sender;

        allTransactions.push(tns);

        hasSigned[_txId][msg.sender] = true;

        txCount = txCount + 1;
    }

    function approveTransaction(uint256 _txId) external  {
        require(_txId <= txCount, "Invalid transaction id");
        require(msg.sender != address(0), "Zero address detected");

        onlyValidSigner();

        require(!hasSigned[_txId][msg.sender], "Can't sign twice");
        Transaction storage tns = transactions[_txId];
        require(address(this).balance >= tns.amount, "Insufficient contract balance");

        require(!tns.isExecuted, "transaction already executed");
        require(tns.signersCount < quorum, "Quorum count reached");

        tns.signersCount = tns.signersCount + 1;

        hasSigned[_txId][msg.sender] = true;

        if(tns.signersCount == quorum) {
            tns.isExecuted = true;
            payable(tns.receiver).transfer(tns.amount);
        }
    }

    function transferOwnership(address _newOwner) external  {
        onlyOwner();
        nextOwner = _newOwner;
    }

    function claimOwnership() external  {
        require(msg.sender == nextOwner, "Not next owner");

        owner = msg.sender;

        nextOwner = address(0);
    }


    function addValidSigner(address _newSigner) external  {
        onlyOwner();

        require(!isValidSigner[_newSigner], "Signer already exist");
        isValidSigner[_newSigner] = true;

        signers.push(_newSigner);
    }

    function removeSigner(uint32 _index) external  {
        onlyOwner();

        require(_index < signers.length, "Invalid index");
        signers[_index] = signers[signers.length - 1];

        isValidSigner[signers[_index]] = false;

        signers.pop();
    }


    function getAllTransaction () external  view returns(Transaction[] memory) {
        return allTransactions;
    }

    function onlyOwner() private view {
        require(isValidSigner[msg.sender], "Not valid signer");
    }

    function onlyValidSigner () private view {
        require(isValidSigner[msg.sender], "Not valid signer");
    }

//These two methods below makes it possible for this contract to receive ether
    receive() external payable { }

    fallback() external payable { }
}

//["0xdD870fA1b7C4700F2BD7f44238821C26f7392148", "0x583031D1113aD414F02576BD6afaBfb302140225", "0x4B0897b0513fdC7C541B6d9D7E929C4e5364D2dB", "0x14723A09ACff6D2A60DcdF7aA4AFf308FDDC160C", "0xCA35b7d915458EF540aDe6068dFe2F44E8fa733c"]