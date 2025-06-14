// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "contracts/delegation/interfaces/IDelegationEvents.sol";

/// @title IDelegationPool
/// @notice Functional interface for the Spyro Delegation Pool contract.
///         Allows external modules (gateway, indexer CLI, rewards
///         distributor, UI) to interact without pulling the full
///         implementation.
interface IDelegationPool is IDelegationEvents {
    /* ─────────────────────────────── Constants ───────────────────────────── */

    /// @notice Maximum delegated stake as a multiple of indexer self‑stake.
    function CAPACITY_MULTIPLE() external view returns (uint256);

    /// @notice Unbonding period (seconds) applied to undelegations.
    function UNBONDING_PERIOD() external view returns (uint256);

    /* ────────────────────────────── Write APIs ───────────────────────────── */

    /// @dev Delegate `amount` SPY to `indexer`, receiving pool‑shares.
    /// @param indexer  Address of the indexer you are delegating to.
    /// @param amount   Amount of SPY to delegate (wei).
    /// @return shares  Pool‑shares minted to the caller.
    function delegate(address indexer, uint256 amount) external returns (uint256 shares);

    /// @dev Queue an undelegation that will be claimable after the unbonding
    ///      period. Shares are burned immediately; SPY is locked.
    /// @param indexer  Indexer you previously delegated to.
    /// @param shares   Amount of shares to burn.
    function queueUndelegate(address indexer, uint256 shares) external;

    /// @dev Finalise a previously queued undelegation and withdraw SPY.
    /// @param indexer  Indexer you originally delegated to.
    /// @return amount  SPY transferred back to the caller.
    function claimUndelegated(address indexer) external returns (uint256 amount);

    /// @dev Claim accumulated query‑fee & inflation rewards for the caller.
    /// @param indexer  Indexer whose pool you are claiming from.
    /// @return amount  Reward SPY transferred.
    function claimRewards(address indexer) external returns (uint256 amount);

    /* ─────────────────────────────── Views ──────────────────────────────── */

    /// @notice Return the share balance of `delegator` in `indexer` pool.
    function sharesOf(address indexer, address delegator) external view returns (uint256);

    /// @notice Total delegated stake (in SPY) backing `indexer`.
    function delegatedStake(address indexer) external view returns (uint256);

    /// @notice Convert a SPY amount to pool‑shares at current ratio.
    function sharesForAmount(address indexer, uint256 amount) external view returns (uint256);

    /// @notice Convert pool‑shares to the underlying SPY amount at current ratio.
    function amountForShares(address indexer, uint256 shares) external view returns (uint256);
}
