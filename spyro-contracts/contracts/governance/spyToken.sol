// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title SPY Token – Governance & Staking token for Spyro
/// @notice ERC20 + ERC20Permit + ERC20Votes implementation
contract SPYToken is ERC20Votes, Ownable {
    /// @dev 1 billion max supply (1e9 * 1e18)
    uint256 public constant MAX_SUPPLY = 1_000_000_000 ether;

    constructor()
        ERC20("Spyro Token", "SPY")
        ERC20Permit("Spyro Token")
    {
        // Initial testnet mint to deployer for boot-strapping
        _mint(msg.sender, 10_000_000 ether);
    }

    /// @notice Mint new SPY (governance-controlled on mainnet)
    function mint(address to, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= MAX_SUPPLY, "SPY: cap exceeded");
        _mint(to, amount);
    }

    // ——— Overrides required by Solidity ———
    function _update(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._update(from, to, amount);
    }
}
