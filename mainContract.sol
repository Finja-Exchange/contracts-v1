// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/IDisputeResolution.sol";
import "./interfaces/iFinjaToken.sol";
import "./interfaces/iPaymentMethods.sol";
import "./interfaces/iCompletedTransactions.sol";
import "./interfaces/iProposalsAndRequests.sol";

contract MainContract is Ownable {

    using SafeMath for uint256;
    
    IDisputeResolution public disputeResolutionContract;
    IFinjaToken public immutable finjaTokenInstance;
    IPaymentMethods public paymentMethodsContract;
    ICompletedTransactions public completedTransactionsContract;
    IProposalsAndRequests public proposalsAndRequestsContract;
    IERC20 public immutable USDCTokenInstance;
    uint256 public rewardAmount;
    uint256 public commission;
    
    uint256 public constant MINIMUM_DELAY = 60 minutes;
    mapping (address => uint256) public lastTxTimestamp;


    modifier rateLimited() {
        require(block.timestamp - lastTxTimestamp[msg.sender] >= MINIMUM_DELAY, "You should wait for at least 60 seconds to create another proposal, request or dispute");
        _;
        lastTxTimestamp[msg.sender] = block.timestamp;
    }

    modifier onlyActiveProposal(uint256 proposalId) {
        IProposalsAndRequests.Proposal memory proposal = proposalsAndRequestsContract.getProposal (proposalId);
        require(proposal.active, "Proposal is not active");
        _;
    }

    modifier onlyDisputeResolutionContract() {
    require(msg.sender == address(disputeResolutionContract), "Only Dispute contract can call the function");
    _;
}
    event newProposal (uint256 indexed proposalId);
    event proposalDeactivated (uint256 indexed proposalId);  
    event newBuyerRequest (uint256 indexed proposalID);
    event requestAccepted (uint256 indexed proposalID, uint256 indexed buyerRequestIndex);
    event paymentConfirmed (uint256 indexed proposalID, uint256 indexed buyerRequestIndex);
    event cryptoReleased (uint256 indexed proposalID, uint256 indexed buyerRequestIndex);
    event cancellationRequested (uint256 indexed proposalID, uint256 indexed buyerRequestIndex, address indexed requestor);
    event buyerRequestDeactivated (uint256 indexed proposalID, uint256 indexed buyerRequestIndex);


constructor(address _finjaTokenAddress, IERC20 _USDCTokenInstance, address _paymentMethodsContractAddress, address _completedTransactionsContract, address _proposalsAndRequests, address _disputeResolutionAddress) {
    finjaTokenInstance = IFinjaToken(_finjaTokenAddress);
    USDCTokenInstance = _USDCTokenInstance;
    paymentMethodsContract = IPaymentMethods(_paymentMethodsContractAddress);
    completedTransactionsContract = ICompletedTransactions(_completedTransactionsContract);
    proposalsAndRequestsContract = IProposalsAndRequests(_proposalsAndRequests);
    disputeResolutionContract = IDisputeResolution(_disputeResolutionAddress);
}


//functions to be used by other functions

function checkProposalAndRequestActive(uint256 proposalId, uint256 buyerRequestIndex) public view {
    IProposalsAndRequests.Proposal memory proposal = proposalsAndRequestsContract.getProposal (proposalId);
    IProposalsAndRequests.BuyerRequest memory request = proposalsAndRequestsContract.getBuyerRequest (proposalId, buyerRequestIndex);

    require(proposal.active, "Proposal is not active");
    require(request.active, "Request is not active");
}

function checkMsgSenderRole(uint256 proposalId, uint256 buyerRequestIndex) public view returns(bool) {
    IProposalsAndRequests.Proposal memory proposal = proposalsAndRequestsContract.getProposal (proposalId);
    IProposalsAndRequests.BuyerRequest memory request = proposalsAndRequestsContract.getBuyerRequest (proposalId, buyerRequestIndex);
    bool isBuyer = request.buyer == msg.sender;
    bool isSeller = proposal.seller == msg.sender;
    require(isBuyer || isSeller, "Only for buyer or seller");
    return isBuyer;
}
//functions to change contracts' addresses 

    function setDisputeResolutionContract(address _disputeResolutionAddress)
        public
        onlyOwner
    {
        disputeResolutionContract = IDisputeResolution(
            _disputeResolutionAddress
        );
    }

    function setProposalsAndRequestsContract (address _proposalsAndRequestsContract)
        public
        onlyOwner
    {
        proposalsAndRequestsContract = IProposalsAndRequests (_proposalsAndRequestsContract);
    }

    function setPaymentMethodscontract (address _paymentMethodsContractAddress)
        public
        onlyOwner
    {
        paymentMethodsContract = IPaymentMethods(_paymentMethodsContractAddress);
    }

    function setCompletedTransactionsContract (address _completedTransactionsContract)
        public
        onlyOwner
    {
        completedTransactionsContract = ICompletedTransactions(_completedTransactionsContract);
    }


//regular functions 

function setCommissionAndReward (uint256 _commission, uint256 _rewardAmount) public onlyOwner {
    rewardAmount = _rewardAmount;
    commission = _commission;
    }

function createProposal(
        uint256 amount,
        uint256 price,
        uint256[] memory paymentMethodIndices,
        string memory paymentDetails,
        string memory comment, 
        string memory username
    ) public 
    rateLimited
    {
        require(amount > 0, "Amount must be greater than 0");
        require(USDCTokenInstance.balanceOf(msg.sender) >= amount, "You don't have enough USDC in this wallet");
        require(price > 0, "Price must be greater than 0");
        for(uint i=0; i<paymentMethodIndices.length; i++) {
            require(paymentMethodIndices[i] < paymentMethodsContract.getPaymentMethodCount(), "Payment method does not exist");
        }
        require(bytes(paymentDetails).length > 0, "paymentDetails must not be empty");
        
        string memory paymentMethodName = "";  
        for(uint i=0; i<paymentMethodIndices.length; i++) {
            (string memory paymentMethodNameForIndex, , , ) = paymentMethodsContract.getPaymentMethod(paymentMethodIndices[i]);
            if(i > 0) {
                paymentMethodName = string(abi.encodePacked(paymentMethodName, ", ", paymentMethodNameForIndex));
            } else {
                paymentMethodName = paymentMethodNameForIndex;
            }
        }

        bytes32 paymentDetailsHash = keccak256(abi.encodePacked(paymentDetails));
        uint256 sellerTransactionsCountasSeller = completedTransactionsContract.sellerTransactionCounts(msg.sender);
        uint256 sellerTransactionsCountasBuyer = completedTransactionsContract.buyerTransactionCounts(msg.sender);
        uint256 proposalId = proposalsAndRequestsContract.getProposalCount ();

        proposalsAndRequestsContract.createProposal (amount, price, paymentMethodName, paymentDetailsHash, comment, username, msg.sender, sellerTransactionsCountasSeller, sellerTransactionsCountasBuyer);

        emit newProposal (proposalId);
    }


function getProposalCount() public view returns (uint256) {
    uint256 numberOfProposals = proposalsAndRequestsContract.getProposalCount();
    return numberOfProposals;
}

function deactivateProposal(uint256 proposalId) public {
    IProposalsAndRequests.Proposal memory proposal = proposalsAndRequestsContract.getProposal (proposalId);
    require(msg.sender == proposal.seller || msg.sender == owner(), "Only the seller or the owner can delete the proposal");
    proposalsAndRequestsContract.deactivateProposal(proposalId); 
    emit proposalDeactivated (proposalId);   
}
    
//Function to request to buy from the Proposals (only Buyer can do this)
function requestToBuy(uint256 proposalId, uint256 amount)
        public
        rateLimited
    {
        require(amount > 0, "Amount must be greater than 0");
        IProposalsAndRequests.Proposal memory proposal = proposalsAndRequestsContract.getProposal (proposalId);
        require(amount <= proposal.amount, "Amount must be less than or equal to the amount in the proposal");
        proposalsAndRequestsContract.requestToBuy(proposalId, amount, msg.sender);
        emit newBuyerRequest (proposalId);
    }


function getRequestCountByProposal(uint256 proposalId) public view returns (uint256) {
        uint256 numberOfRequestsForProposal =  proposalsAndRequestsContract.getRequestCountByProposal(proposalId);
        return numberOfRequestsForProposal;
    }

function deactivateBuyerRequest (uint256 proposalId, uint256 buyerRequestIndex) public {
        IProposalsAndRequests.BuyerRequest memory request = proposalsAndRequestsContract.getBuyerRequest (proposalId, buyerRequestIndex);
        require(msg.sender == request.buyer, "Only the buyer can deactivate the request");
        require(!request.accepted, "Cannot deactivate request after seller accepted");
        proposalsAndRequestsContract.deactivateBuyerRequest (proposalId, buyerRequestIndex);
        emit buyerRequestDeactivated (proposalId,buyerRequestIndex);
        }

    //Function to accept the Buyer's request to buy (only Seller can do this). Inputs: Porposal ID and Buyer's address
function acceptBuyerRequest(uint256 proposalId, uint256 buyerRequestIndex)
    public
{
    IProposalsAndRequests.BuyerRequest memory request = proposalsAndRequestsContract.getBuyerRequest (proposalId, buyerRequestIndex);
    require(!request.accepted, "Buyer's request is already accepted");
    
    IProposalsAndRequests.Proposal memory proposal = proposalsAndRequestsContract.getProposal (proposalId);
    require(msg.sender == proposal.seller || msg.sender == owner(), "Only seller can accept the buyer's request");
    uint256 amount = request.amount;
    
    //Transfer the Crypto from the Seller to the Escrow
    transferCryptoToEscrow(amount);

    //update data on request and proposal 
    proposalsAndRequestsContract.acceptBuyerRequest(proposalId, buyerRequestIndex, amount);

    emit requestAccepted (proposalId, buyerRequestIndex);
}
    
//transferCryptoToEscrow transfers the Crypto from the Seller to the Escrow
function transferCryptoToEscrow(uint256 amount) public { 
        // Ensure the sender has approved this contract
        require(USDCTokenInstance.allowance(msg.sender, address(this)) >= amount, "Contract not approved to spend USDC");
        // Transfer the amount to the contract
        USDCTokenInstance.transferFrom(msg.sender, address(this), amount);
    }


//function for the Buyer to confirm the payment (only Buyer can do this. Inputs: Proposal ID and Buyer's address. Seller must have accepted the Buyer's request to buy. This function changes paymentDeclared to true. This function can only be called once.
function confirmFiatPayment(uint256 proposalId, uint256 buyerRequestIndex)
        public
    {
        IProposalsAndRequests.BuyerRequest memory request = proposalsAndRequestsContract.getBuyerRequest (proposalId, buyerRequestIndex);
        require(msg.sender == request.buyer, "Only buyer can confirm the payment");
        require(request.accepted, "Seller has not accepted the buyer's request");
        require(!request.paymentDeclared, "Payment has already been declared");
        require(request.active = true, "Request is no longer active");
        //Set the Buyer's request to paymentDeclared
        proposalsAndRequestsContract.confirmFiatPayment(proposalId, buyerRequestIndex);
        emit paymentConfirmed(proposalId, buyerRequestIndex); 
    }


//function for Seller to confirm payment receipt and release Crypto from Escrow to Buyer (only Seller can do this). Inputs: Proposal ID and Buyer's address. Buyer must have declared the payment. This function can only be called once.
function releaseCrypto(uint256 proposalId, uint256 buyerRequestIndex)
        public
    {
        require(disputeResolutionContract.canCreateDispute(proposalId, buyerRequestIndex), "Can't release escrow balance when there is an active dispute!");
        IProposalsAndRequests.Proposal memory proposal = proposalsAndRequestsContract.getProposal (proposalId);
        require(msg.sender == proposal.seller, "Only seller can release Crypto");
        IProposalsAndRequests.BuyerRequest memory request = proposalsAndRequestsContract.getBuyerRequest (proposalId, buyerRequestIndex);

        require(request.paymentDeclared, "Buyer has not declared the payment");
        require(!request.transactionCompleted, "This transaction is already closed");
        require(proposal.escrowBalance >= request.amount, "Amount in the Escrow is less than the amount requested");


    uint256 amount = request.amount;

    // Ensure the contract has enough USDC to transfer
    require(USDCTokenInstance.balanceOf(address(this)) >= amount, "Not enough USDC");

    uint256 dexCommission = amount * commission/1000;

    //Transfer crypto to buyer
    bool success = USDCTokenInstance.transfer(request.buyer, amount - dexCommission);
    require(success, "Transfer to buyer failed.");

    //Transfer commission to the owner
    success = USDCTokenInstance.transfer(owner(), dexCommission);
    require(success, "Transfer of commission failed");

    // Record completed transaction
    completedTransactionsContract.recordCompletedTransaction(proposalId, buyerRequestIndex);

    //Record changes in Proposal and Buyer request 
    proposalsAndRequestsContract.changeProposalAndRequestDataUponCryptoRelease(proposalId, buyerRequestIndex, amount);

    emit cryptoReleased (proposalId, buyerRequestIndex);
}

function createDispute(uint256 proposalId, uint256 buyerRequestIndex)
        public
        returns (uint256)
    {
        IProposalsAndRequests.BuyerRequest memory request = proposalsAndRequestsContract.getBuyerRequest (proposalId, buyerRequestIndex);
        IProposalsAndRequests.Proposal memory proposal = proposalsAndRequestsContract.getProposal (proposalId);
        require (block.timestamp > request.date + 60, "Dispute can't be created at least for 1 hour since the request was created");
        checkProposalAndRequestActive(proposalId, buyerRequestIndex);
        bool isBuyer = checkMsgSenderRole(proposalId, buyerRequestIndex);
        if (isBuyer) {
            require(
                request.paymentDeclared,
                "Buyer has not declared the payment"
            );
        require(
                request.accepted,
                "Seller has not accepted the request");
        }
        
        proposalsAndRequestsContract.recordDisputeCreation (proposalId, buyerRequestIndex);

        uint256 disputeId = disputeResolutionContract.createDispute(
            request.buyer,
            proposal.seller,
            proposalId,
            buyerRequestIndex,
            request.amount
        );

     
        return disputeId;
    }

function releaseEscrowAfterDispute(uint256 proposalId, uint256 buyerRequestIndex, address payable winner, uint256 amount) external onlyDisputeResolutionContract {
    IProposalsAndRequests.Proposal memory proposal = proposalsAndRequestsContract.getProposal (proposalId);
    uint256 escrowedAmount = proposal.escrowBalance;
    require(escrowedAmount >= amount, "Insufficient escrow balance");
    require(USDCTokenInstance.transfer(winner, amount), "Escrow release failed");
    proposalsAndRequestsContract.recordEscrowReleaseAfterDispute (proposalId, buyerRequestIndex, amount);
}


function requestCancellation(uint256 proposalId, uint256 buyerRequestIndex) public {
    checkProposalAndRequestActive(proposalId, buyerRequestIndex);
    checkMsgSenderRole(proposalId, buyerRequestIndex);
    require(disputeResolutionContract.canCreateDispute(proposalId, buyerRequestIndex), "There is an active dispute!");
    IProposalsAndRequests.Proposal memory proposal = proposalsAndRequestsContract.getProposal (proposalId);
    IProposalsAndRequests.BuyerRequest memory request = proposalsAndRequestsContract.getBuyerRequest (proposalId, buyerRequestIndex);

    require(request.accepted, "Request is not accepted yet");
    require(proposal.seller == msg.sender || request.buyer == msg.sender, "Only buyer or seller can request cancellation");

    bool requestedByBuyer; 
    
    if (msg.sender == request.buyer) {
        requestedByBuyer = true;}  else {
        requestedByBuyer = false;}
    
    proposalsAndRequestsContract.recordRequestCancellation(proposalId, buyerRequestIndex, requestedByBuyer);
    processCancellation(proposalId, buyerRequestIndex);

    emit cancellationRequested (proposalId, buyerRequestIndex, msg.sender);
}

function processCancellation(uint256 proposalId, uint256 buyerRequestIndex) internal {
    IProposalsAndRequests.Proposal memory proposal = proposalsAndRequestsContract.getProposal (proposalId);
    IProposalsAndRequests.BuyerRequest memory request = proposalsAndRequestsContract.getBuyerRequest (proposalId, buyerRequestIndex);

    //process cancelation
    if (request.buyerRequestedtoCancel && request.sellerRequestedtoCancel) {
        // record changes in proposalsAndRequestsContract
        proposalsAndRequestsContract.processCancellation(proposalId, buyerRequestIndex);
        // Return the escrow amount to the seller
        uint256 amount = request.amount;
        USDCTokenInstance.transfer(proposal.seller, amount);
}   
}
}
