// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title ICuration
 * @notice Minimal interface for the Spyro Curation contract so that
 *         other protocol modules (Gateway, RewardsDistributor, governance
 *         executors, front‑ends, etc.) can interact without importing the
 *         full implementation.
 *
 * @dev    The underlying Curation contract stores bonding‑curve pools per
 *         AI‑Graph (identified by a bytes32 hash). Curators deposit SPY,
 *         receive "Curation Shares", and earn a slice of the query fees.
 */
interface ICuration {
    /*──────────────────────────────────────────────────────────*
     *  External (state‑changing)                             *
     *──────────────────────────────────────────────────────────*/

    /**
     * @notice Deposit `amount` of SPY on an AI‑Graph bonding curve and
     *         mint curation shares to the caller.
     * @param  graphID   The bytes32 ID of the AI‑Graph (hash of aigraph.yaml).
     * @param  amount    Amount of SPY to deposit (before the 2.5 % tax).
     * @return sharesOut Amount of curation shares minted for the curator.
     */
    function signal(bytes32 graphID, uint256 amount) external returns (uint256 sharesOut);

    /**
     * @notice Burn `sharesIn` curation shares and withdraw the proportional
     *         amount of SPY from the bonding curve.
     * @param  graphID   The bytes32 ID of the AI‑Graph.
     * @param  sharesIn  Number of shares the curator wants to burn.
     * @return tokensOut SPY returned to the curator.
     */
    function unsignal(bytes32 graphID, uint256 sharesIn) external returns (uint256 tokensOut);

    /**
     * @notice Governance‑only: migrate curator stake from an old AI‑Graph
     *         version to a new one, applying a 1 % migration tax.
     */
    function migrateVersion(bytes32 oldID, bytes32 newID, uint256 sharesToMigrate) external;

    /*──────────────────────────────────────────────────────────*
     *  View helpers                                           *
     *──────────────────────────────────────────────────────────*/

    /**
     * @return Price of one curation share for `graphID`, scaled by 1e18.
     */
    function pricePerShare(bytes32 graphID) external view returns (uint256);

    /**
     * @return The amount of shares held by `curator` for `graphID`.
     */
    function sharesOf(bytes32 graphID, address curator) external view returns (uint256);

    /**
     * @dev    Curve storage getter: returns the current SPY pool balance and
     *         total shares outstanding for `graphID`.
     */
    function curves(bytes32 graphID) external view returns (uint256 tokens, uint256 shares);

    /*──────────────────────────────────────────────────────────*
     *  Constant getters                                       *
     *──────────────────────────────────────────────────────────*/

    function CURATION_TAX_BPS() external view returns (uint256);
    function MIGRATION_TAX_BPS() external view returns (uint256);
}
