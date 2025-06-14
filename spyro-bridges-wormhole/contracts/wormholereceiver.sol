// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IWormhole.sol";
import "./interfaces/ISpyroCuration.sol";
import "./libraries/BytesLib.sol";

/**
 * @title WormholeReceiver
 * @notice Verifies and executes Wormhole VAAs sent from Chain A, decodes the
 *         curation signal payload, and forwards it to the Spyro Curation contract
 *         on this chain.
 */
contract WormholeReceiver is Ownable {
    IWormhole public immutable wormhole;
    uint16    public immutable expectedChainId;
    bytes32   public immutable expectedEmitter;
    address   public immutable curationContract;

    /// @notice emitted when a VAA is successfully processed
    event CurationReceived(
        bytes32 indexed graphId,
        uint256        amount,
        uint64         sequence
    );

    /**
     * @param _wormhole          Address of the Wormhole core contract
     * @param _expectedChainId   Wormhole chain ID of the source bridge
     * @param _expectedEmitter   Emitter address of the bridge contract on source chain
     * @param _curationContract  Address of the Spyro Curation contract to relay to
     */
    constructor(
        address _wormhole,
        uint16  _expectedChainId,
        bytes32 _expectedEmitter,
        address _curationContract
    ) {
        require(_wormhole != address(0), "zero wormhole");
        require(_curationContract != address(0), "zero curation");
        wormhole = IWormhole(_wormhole);
        expectedChainId = _expectedChainId;
        expectedEmitter = _expectedEmitter;
        curationContract = _curationContract;
    }

    /**
     * @notice Entrypoint for relayer to submit a signed VAA (byte array)
     * @param encodedVAA  Wormhole VAA bytes produced by the core bridge
     */
    function receiveCuration(bytes memory encodedVAA) external onlyOwner {
        // Verify and parse the VAA
        (IWormhole.VM memory vm, bool valid, string memory reason) = wormhole.parseAndVerifyVM(encodedVAA);
        require(valid, reason);

        // Ensure correct emitter and chain
        require(vm.emitterChainId == expectedChainId, "invalid source chain");
        require(vm.emitterAddress == expectedEmitter, "invalid emitter");

        // Decode payload: (bytes32 graphId, uint256 amount)
        bytes memory payload = vm.payload;
        (bytes32 graphId, uint256 amount) = abi.decode(payload, (bytes32, uint256));

        // Forward to Spyro Curation
        ISpyroCuration(curationContract).relayCurationSignal(graphId, amount);

        emit CurationReceived(graphId, amount, vm.sequence);
    }
}
