// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

/**
 * @title Multisig
 * @author Garv
 * Develop a multi-signature wallet smart contract using Solidity. The contract should allow multiple owners to collectively control the funds in the wallet. The key features include:
 *     A wallet with multiple owners, each having their own private key.
 *     A specified number of owners (threshold) is required to approve and execute a transaction.
 *     Owners can submit, approve, and cancel transactions.
 */
contract MultiSigWallet {
    mapping(address => bool) public isOwner;
    uint256 public numApprovalsRequired;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        mapping(address => bool) isApproved;
        uint256 numApprovals;
    }

    Transaction[] public transactions;

    event Deposit(address indexed sender, uint256 indexed value, uint256 indexed transactionId);
    event Submission(uint256 indexed transactionId);
    event Approval(address indexed sender, uint256 indexed transactionId);
    event Execution(uint256 indexed transactionId);
    event ExecutionFailed(uint256 indexed transactionId);

    constructor(address[] memory _owners, uint256 _numApprovalsRequired) {
        require(_owners.length > 0, "Owners required");
        require(_numApprovalsRequired > 0 && _numApprovalsRequired <= _owners.length, "Invalid number of approvals");

        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), "Invalid owner");
            require(!isOwner[_owners[i]], "Owner not unique");

            isOwner[_owners[i]] = true;
        }

        numApprovalsRequired = _numApprovalsRequired;
    }

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    modifier notExists(uint256 transactionId) {
        require(transactionId < transactions.length, "Transaction does not exist");
        _;
    }

    modifier notExecuted(uint256 transactionId) {
        require(!transactions[transactionId].executed, "Transaction already executed");
        _;
    }

    modifier notApproved(uint256 transactionId) {
        require(!transactions[transactionId].isApproved[msg.sender], "Transaction already approved");
        _;
    }

    /**
     * @dev Owner submits a transaction in the wallet
     * @param to Address of whom the value is to be sent
     * @param value Value to be sent in the transaction
     * @param data Data to be sent in the transaction
     */
    function submitTransaction(address to, uint256 value, bytes memory data) external onlyOwner {
        uint256 transactionId = transactions.length;

        transactions.push(Transaction({to: to, value: value, data: data, executed: false, numApprovals: 0}));

        emit Submission(transactionId);
        approveTransaction(transactionId);
    }

    /**
     * @dev Approval of the transaction  by any owner
     * @param transactionId ID of the transaction which is to be approved
     */
    function approveTransaction(uint256 transactionId)
        public
        onlyOwner
        notExists(transactionId)
        notExecuted(transactionId)
        notApproved(transactionId)
    {
        transactions[transactionId].isApproved[msg.sender] = true;
        transactions[transactionId].numApprovals += 1;

        emit Approval(msg.sender, transactionId);

        if (transactions[transactionId].numApprovals == numApprovalsRequired) {
            executeTransaction(transactionId);
        }
    }

    /**
     * @dev Request for cancelation by an owner.
     * @param transactionId ID of the transaction which is to be executed.
     */
    function cancelTransaction(uint256 transactionId)
        external
        onlyOwner
        notExists(transactionId)
        notExecuted(transactionId)
    {
        require(transactions[transactionId].isApproved[msg.sender], "Transaction not approved by owner");

        transactions[transactionId].isApproved[msg.sender] = false;
        transactions[transactionId].numApprovals -= 1;

        emit Approval(msg.sender, transactionId);
    }

    /**
     * @dev Final execution of transaction after threshold is reached
     * @param transactionId ID of the transaction which is to be executed
     */
    function executeTransaction(uint256 transactionId)
        public
        onlyOwner
        notExists(transactionId)
        notExecuted(transactionId)
    {
        if (transactions[transactionId].numApprovals == numApprovalsRequired) {
            Transaction storage transaction = transactions[transactionId];
            transaction.executed = true;

            (bool success,) = transaction.to.call{value: transaction.value}(transaction.data);
            if (success) {
                emit Execution(transactionId);
            } else {
                emit ExecutionFailed(transactionId);
                transaction.executed = false;
            }
        }
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, transactions.length);
    }
}
