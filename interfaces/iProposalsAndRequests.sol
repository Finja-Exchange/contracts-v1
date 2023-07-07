// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

interface IProposalsAndRequests {

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

function getProposal (uint256 proposalId) external view returns (Proposal memory);

function getBuyerRequest (uint256 proposalId, uint256 buyerRequestIndex) external view returns (BuyerRequest memory);

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
    ) external;

function getProposalCount() external view returns (uint256);

function deactivateProposal (uint256 proposalId) external;

function requestToBuy(uint256 proposalId, uint256 amount, address buyer) external;

function getRequestCountByProposal(uint256 proposalId) external view returns (uint256);

function deactivateBuyerRequest (uint256 proposalId, uint256 buyerRequestIndex) external;

function acceptBuyerRequest(uint256 proposalId, uint256 buyerRequestIndex, uint256 amount) external;

function confirmFiatPayment(uint256 proposalId, uint256 buyerRequestIndex) external;

function changeProposalAndRequestDataUponCryptoRelease(uint256 proposalId, uint256 buyerRequestIndex, uint256 amount) external;

function recordDisputeCreation (uint256 proposalId, uint256 buyerRequestIndex) external;

function recordEscrowReleaseAfterDispute (uint256 proposalId, uint256 buyerRequestIndex, uint256 amount) external;

function recordRequestCancellation(uint256 proposalId, uint256 buyerRequestIndex, bool requestedByBuyer) external;

function processCancellation (uint256 proposalId, uint256 buyerRequestIndex) external;

}