// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

interface IFinjaToken {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external;
    function mint(address to, uint256 amount) external;
}