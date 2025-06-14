// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title ISpyroCuration
 * @notice Interface for cross-chain relayers to invoke a curation signal
 *         on the Spyro Curation contract via WormholeReceiver.
 */
interface ISpyroCuration {
    /**
     * @notice Relay a curation deposit sent from a remote chain
     * @param graphId  bytes32 identifier of the AI-Graph
     * @param amount   amount of SPY to signal into the bonding curve
     */
    function relayCurationSignal(bytes32 graphId, uint256 amount) external;
}
