// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IDelegationEvents
/// @notice Event‑only interface so external indexers / gateways can subscribe
///         without importing full DelegationPool source.
interface IDelegationEvents {
    /*━━━━━━━━━━━━━━━━━━━━━━━━━━━━ Events ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━*/

    /// @dev Emitted when `amount` SPY is delegated → `indexer` and `shares` minted
    event Delegated(
        address indexed delegator,
        address indexed indexer,
        uint256 amount,
        uint256 shares
    );

    /// @dev Emitted when shares are queued for undelegation (unlock after delay)
    event UndelegationQueued(
        address indexed delegator,
        address indexed indexer,
        uint256 shares,
        uint256 unlockTime
    );

    /// @dev Emitted when unlocked SPY is withdrawn back to delegator
    event Withdrawn(
        address indexed delegator,
        address indexed indexer,
        uint256 amount
    );

    /// @dev Emitted when rewards are claimed by a delegator
    event RewardsClaimed(
        address indexed delegator,
        address indexed indexer,
        uint256 tokenAmount
    );
}
