// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./interfaces/iFinjaToken.sol";
import "./interfaces/iProposalsAndRequests.sol";
import "./interfaces/iMainContract.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@openzeppelin/contracts/access/Ownable.sol";


contract CompletedTransactions {
   
    struct CompletedTransaction {
        uint256 date;
        address buyer;
        address seller;
        uint256 amount;
        uint256 price;
        uint256 proposalID;
        uint256 buyerRequestIndex;
    }


    mapping (uint256 => CompletedTransaction) public completedTransactionsById;
    mapping(address => CompletedTransaction[]) public buyerCompletedTransactions;
    mapping(address => CompletedTransaction[]) public sellerCompletedTransactions;
    uint256 public completedTransactionCount;
    mapping(address => uint256) public buyerTransactionCounts;
    mapping(address => uint256) public sellerTransactionCounts;


 
    IFinjaToken public finjaTokenInstance;
    IProposalsAndRequests public proposalsAndRequestsContract;

    address public mainContract;

    event newCompletedTransaction (uint256 proposalId, uint256 buyerRequestIndex, uint256 completedTransactionCount, address indexed buyer, address indexed seller, uint256 amount, uint256 price, uint256 indexed date, uint256 finjaTokenReward);

    modifier onlyMainContract() {
        require(msg.sender == mainContract, "Caller is not the main contract");
        _;
    }


    constructor(address _finjaTokenAddress) {
        finjaTokenInstance = IFinjaToken(_finjaTokenAddress);
    }


    function setProposalsAndRequestContract (address _proposalsAndRequests) public {
        proposalsAndRequestsContract = IProposalsAndRequests(_proposalsAndRequests);
    }

    function setMainContract (address _mainContract) public {
        mainContract = _mainContract;
    }


    // function to record Completed Transacations
  
    function recordCompletedTransaction(uint256 proposalId, uint256 buyerRequestIndex) public onlyMainContract {
        IProposalsAndRequests.BuyerRequest memory request = proposalsAndRequestsContract.getBuyerRequest(proposalId, buyerRequestIndex);
        IProposalsAndRequests.Proposal memory proposal = proposalsAndRequestsContract.getProposal (proposalId);
        uint256 rewardAmount = IMainContract(mainContract).rewardAmount();
        CompletedTransaction memory completedTransaction = CompletedTransaction({
            date: block.timestamp,
            buyer: request.buyer,
            seller: proposal.seller,
            amount: request.amount,
            price: proposal.price,
            proposalID: proposalId,
            buyerRequestIndex: buyerRequestIndex
        });

        buyerCompletedTransactions[request.buyer].push(completedTransaction);
        sellerCompletedTransactions[proposal.seller].push(completedTransaction); 

        completedTransactionCount++;
        completedTransactionsById[completedTransactionCount] = completedTransaction;
    

        // Increment transaction counts for the buyer and seller
        buyerTransactionCounts[completedTransaction.buyer]++;
        sellerTransactionCounts[completedTransaction.seller]++; 

        //reward Buyer and Seller with tokens
        uint256 finjaTokenReward = rewardAmount*request.amount;
        finjaTokenInstance.mint(request.buyer, finjaTokenReward);
        finjaTokenInstance.mint(proposal.seller, finjaTokenReward); 

        emit newCompletedTransaction(proposalId, buyerRequestIndex, completedTransactionCount, request.buyer, proposal.seller, request.amount, proposal.price, block.timestamp, finjaTokenReward);
    }
   
}
