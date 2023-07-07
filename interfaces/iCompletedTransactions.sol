// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

interface ICompletedTransactions {
    function recordCompletedTransaction(uint256 proposalId, uint256 buyerRequestIndex) external;
    function buyerTransactionCounts (address buyeraddress) external view returns (uint256);
    function sellerTransactionCounts (address selleraddress) external view returns (uint256);
}