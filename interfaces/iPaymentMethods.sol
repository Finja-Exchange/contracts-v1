// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

interface IPaymentMethods {
    function addPaymentMethod(string memory name, string memory description, string memory region) external;
    function deactivatePaymentMethod(uint256 paymentMethodId) external;
    function reactivatePaymentMethod(uint256 paymentMethodId) external;
    function updatePaymentMethod(uint256 paymentMethodId, string memory name, string memory description, string memory region) external;
    function getPaymentMethod(uint256 paymentMethodId) external view returns (string memory, string memory, string memory, bool);
    function getPaymentMethodCount() external view returns (uint256);
}
