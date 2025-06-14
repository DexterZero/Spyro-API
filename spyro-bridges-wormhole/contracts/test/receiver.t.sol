// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "contracts/WormholeReceiver.sol";
import "contracts/interfaces/IWormhole.sol";
import "contracts/interfaces/ISpyroCuration.sol";

/// @dev Mock Wormhole core implementing only parseAndVerifyVM
contract MockWormholeCore is IWormhole {
    IWormhole.VM private vmData;
    bool          private isValid;
    string        private errMsg;

    constructor(
        IWormhole.VM memory _vmData,
        bool              _isValid,
        string memory     _errMsg
    ) {
        vmData = _vmData;
        isValid = _isValid;
        errMsg = _errMsg;
    }

    // We don't use publishMessage here
    function publishMessage(
        uint32,
        bytes calldata,
        uint8
    ) external pure returns (uint64) {
        revert("not implemented");
    }

    function parseAndVerifyVM(
        bytes calldata
    ) external view returns (
        IWormhole.VM memory vm,
        bool valid,
        string memory reason
    ) {
        return (vmData, isValid, errMsg);
    }
}

/// @dev Mock SpyroCuration that records relayed signals
contract MockCuration is ISpyroCuration {
    bytes32 public lastGraphId;
    uint256 public lastAmount;

    function relayCurationSignal(
        bytes32 graphId,
        uint256 amount
    ) external override {
        lastGraphId = graphId;
        lastAmount = amount;
    }
}

contract WormholeReceiverTest is Test {
    /// @notice VM helper to construct a minimal VM struct
    function makeVM(
        uint16 emitterChain,
        bytes32 emitterAddr,
        uint64 seq,
        uint8  consistency,
        bytes memory payload
    ) internal pure returns (IWormhole.VM memory) {
        return IWormhole.VM({
            emitterChainId:   emitterChain,
            emitterAddress:   emitterAddr,
            sequence:         seq,
            consistencyLevel: consistency,
            payload:          payload
        });
    }

    function testReceiveVAARevertsWhenInvalid() public {
        // Prepare an invalid VM
        IWormhole.VM memory vm = makeVM(
            1,
            bytes32(uint256(0x1234)),
            1,
            1,
            abi.encode(bytes32("g"), uint256(10))
        );
        MockWormholeCore core = new MockWormholeCore(vm, false, "bad VAA");
        MockCuration cur = new MockCuration();
        WormholeReceiver receiver = new WormholeReceiver(
            address(core), 1, bytes32(uint256(0x1234)), address(cur)
        );

        vm.expectRevert(bytes("bad VAA"));
        receiver.receiveAndExecuteVAA(hex"deadbeef");
    }

    function testReceiveVAAForwardsPayloadToCuration() public {
        // Payload with graphId and amount
        bytes32 graphId = bytes32("graph-01");
        uint256 amount = 12345;
        bytes memory payload = abi.encode(graphId, amount);

        IWormhole.VM memory vm = makeVM(
            2,
            bytes32(uint256(0x5678)),
            42,
            1,
            payload
        );
        // Valid VM from expected emitter chain & address
        MockWormholeCore core = new MockWormholeCore(vm, true, "");
        MockCuration cur = new MockCuration();
        WormholeReceiver receiver = new WormholeReceiver(
            address(core),
            2,
            bytes32(uint256(0x5678)),
            address(cur)
        );

        // Call receiver with dummy VAA bytes
        receiver.receiveAndExecuteVAA(hex"cafebabe
