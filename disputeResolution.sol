// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/iMainContract.sol";


contract DisputeResolution is Ownable {
    address public mainContract;
    IERC20 public immutable finjaTokenInstance;

    struct Dispute {
        address buyer;
        address seller;
        uint256 proposalID;
        uint256 buyerRequestIndex;
        uint256 disputedAmount;
        uint256 buyerVotes;
        uint256 sellerVotes;
        uint256 endTime;
        bool resolveDisputeFunctionTriggered;
        bool resolved;
        bool winnerBuyer;
    }

    mapping(uint256 => Dispute) public disputes;
    mapping(uint256 => mapping(address => uint256)) public stakedTokens;
    mapping(uint256 => mapping(address => uint256)) public buyerStakedTokens;
    mapping(uint256 => mapping(address => uint256)) public sellerStakedTokens;
    mapping(uint256 => uint256) public latestDisputeForProposal;
    mapping(bytes32 => uint256) public disputesForProposalRequest;

    uint256 public winningThreshold;
    uint256 public disputeCount;
    uint256 public votingPeriod;

    event DisputeCreated(uint256 indexed proposalId, uint256 indexed buyerRequestIndex, uint256 indexed disputeId, address buyer, address seller);
    event VoteSubmitted(uint256 indexed disputeId, address voter, bool inFavorOfBuyer, uint256 amount);
    event DisputeResolved(uint256 indexed disputeId, bool inFavorOfBuyer);
    event DisputeReresolveDisputeFunctionTriggered(uint256 indexed disputeId);

    constructor(IERC20 _finjaTokenInstance) {
        finjaTokenInstance = _finjaTokenInstance;
        winningThreshold = 75;
        disputeCount = 0;
    }


    modifier onlyMainContract() {
        require(msg.sender == mainContract, "Caller is not the main contract");
        _;
    }

    function setMainContract (address _mainContract)
        public
        onlyOwner
    {
        mainContract = _mainContract;
    }

function setVotingPeriod (uint256 _votingPeriod) public onlyOwner {
    votingPeriod = _votingPeriod;
}

function generateKey(uint256 proposalID, uint256 buyerRequestIndex) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(proposalID, buyerRequestIndex));
}

function canCreateDispute(uint256 proposalID, uint256 buyerRequestIndex) public view returns (bool) {
    bytes32 key = generateKey(proposalID, buyerRequestIndex);
    uint256 latestDisputeId = disputesForProposalRequest[key];
    if (latestDisputeId == 0) {
        // No dispute with the given proposalID and buyerRequestIndex exists
        return true;
    }
    Dispute memory dispute = disputes[latestDisputeId]; 
    // Check if it's unresolved and end time has passed
    return !dispute.resolved && dispute.endTime <= block.timestamp && dispute.resolveDisputeFunctionTriggered;
}

function createDispute(address buyer, address seller, uint256 proposalID, uint256 buyerRequestIndex, uint256 disputedAmount) public onlyMainContract returns (uint256) {
    require(canCreateDispute(proposalID, buyerRequestIndex), "Cannot create a new dispute for the given proposal and buyer request");
    uint256 disputeId = disputeCount++;
    disputes[disputeId] = Dispute(buyer, seller, proposalID, buyerRequestIndex, disputedAmount, 0, 0, block.timestamp + votingPeriod, false, false, false);
    bytes32 key = generateKey(proposalID, buyerRequestIndex);
    disputesForProposalRequest[key] = disputeId;
    emit DisputeCreated(proposalID, buyerRequestIndex, disputeId, buyer, seller);
    return disputeId;
}

function vote(uint256 disputeId, bool inFavorOfBuyer, uint256 amount) public {
    require(disputeId < disputeCount, "Invalid dispute ID");
    require(block.timestamp < disputes[disputeId].endTime, "Voting period is over");
    require(!disputes[disputeId].resolved, "Dispute has already been resolved");
    
    if(inFavorOfBuyer) {
        require(sellerStakedTokens[disputeId][msg.sender] == 0, "Voter has already voted for the seller");
    } else {
        require(buyerStakedTokens[disputeId][msg.sender] == 0, "Voter has already voted for the buyer");
    }

    finjaTokenInstance.transferFrom(msg.sender, address(this), amount);
    stakedTokens[disputeId][msg.sender] += amount;

    if (inFavorOfBuyer) {
        disputes[disputeId].buyerVotes += amount;
        buyerStakedTokens[disputeId][msg.sender] += amount;
    } else {
        disputes[disputeId].sellerVotes += amount;
        sellerStakedTokens[disputeId][msg.sender] += amount;
    }

    emit VoteSubmitted(disputeId, msg.sender, inFavorOfBuyer, amount);

}


function resolveDispute(uint256 disputeId) public {
    require(!disputes[disputeId].resolved, "Dispute has already been resolved");
    require(block.timestamp > disputes[disputeId].endTime, "The voting period is not over yet!");

    //record that resolution has been tried
    disputes[disputeId].resolveDisputeFunctionTriggered = true;
    emit DisputeReresolveDisputeFunctionTriggered(disputeId);

    uint256 totalVotes = disputes[disputeId].buyerVotes + disputes[disputeId].sellerVotes;
    bool thresholdMet;

    // Checking if neither party reaches the 75% threshold
    if (totalVotes > 0 && 
        (disputes[disputeId].buyerVotes * 100 >= totalVotes * winningThreshold ||
        disputes[disputeId].sellerVotes * 100 >= totalVotes * winningThreshold)) {
        thresholdMet = true;
    } else {
        thresholdMet = false;
    }

    bool inFavorOfBuyer;
    if (thresholdMet) {
        inFavorOfBuyer = disputes[disputeId].buyerVotes * 100 >= totalVotes * winningThreshold;

        if (inFavorOfBuyer) {
            disputes[disputeId].winnerBuyer = true;
            IMainContract(mainContract).releaseEscrowAfterDispute(disputes[disputeId].proposalID, disputes[disputeId].buyerRequestIndex, payable(disputes[disputeId].buyer), disputes[disputeId].disputedAmount);
        } else {
            disputes[disputeId].winnerBuyer = false;
            IMainContract(mainContract).releaseEscrowAfterDispute(disputes[disputeId].proposalID, disputes[disputeId].buyerRequestIndex, payable(disputes[disputeId].seller), disputes[disputeId].disputedAmount);
        }
        disputes[disputeId].resolved = true;
        emit DisputeResolved(disputeId, inFavorOfBuyer);
    } 
}



    function getStakedTokens(uint256 disputeId, address voter) public view returns (uint256 buyerTokens, uint256 sellerTokens) {
        require(disputeId < disputeCount, "Invalid dispute ID");
        buyerTokens = buyerStakedTokens[disputeId][voter];
        sellerTokens = sellerStakedTokens[disputeId][voter];
    }

    function setWinningThreshold(uint256 newThreshold) public onlyOwner {
        require(newThreshold > 0 && newThreshold <= 100, "Invalid threshold");
        winningThreshold = newThreshold;
    }

    function claimTokens(uint256 disputeId) public {
    require(disputeId < disputeCount, "Invalid dispute ID");
    require(disputes[disputeId].resolveDisputeFunctionTriggered, "Dispute resolution has not been attempted yet");

    uint256 amount = stakedTokens[disputeId][msg.sender];
    require(amount > 0, "No tokens to claim");

    uint256 totalVotes = disputes[disputeId].buyerVotes + disputes[disputeId].sellerVotes;
    bool buyerReachedThreshold = disputes[disputeId].buyerVotes * 100 >= totalVotes * winningThreshold;
    bool sellerReachedThreshold = disputes[disputeId].sellerVotes * 100 >= totalVotes * winningThreshold;

    bool thresholdMet = buyerReachedThreshold || sellerReachedThreshold;

    if (thresholdMet) {
        bool voterVotedForBuyer = buyerStakedTokens[disputeId][msg.sender] > 0;
        bool voterVotedForWinner = (buyerReachedThreshold && voterVotedForBuyer) || (sellerReachedThreshold && !voterVotedForBuyer);

        uint256 totalWinnerStakes = buyerReachedThreshold ? disputes[disputeId].buyerVotes : disputes[disputeId].sellerVotes;
        uint256 totalLoserStakes = sellerReachedThreshold ? disputes[disputeId].buyerVotes : disputes[disputeId].sellerVotes;

        if (voterVotedForWinner) {
            uint256 loserTokensToBeDistributed = (totalLoserStakes * 10) / 100;
            uint256 additionalTokens = (amount * loserTokensToBeDistributed) / totalWinnerStakes;
            amount += additionalTokens;
        } else {
            amount = (amount * 90) / 100;
        }
    }

    stakedTokens[disputeId][msg.sender] = 0;
    finjaTokenInstance.transfer(msg.sender, amount);
}


}