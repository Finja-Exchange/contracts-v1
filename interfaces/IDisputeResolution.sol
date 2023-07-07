// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

interface IDisputeResolution {
    function canCreateDispute(uint256 proposalID, uint256 buyerRequestIndex) external view returns (bool);
    function createDispute(address buyer, address seller, uint256 proposalId, uint256 buyerRequest, uint256 disputedAmount) external returns (uint256);
}