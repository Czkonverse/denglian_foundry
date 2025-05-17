// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

contract MultiSigWallet {
    // Events
    event ProposalCreated(
        uint256 indexed proposalId, address indexed proposer, address target, uint256 value, bytes data
    );
    event ProposalConfirmed(uint256 indexed proposalId, address indexed confirmer);
    event ProposalExecuted(uint256 indexed proposalId, address indexed executor);

    // State variables
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public threshold;

    struct Proposal {
        address target;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmCount;
    }

    Proposal[] public proposals;
    mapping(uint256 => mapping(address => bool)) public confirmations;

    // Constructor
    constructor(address[] memory _owners, uint256 _threshold) {
        require(_owners.length > 0, "Owners required");
        require(_threshold > 0 && _threshold <= _owners.length, "Invalid threshold");

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        threshold = _threshold;
    }

    // Submit a proposal for arbitrary call
    function submitProposal(address _target, uint256 _value, bytes calldata _data) external onlyOwner {
        proposals.push(Proposal({target: _target, value: _value, data: _data, executed: false, confirmCount: 0}));

        emit ProposalCreated(proposals.length - 1, msg.sender, _target, _value, _data);
    }

    // Confirm proposal
    function confirmProposal(uint256 proposalId) external onlyOwner {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Proposal already executed");
        require(!confirmations[proposalId][msg.sender], "Already confirmed");

        confirmations[proposalId][msg.sender] = true;
        proposal.confirmCount++;

        emit ProposalConfirmed(proposalId, msg.sender);
    }

    // Execute proposal
    function executeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Proposal already executed");
        require(proposal.confirmCount >= threshold, "Not enough confirmations");

        proposal.executed = true;

        (bool success,) = proposal.target.call{value: proposal.value}(proposal.data);
        require(success, "Execution failed");

        emit ProposalExecuted(proposalId, msg.sender);
    }

    // Modifier
    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    // Accept ETH
    receive() external payable {}
}
