// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./MilestoneNFTv2.sol";

contract CiriverseDAO is Ownable {
    // data
    // enum for vote
    // Create an enum named Vote containing possible options for a vote
    enum Vote {
        OPTION_1, // OPTION_1 = 0
        OPTION_2 // OPTION_2 = 1
    }
    // Create a struct named Proposal containing all relevant information
    struct Proposal {
        // deadline - the UNIX timestamp until which this proposal is active. Proposal can be executed after the deadline has been exceeded.
        uint256 deadline;
        // option1 - game or option to pick from donators/fans
        string option1;
        // option2 - game or option to pick from donators/fans
        string option2;
        // votesOpt1 - number of votes for votesOpt1
        uint256 votesOpt1;
        // votesOpt2 - number of votes for votesOpt2
        uint256 votesOpt2;
        // executed - whether or not this proposal has been executed yet. Cannot be executed before the deadline has been exceeded.
        bool executed;
        // voters - a mapping of address voters
        mapping(address => uint256) voters;
        // results
        string result;
    }

    // Create a mapping of address to array of Proposal
    mapping(address => mapping(uint256 => Proposal)) public s_proposals;
    // Mapping address to number of proposals that have been created
    mapping(address => uint256) public numProposals;
    // milestoneNFT address
    address private milestoneAddress;

    // constructor set up milestoneAddress address
    constructor(address _milestoneAddress) {
        milestoneAddress = _milestoneAddress;
    }

    // Create a modifier which only allows a function to be
    // called by someone who owns at least 1 creator milestone NFT
    modifier nftHolderOnly(address creator) {
        uint256 tokenId = MilestoneNFTv2(milestoneAddress).getTokenId(
            creator,
            0
        );
        require(
            MilestoneNFTv2(milestoneAddress).balanceOf(msg.sender, tokenId) > 0,
            "Not reach any milestone"
        );
        _;
    }

    // Create a modifier which only allows a function to be
    // called by someone who is a creator
    modifier creatorOnly() {
        require(
            MilestoneNFTv2(milestoneAddress).isCreator(msg.sender),
            "You must register first"
        );
        _;
    }

    // Create a modifier which only allows a function to be
    // called by someone creator who at least setup 1 creator milestone
    modifier withMilestoneOnly() {
        require(
            MilestoneNFTv2(milestoneAddress).getMilestones(msg.sender).length >
                0,
            "Creator have'nt setup Milestone NFTs yet."
        );
        _;
    }

    // Create a modifier which only allows a function to be
    // called if the given proposal's deadline has not been exceeded yet
    modifier activeProposalOnly(address creator, uint256 proposalIndex) {
        require(
            s_proposals[creator][proposalIndex].deadline > block.timestamp,
            "DEADLINE_EXCEEDED"
        );
        _;
    }

    // Create a modifier which only allows a function to be
    // called if the given proposals' deadline HAS been exceeded
    // and if the proposal has not yet been executed
    modifier inactiveProposalOnly(address creator, uint256 proposalIndex) {
        require(
            s_proposals[creator][proposalIndex].deadline <= block.timestamp,
            "DEADLINE_NOT_EXCEEDED"
        );
        require(
            s_proposals[creator][proposalIndex].executed == false,
            "PROPOSAL_ALREADY_EXECUTED"
        );
        _;
    }

    /** @dev createProposal allows a MilestoneNFT creator to create a new proposal in the DAO
     * @param _option1 - the option1 creator to make if this proposal pass if this proposal passes
     * @param _option2 - the option2 creator to make if this proposal pass if this proposal passes
     * @return Returns the proposal index for the newly created proposal
     */
    function createProposal(string calldata _option1, string calldata _option2)
        external
        creatorOnly
        withMilestoneOnly
        returns (uint256)
    {
        // should also check if creator have milestoneNFTs or not, because without it no donators can vote.
        Proposal storage proposal = s_proposals[msg.sender][
            numProposals[msg.sender]
        ];
        // set proposal options
        proposal.option1 = _option1;
        proposal.option2 = _option2;
        // Set the proposal's voting deadline to be (current time + 30 minutes)
        proposal.deadline = block.timestamp + 30 minutes;
        // increment the num proposal for this creator
        numProposals[msg.sender]++;

        return numProposals[msg.sender] - 1;
    }

    /// @dev voteOnProposal allows a creator MilestoneNFT holder to cast their vote on an active proposal
    /// @param creator - address of creator
    /// @param proposalIndex - the index of the proposal to vote on in the proposals array
    /// @param vote - the type of vote they want to cast
    function voteOnProposal(
        address creator,
        uint256 proposalIndex,
        Vote vote
    )
        external
        nftHolderOnly(creator)
        activeProposalOnly(creator, proposalIndex)
    {
        Proposal storage proposal = s_proposals[creator][proposalIndex];

        // uint256 voterNFTBalance = cryptoDevsNFT.balanceOf(msg.sender);
        // uint8[2] memory voterNFTBalance = MilestoneNFTv2(milestoneAddress).balanceOfBatch([msg.sender, msg.sender], [0,1]);
        uint256 numHoldNFTs = MilestoneNFTv2(milestoneAddress).getVotesCount(
            creator,
            msg.sender
        );
        // substract holdNFTs count with vote count
        uint256 numVotes = numHoldNFTs - proposal.voters[msg.sender];

        require(numVotes > 0, "Already vote or not elligible");

        if (vote == Vote.OPTION_1) {
            proposal.votesOpt1 += numVotes;
            proposal.voters[msg.sender] += numVotes;
        } else {
            proposal.votesOpt2 += numVotes;
            proposal.voters[msg.sender] += numVotes;
        }
    }

    /// @dev executeProposal allows any creator MilestoneNFTs holder to execute a proposal after it's deadline has been exceeded
    /// @param proposalIndex - the index of the proposal to execute in the proposals array
    function executeProposal(address creator, uint256 proposalIndex)
        external
        nftHolderOnly(creator)
        inactiveProposalOnly(creator, proposalIndex)
    {
        Proposal storage proposal = s_proposals[creator][proposalIndex];

        // If the proposal has more YAY votes than NAY votes
        // purchase the NFT from the FakeNFTMarketplace
        if (proposal.votesOpt1 > proposal.votesOpt2) {
            proposal.result = proposal.option1;
        } else {
            proposal.result = proposal.option2;
        }
        proposal.executed = true;
    }

    /**
     * @dev get numProposals for spesific creator
     */
    function getNumProposals(address creator) external view returns (uint256) {
        return numProposals[creator];
    }

    /**
     * @dev check if donators can vote
     */
    function IsCanVote(address creator, uint256 proposalIndex)
        external
        view
        returns (bool)
    {
        Proposal storage proposal = s_proposals[creator][proposalIndex];

        uint256 numHoldNFTs = MilestoneNFTv2(milestoneAddress).getVotesCount(
            creator,
            msg.sender
        );
        // substract holdNFTs count with vote count
        uint256 numVotes = numHoldNFTs - proposal.voters[msg.sender];
        return (numVotes > 0);
    }
}
