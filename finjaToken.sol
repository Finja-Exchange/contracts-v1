// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20FlashMint.sol";

contract FinjaToken is ERC20, ERC20Burnable, ERC20Snapshot, Ownable, Pausable, ERC20Permit, ERC20Votes, ERC20FlashMint {
    constructor() ERC20("FinjaToken", "FINJA") ERC20Permit("FinjaToken") {
        _mint(msg.sender, 10000000 * 10 ** decimals());
        lastOwnerMint = block.timestamp;
    }

    address public CompletedTransactionsContract; 
    uint256 public constant MAX_TOTAL_SUPPLY = 1 * 10**9 * 10**18; // 1 billion tokens
    uint256 public constant ANNUAL_MINT_CAP = MAX_TOTAL_SUPPLY * 2 / 100; // 2% of max supply
    uint256 public ownerMintedThisYear;
    uint256 public lastOwnerMint;

    modifier onlyCompletedTransactionsContract {
        require(msg.sender == CompletedTransactionsContract, "Only CompletedTransactions Contract can mint using this function");
        _;
    }

    function setCompletedTransactionsContract(address _CompletedTransactionsContract) public onlyOwner {
        CompletedTransactionsContract = _CompletedTransactionsContract;
    }

    function mint(address to, uint256 amount) public onlyCompletedTransactionsContract {
        require(totalSupply() + amount <= MAX_TOTAL_SUPPLY, "Max supply reached");
        _mint(to, amount);
    }

    function ownerMint(address to, uint256 amount) public onlyOwner {
        require(totalSupply() + amount <= MAX_TOTAL_SUPPLY, "Max supply reached");
        if ((lastOwnerMint + 365 days) <= block.timestamp) {
            lastOwnerMint = block.timestamp;
            ownerMintedThisYear = 0;
        }
        require(ownerMintedThisYear + amount <= ANNUAL_MINT_CAP, "Annual mint cap reached");
        ownerMintedThisYear += amount;
        _mint(to, amount);
    }

    function snapshot() public onlyOwner {
        _snapshot();
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override(ERC20, ERC20Snapshot)
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    // The following functions are overrides required by Solidity.

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, 
        ERC20Votes)
    {
        super._burn(account, amount);
    }

}
