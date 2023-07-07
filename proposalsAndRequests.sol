// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;


import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/iCompletedTransactions.sol";

contract ProposalsAndRequests is Ownable {
using SafeMath for uint256;

address public mainContract;
ICompletedTransactions public completedTransactionsContract;

struct Proposal {
        uint256 amount;
        uint256 escrowBalance;
        uint256 price;
        uint256 date;
        string paymentMethodName;
        bytes32 paymentDetails;
        string comment;
        string username;
        bool active;
        address seller;
        uint256 sellerTransactionsCountasSeller;
        uint256 sellerTransactionsCountasBuyer;
    }

mapping(uint256 => Proposal) public proposals;

uint256[] public proposalIds;
uint256 public proposalCount = 0;
uint256 public historicalProposalCount = 0;

uint256[] public activeProposalIds;
uint256 public activeProposalCount = 0;


    struct BuyerRequest {
        uint256 buyerRequestIndex;
        uint256 proposalId;
        uint256 amount;
        uint256 date;
        address buyer;
        bool accepted;
        bool paymentDeclared;
        bool transactionCompleted;
        bool buyerRequestedtoCancel;
        bool sellerRequestedtoCancel;
        bool disputeCreated;
        bool active;
    }

    struct RequestIndex {
    uint256 proposalId;
    uint256 buyerRequestIndex;
}


mapping(uint256 => mapping(uint256 => BuyerRequest)) public buyerRequests;
mapping(address => RequestIndex[]) public buyerRequestIndicesByBuyer;
mapping(uint256 => uint256) public buyerRequestsLength;

event transactionCancelled (uint256 indexed proposalId, uint256 indexed buyerRequestIndex);


modifier onlyActiveProposal(uint256 proposalId) {
        require(proposals[proposalId].active, "Proposal is not active");
        _;
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

function setCompletedTransactionsContract (address _completedTransactionsContract)
        public
        onlyOwner
    {
        completedTransactionsContract = ICompletedTransactions(_completedTransactionsContract);
    }

function createProposal(
    uint256 amount,
    uint256 price,
    string memory paymentMethodName,
    bytes32 paymentDetails,
    string memory comment, 
    string memory username,
    address seller,
    uint256 sellerTransactionsCountasSeller,
    uint256 sellerTransactionsCountasBuyer
) public {
    proposals[proposalCount] = Proposal({
        amount: amount,
        escrowBalance: 0,
        price: price,
        date: block.timestamp,
        paymentMethodName: paymentMethodName,
        paymentDetails: paymentDetails,
        comment: comment,
        username: username,
        active: true,
        seller: seller, 
        sellerTransactionsCountasSeller: sellerTransactionsCountasSeller,
        sellerTransactionsCountasBuyer: sellerTransactionsCountasBuyer
    });
    proposalIds.push(historicalProposalCount);
    activeProposalIds.push(historicalProposalCount);
    activeProposalCount++;
    proposalCount++;
    historicalProposalCount++;
}


function getProposal(uint256 proposalId) public view returns (Proposal memory) {
    return proposals[proposalId];
}

function getProposalCount() public view returns (uint256) {
    return proposalCount;
}

function getAllProposalIds() public view returns (uint256[] memory) {
    return proposalIds;
}

function deactivateProposal(uint256 proposalId) public onlyMainContract {
    bool canDelete = true;
    for (uint256 i = 0; i < buyerRequestsLength[proposalId]; i++) {
        if (buyerRequests[proposalId][i].accepted && buyerRequests[proposalId][i].active) {
            canDelete = false;
            break;
        }
    }

    require(canDelete, "Cannot delete proposal if a buyer request has been accepted and it's still active");
    proposals[proposalId].active = false;

    // Find the index of the proposalId in the activeProposalIds array
    uint256 indexToBeDeleted;
    for (uint256 i = 0; i < activeProposalCount; i++) {
        if (activeProposalIds[i] == proposalId) {
            indexToBeDeleted = i;
            break;
        }
    }

    // Move the last element to the index to be deleted
    activeProposalIds[indexToBeDeleted] = activeProposalIds[activeProposalCount - 1];

    // Delete the last element
    activeProposalIds.pop();

    // Decrement activeProposalCount
    activeProposalCount--;
}

function deleteProposal(uint256 proposalId) public onlyOwner {
    require(proposalId < proposalCount, "Proposal does not exist");

    // If the proposal is active, remove it from activeProposalIds
    if (proposals[proposalId].active) {
        // Find the index of the proposalId in the activeProposalIds array
        uint256 indexToBeDeleted;
        for (uint256 i = 0; i < activeProposalCount; i++) {
            if (activeProposalIds[i] == proposalId) {
                indexToBeDeleted = i;
                break;
            }
        }

        // Move the last element to the index to be deleted
        activeProposalIds[indexToBeDeleted] = activeProposalIds[activeProposalCount - 1];

        // Delete the last element
        activeProposalIds.pop();

        // Decrement activeProposalCount
        activeProposalCount--;
    }

    // Remove the proposal from the mapping
    delete proposals[proposalId];
    // Find the index of the proposalId in the proposalIds array
    uint256 indexToBeDeletedInProposalIds;
    for (uint256 i = 0; i < proposalCount; i++) {
        if (proposalIds[i] == proposalId) {
            indexToBeDeletedInProposalIds = i;
            break;
        }
    }

    // Move the last element to the index to be deleted
    proposalIds[indexToBeDeletedInProposalIds] = proposalIds[proposalCount - 1];

    // Delete the last element
    proposalIds.pop();
    
    // Decrement proposalCount
    proposalCount--;
}


function getActiveProposalIds() public view returns (uint256[] memory) {
    return activeProposalIds;
}


//Function to request to buy from the Proposals (only Buyer can do this)
function requestToBuy(uint256 proposalId, uint256 amount, address buyer)
        public
        onlyActiveProposal(proposalId)
        onlyMainContract
    {
        uint256 buyerRequestIndex = buyerRequestsLength[proposalId]; 

        BuyerRequest memory buyerRequest = BuyerRequest({
            buyerRequestIndex: buyerRequestIndex,
            proposalId: proposalId,
            amount: amount,
            date: block.timestamp,
            buyer: buyer,
            accepted: false, 
            paymentDeclared: false, 
            buyerRequestedtoCancel: false,
            sellerRequestedtoCancel: false,
            transactionCompleted: false,
            disputeCreated: false,
            active: true
        });

        //store the Buyer's request in a mappings of arrays
        buyerRequests[proposalId][buyerRequestIndex] = buyerRequest;
        buyerRequestIndicesByBuyer[buyer].push(RequestIndex({proposalId: proposalId, buyerRequestIndex: buyerRequestIndex}));
        buyerRequestsLength[proposalId]++;
     
    }


function getBuyerRequest(uint256 proposalId, uint256 buyerRequestIndex) 
    public view returns (BuyerRequest memory) 
{
    return buyerRequests[proposalId][buyerRequestIndex];
}

function getRequestCountByProposal(uint256 proposalId) public view returns (uint256) {
        return buyerRequestsLength[proposalId];
    }

//function to get all active requests by buyer
function getActiveRequestsByBuyer(address buyer) public view returns (BuyerRequest[] memory) {
    RequestIndex[] storage requestIndices = buyerRequestIndicesByBuyer[buyer];
    BuyerRequest[] memory activeRequests = new BuyerRequest[](requestIndices.length);

    uint256 counter = 0;
    for (uint256 i = 0; i < requestIndices.length; i++) {
        BuyerRequest storage request = buyerRequests[requestIndices[i].proposalId][requestIndices[i].buyerRequestIndex];
        if (request.active) {
            activeRequests[counter] = request;
            counter++;
        }
    }

    // Reduce size of activeRequests array to remove empty elements
    BuyerRequest[] memory reducedActiveRequests = new BuyerRequest[](counter);
    for (uint256 i = 0; i < counter; i++) {
        reducedActiveRequests[i] = activeRequests[i];
    }

    return reducedActiveRequests;
}


//return active requests by proposal

function getActiveRequestsByProposal(uint256 proposalId) public view returns (BuyerRequest[] memory) {
    uint256 length = buyerRequestsLength[proposalId];
    BuyerRequest[] memory activeRequests = new BuyerRequest[](length);

    uint256 counter = 0;
    for (uint256 i = 0; i < length; i++) {
        if (buyerRequests[proposalId][i].active) {
            activeRequests[counter] = buyerRequests[proposalId][i];
            counter++;
        }
    }

    // Reduce size of activeRequests array to remove empty elements
    BuyerRequest[] memory reducedActiveRequests = new BuyerRequest[](counter);
    for (uint256 i = 0; i < counter; i++) {
        reducedActiveRequests[i] = activeRequests[i];
    }

    return reducedActiveRequests;
}



function deactivateBuyerRequest (uint256 proposalId, uint256 buyerRequestIndex) public onlyMainContract {
        require(!buyerRequests[proposalId][buyerRequestIndex].accepted, "Cannot deactivate request after seller accepted");
        buyerRequests[proposalId][buyerRequestIndex].active = false;
        }

function acceptBuyerRequest(uint256 proposalId, uint256 buyerRequestIndex, uint256 amount)
    public
    onlyActiveProposal(proposalId)
    onlyMainContract
{

    //Reduce the amount in the Proposal by the amount requested by the Buyer
    proposals[proposalId].amount = proposals[proposalId].amount.sub(buyerRequests[proposalId][buyerRequestIndex].amount);
    //Set the Buyer's request to accepted
    buyerRequests[proposalId][buyerRequestIndex].accepted = true;
    // Add the amount to the escrowBalance
    proposals[proposalId].escrowBalance = proposals[proposalId].escrowBalance.add(amount);

}

    //function for the Buyer to confirm the payment (only Buyer can do this. Inputs: Proposal ID and Buyer's address. Seller must have accepted the Buyer's request to buy. This function changes paymentDeclared to true. This function can only be called once.
function confirmFiatPayment(uint256 proposalId, uint256 buyerRequestIndex)
        public
        onlyActiveProposal(proposalId)
        onlyMainContract
    {
        //Set the Buyer's request to paymentDeclared
        buyerRequests[proposalId][buyerRequestIndex].paymentDeclared = true;

    }

//function for Seller to confirm payment receipt and release Crypto from Escrow to Buyer (only Seller can do this). Inputs: Proposal ID and Buyer's address. Buyer must have declared the payment. This function can only be called once.
function changeProposalAndRequestDataUponCryptoRelease(uint256 proposalId, uint256 buyerRequestIndex, uint256 amount)
        public  
        onlyActiveProposal(proposalId)
        onlyMainContract
    {

    buyerRequests[proposalId][buyerRequestIndex].transactionCompleted = true;
    buyerRequests[proposalId][buyerRequestIndex].active = false;

    proposals[proposalId].escrowBalance = proposals[proposalId].escrowBalance.sub(amount);

    proposals[proposalId].sellerTransactionsCountasSeller = completedTransactionsContract.sellerTransactionCounts (proposals[proposalId].seller);
    proposals[proposalId].sellerTransactionsCountasBuyer = completedTransactionsContract.buyerTransactionCounts (proposals[proposalId].seller);

    //If the amount in the Proposal is 0, set the Proposal to inactive
    if (proposals[proposalId].amount == 0) {
        proposals[proposalId].active = false;
    // Find the index of the proposalId in the activeProposalIds array
    uint256 indexToBeDeleted;
    for (uint256 i = 0; i < activeProposalCount; i++) {
        if (activeProposalIds[i] == proposalId) {
            indexToBeDeleted = i;
            break;
        }
    }
    }
}

function recordDisputeCreation (uint256 proposalId, uint256 buyerRequestIndex)
        public
        onlyMainContract
    {
        buyerRequests[proposalId][buyerRequestIndex].disputeCreated = true;
    }

function recordEscrowReleaseAfterDispute (uint256 proposalId, uint256 buyerRequestIndex, uint256 amount) external onlyMainContract {
    proposals[buyerRequests[proposalId][buyerRequestIndex].proposalId].escrowBalance -= amount;
    if (proposals[proposalId].amount == 0) {
        proposals[proposalId].active = false;
        // Find the index of the proposalId in the activeProposalIds array
    uint256 indexToBeDeleted;
    for (uint256 i = 0; i < activeProposalCount; i++) {
        if (activeProposalIds[i] == proposalId) {
            indexToBeDeleted = i;
            break;
        }
    }
    }
    buyerRequests[proposalId][buyerRequestIndex].active = false;
}

function recordRequestCancellation(uint256 proposalId, uint256 buyerRequestIndex, bool requestedByBuyer) public  onlyMainContract {

    if (requestedByBuyer) {
        buyerRequests[proposalId][buyerRequestIndex].buyerRequestedtoCancel = true;
        } else {
        buyerRequests[proposalId][buyerRequestIndex].sellerRequestedtoCancel = true;
    }
 }

function processCancellation (uint256 proposalId, uint256 buyerRequestIndex) public  onlyMainContract {
    require (buyerRequests[proposalId][buyerRequestIndex].buyerRequestedtoCancel && buyerRequests[proposalId][buyerRequestIndex].sellerRequestedtoCancel, "Both, Buyer and Seller should request cancellation of this transaction");
    buyerRequests[proposalId][buyerRequestIndex].active = false;
    uint256 amount = buyerRequests[proposalId][buyerRequestIndex].amount;
    proposals[proposalId].escrowBalance = proposals[proposalId].escrowBalance.sub(amount);
    proposals[proposalId].amount += amount;
    emit transactionCancelled (proposalId, buyerRequestIndex);
    }
}