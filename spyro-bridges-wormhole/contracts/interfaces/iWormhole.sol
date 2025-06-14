// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IWormhole
 * @notice Minimal interface for the Wormhole core bridge contract
 *         needed by SpyroBridge and SpyroReceiver for publishing and
 *         verifying VAAs (Verifiable Action Approvals).
 */
interface IWormhole {
    /**
     * @notice Publish an arbitrary message to the Wormhole network
     * @param nonce      Application-specific nonce for uniqueness
     * @param payload    Encoded message payload
     * @param consistencyLevel 0-32: number of block confirmations required
     * @return sequence  Sequence number emitted by the core contract
     */
    function publishMessage(
        uint32 nonce,
        bytes calldata payload,
        uint8 consistencyLevel
    ) external returns (uint64 sequence);

    /**
     * @notice Parse and verify a signed VAA
     * @param encodedVAA  Wire-format VAA bytes
     * @return vm          Parsed VAA structure containing emitterChainId,
     *                     emitterAddress, payload, sequence, etc.
     */
    function parseAndVerifyVM(
        bytes calldata encodedVAA
    ) external view returns (
        
        // VM struct fields expanded
        uint32    version,
        uint32    timestamp,
        uint32    nonce,
        uint16    emitterChainId,
        bytes32   emitterAddress,
        uint64    sequence,
        uint8     consistencyLevel,
        bytes     payload
    );
}
