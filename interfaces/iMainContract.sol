// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

interface IMainContract {
    function releaseEscrowAfterDispute(uint256 proposalId, uint256 buyerRequestIndex, address payable winner, uint256 amount) external;
    function rewardAmount() external view returns (uint256);

}