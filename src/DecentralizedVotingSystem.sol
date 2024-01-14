// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

/**
 * @title Decentralized Voting System
 * @author Garv
 * Design a decentralized voting system smart contract using Solidity. The contract should support the following features:
 *     ● Users can register to vote.
 *     ● The owner of the contract can add candidates.
 *     ● Registered voters can cast their votes for a specific candidate.
 *     ● The voting process should be transparent, and the results should be publicly accessible.
 */
contract DecentralizedVotingSystem {
    address public owner;
    mapping(address => bool) public registeredVoters;
    mapping(address => bool) public alreadyVoted;
    mapping(address => bool) public candidates;
    mapping(address => uint256) public votes;

    address[] public candidateList; // Added to keep track of candidates

    uint256 public VOTE_START_TIME;
    uint256 public VOTE_STOP_TIME;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    event VoterRegistered(address voter);
    event CandidateAdded(address candidate);
    event VoteCast(address voter, address candidate);
    event ElectionResult(address winner, uint256 winningVotes);

    constructor(uint256 voteStartTime, uint256 voteStopTime) {
        VOTE_START_TIME = voteStartTime;
        VOTE_STOP_TIME = voteStopTime;
        owner = msg.sender;
    }

    modifier validateRegister() {
        require(!registeredVoters[msg.sender], "You are already registered to vote");
        _;
    }

    modifier validateAddCandidate(address _candidate) {
        require(_candidate != address(0), "Cannot be a zero address");
        require(!candidates[_candidate], "Candidate already added");
        _;
    }

    modifier validateCastVote(address _candidate) {
        require(registeredVoters[msg.sender], "You are not registered to vote");
        require(!alreadyVoted[msg.sender], "You already voted");
        require(candidates[_candidate], "Invalid candidate");
        _;
    }

    /**
     * @dev Registers the user as a voter
     */
    function registerToVote() external validateRegister {
        registeredVoters[msg.sender] = true;
        emit VoterRegistered(msg.sender);
    }

    /**
     * @dev Allows the onwer to add a candidate for voting
     * @param _candidate Address of the candidate
     */
    function addCandidate(address _candidate) external onlyOwner validateAddCandidate(_candidate) {
        candidates[_candidate] = true;
        votes[_candidate] = 0;
        candidateList.push(_candidate);
        emit CandidateAdded(_candidate);
    }

    /**
     * @dev Casts a vote for the given candidate
     * @param _candidate Address of the candidate to vote
     */
    function castVote(address _candidate) external validateCastVote(_candidate) {
        alreadyVoted[msg.sender] = true;
        votes[_candidate] += 1;
        emit VoteCast(msg.sender, _candidate);
    }

    /**
     * @dev Returns the result if the voting
     * @return winner Address of the winning candidate
     * @return winningVotes Number of votes of the winning candidate
     */
    function result() external view returns (address winner, uint256 winningVotes) {
        uint256 maxVotes = 0;

        for (uint256 i = 0; i < candidateList.length; i++) {
            address _candidate = candidateList[i];
            if (votes[_candidate] > maxVotes) {
                maxVotes = votes[_candidate];
                winner = _candidate;
            }
        }

        return (winner, maxVotes);
    }
}
