// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MultiSigWallet {
    // event
    event ProposalCreated(
        uint256 indexed proposalId, address indexed proposer, address token, address to, uint256 amount
    );
    event ProposalConfirmed(uint256 indexed proposalId, address indexed confirmer);
    event ProposalExecuted(uint256 indexed proposalId, address indexed executor);

    // state variables
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public threshold;

    struct Proposal {
        address token;
        address to;
        uint256 amount;
        bool executed;
        uint256 confirmCount;
    }

    Proposal[] public proposals;
    mapping(uint256 => mapping(address => bool)) public confirmations;

    // constructor
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

    // 提交提案
    // 任何⼀个拥有者都可以提交提案
    function submitProposal(address _token, address _to, uint256 _amount) external returns (uint256) {
        require(isOwner[msg.sender], "Not an owner");
        require(_token != address(0), "Invalid token address");
        require(_to != address(0), "Invalid recipient address");
        require(_amount > 0, "Amount must be > 0");

        Proposal memory proposal = Proposal({
            token: _token,
            to: _to,
            amount: _amount,
            executed: false,
            confirmCount: 1 // 自动确认
        });

        proposals.push(proposal);
        uint256 proposalId = proposals.length - 1;

        confirmations[proposalId][msg.sender] = true;

        emit ProposalCreated(proposalId, msg.sender, _token, _to, _amount);
        emit ProposalConfirmed(proposalId, msg.sender);

        return proposalId;
    }

    // 多签确认
    function confirmProposal(uint256 proposalId) external {
        require(isOwner[msg.sender], "Not an owner");
        require(proposalId < proposals.length, "Invalid proposal ID");

        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Proposal already executed");
        require(!confirmations[proposalId][msg.sender], "Already confirmed");

        confirmations[proposalId][msg.sender] = true;
        proposal.confirmCount += 1;

        emit ProposalConfirmed(proposalId, msg.sender);
    }

    // 达到多签⻔槛，任何⼈都可以执⾏交易
    function executeProposal(uint256 proposalId) external {
        require(proposalId < proposals.length, "Invalid proposal ID");

        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Proposal already executed");
        require(proposal.confirmCount >= threshold, "Not enough confirmations");

        proposal.executed = true;

        // 执行ERC20转账
        bool success = IERC20(proposal.token).transfer(proposal.to, proposal.amount);
        require(success, "ERC20 transfer failed");

        emit ProposalExecuted(proposalId, msg.sender);
    }
}
