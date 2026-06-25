pragma solidity >=0.8.0;

import "./AccessControl.sol";

contract MultiSig is AccessControl {
    struct Transaction {
        bool executed;
        address to;
        uint256 value;
        bytes data;
        bytes32 descriptionHash;
        uint256 confirmations;
    }

    uint256 public requiredConfirmations;
    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public isConfirmed;

    event SubmitTransaction(
        uint256 indexed transactionId,
        address indexed submitter,
        address indexed to,
        uint256 value,
        bytes data,
        bytes32 descriptionHash
    );
    event ConfirmTransaction(uint256 indexed transactionId, address indexed owner);
    event RevokeConfirmation(uint256 indexed transactionId, address indexed owner);
    event ExecuteTransaction(uint256 indexed transactionId, address indexed executor);

    modifier transactionExists(uint256 _transactionId) {
        require(_transactionId < transactions.length, "Transaction does not exist");
        _;
    }

    modifier notExecuted(uint256 _transactionId) {
        require(!transactions[_transactionId].executed, "Transaction already executed");
        _;
    }

    modifier notConfirmed(uint256 _transactionId) {
        require(!isConfirmed[_transactionId][msg.sender], "Transaction already confirmed");
        _;
    }

    constructor(address[] memory _owners, uint256 _requiredConfirmations) AccessControl(_owners) {
        require(
            _requiredConfirmations > 0 && _requiredConfirmations <= _owners.length,
            "Invalid required confirmations"
        );
        requiredConfirmations = _requiredConfirmations;
    }

    receive() external payable {}

    function submitTransaction(
        address _to,
        uint256 _value,
        bytes memory _data,
        bytes32 _descriptionHash
    ) public onlyOwner returns (uint256 transactionId) {
        require(_to != address(0), "Invalid destination");

        transactionId = transactions.length;
        transactions.push(
            Transaction({
                executed: false,
                to: _to,
                value: _value,
                data: _data,
                descriptionHash: _descriptionHash,
                confirmations: 0
            })
        );

        emit SubmitTransaction(transactionId, msg.sender, _to, _value, _data, _descriptionHash);
        confirmTransaction(transactionId);
    }

    function confirmTransaction(uint256 _transactionId)
        public
        onlyOwner
        transactionExists(_transactionId)
        notExecuted(_transactionId)
        notConfirmed(_transactionId)
    {
        Transaction storage txn = transactions[_transactionId];
        isConfirmed[_transactionId][msg.sender] = true;
        txn.confirmations += 1;

        emit ConfirmTransaction(_transactionId, msg.sender);

        if (txn.confirmations >= requiredConfirmations) {
            executeTransaction(_transactionId);
        }
    }

    function revokeConfirmation(uint256 _transactionId)
        public
        onlyOwner
        transactionExists(_transactionId)
        notExecuted(_transactionId)
    {
        require(isConfirmed[_transactionId][msg.sender], "Transaction not confirmed");

        Transaction storage txn = transactions[_transactionId];
        isConfirmed[_transactionId][msg.sender] = false;
        txn.confirmations -= 1;

        emit RevokeConfirmation(_transactionId, msg.sender);
    }

    function executeTransaction(uint256 _transactionId)
        public
        onlyOwner
        transactionExists(_transactionId)
        notExecuted(_transactionId)
    {
        Transaction storage txn = transactions[_transactionId];
        require(txn.confirmations >= requiredConfirmations, "Not enough confirmations");

        txn.executed = true;

        (bool success, ) = txn.to.call{value: txn.value}(txn.data);
        require(success, "Transaction execution failed");

        emit ExecuteTransaction(_transactionId, msg.sender);
    }

    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }

    function getTransaction(uint256 _transactionId)
        public
        view
        transactionExists(_transactionId)
        returns (
            bool executed,
            address to,
            uint256 value,
            bytes memory data,
            bytes32 descriptionHash,
            uint256 confirmations
        )
    {
        Transaction storage txn = transactions[_transactionId];
        return (txn.executed, txn.to, txn.value, txn.data, txn.descriptionHash, txn.confirmations);
    }

    function getConfirmations(uint256 _transactionId)
        public
        view
        transactionExists(_transactionId)
        returns (uint256)
    {
        return transactions[_transactionId].confirmations;
    }
}
