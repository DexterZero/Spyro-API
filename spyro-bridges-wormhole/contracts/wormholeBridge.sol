// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interfaces/IWormhole.sol";
import "./interfaces/ISpyroCuration.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title WormholeBridge
/// @notice Publishes Spyro Curation signals to a target chain via Wormhole
contract WormholeBridge is Ownable {
    IWormhole public immutable wormhole;
    uint16    public immutable targetChainId;
    bytes32   public immutable targetBridgeAddress; // Wormhole emitter address on target chain

    /// @notice emitted when a curation signal is published
    event CurationSent(
        bytes32 indexed graphId,
        uint256        amount,
        uint64         sequence
    );

    /**
     * @param _wormhole              Address of the Wormhole core contract
     * @param _targetChainId         Wormhole chain ID for the target Spyro deployment
     * @param _targetBridgeAddress   32-byte emitter address of the bridge contract on target chain
     */
    constructor(
        address _wormhole,
        uint16  _targetChainId,
        bytes32 _targetBridgeAddress
    ) {
        require(_wormhole != address(0), "zero wormhole");
        wormhole = IWormhole(_wormhole);
        targetChainId = _targetChainId;
        targetBridgeAddress = _targetBridgeAddress;
    }

    /**
     * @notice Encode and publish a curation deposit event for cross-chain forwarding.
     * @dev    Only the owner (e.g. governance or a relayer role) may call this.
     * @param graphId   bytes32 ID of the AI-Graph being curated
     * @param amount    SPY amount signalled on this chain
     * @param nonce     application-specific nonce to derive VAA uniqueness
     * @return sequence Wormhole sequence number for the published message
     */
    function sendCurationSignal(
        bytes32 graphId,
        uint256 amount,
        uint32  nonce
    ) external onlyOwner returns (uint64 sequence) {
        // Payload: abi.encode(graphId, amount)
        bytes memory payload = abi.encode(graphId, amount);

        // Publish via Wormhole core
        sequence = wormhole.publishMessage(
            nonce,
            payload,
            uint8(1) // minimal consistency level
        );

        emit CurationSent(graphId, amount, sequence);
    }
}
