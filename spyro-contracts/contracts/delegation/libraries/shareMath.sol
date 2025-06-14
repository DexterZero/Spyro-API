// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ShareMath
/// @notice Helper library to convert between token amounts and pool‑shares in
///         Spyro DelegationPool (and potentially Curation).
///
/// The implementation uses 18‑dec fixed‑point math and mirrors Balancer’s
/// proportional‑ownership pattern:
///   amount  = shares  * poolBalance / totalShares
///   shares  = amount  * totalShares / poolBalance
///
/// If the pool is being initialised (totalShares == 0) it mints shares equal
/// to the deposit so the first delegator owns 100 %.
///
/// All functions are pure and gas‑cheap (no SafeMath needed in 0.8.x).
library ShareMath {
    /* @dev Convert deposit amount → shares to mint. */
    function amountToShares(
        uint256 amount,
        uint256 poolBalance,
        uint256 totalShares
    ) internal pure returns (uint256 shares) {
        if (totalShares == 0 || poolBalance == 0) {
            // First delegator gets 1:1 shares
            return amount;
        }
        shares = (amount * totalShares) / poolBalance;
    }

    /* @dev Convert shares burned → token amount returned. */
    function sharesToAmount(
        uint256 shares,
        uint256 poolBalance,
        uint256 totalShares
    ) internal pure returns (uint256 amount) {
        amount = (shares * poolBalance) / totalShares;
    }

    /* @dev Price per share with 18‑decimal precision (1e18 = 1 SPY).
     *      Returns 1e18 for empty pools so UI can show a sane default. */
    function pricePerShare(
        uint256 poolBalance,
        uint256 totalShares
    ) internal pure returns (uint256) {
        return totalShares == 0 ? 1e18 : (poolBalance * 1e18) / totalShares;
    }
}
