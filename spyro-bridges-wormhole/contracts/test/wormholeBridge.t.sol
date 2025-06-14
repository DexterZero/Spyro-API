// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "contracts/interfaces/IWormhole.sol";
import "contracts/WormholeBridge.sol";

/// @dev Mock Wormhole core implementing IWormhole
contract MockWormhole is IWormhole {
    uint64 public nextSequence = 1;
    uint32 public lastNonce;
    bytes  public lastPayload;
    uint8  public lastConsistency;

    function publishMessage(
        uint32 nonce,
        bytes calldata payload,
        uint8 consistencyLevel
    ) external override returns (uint64 sequence) {
        lastNonce = nonce;
        lastPayload = payload;
        lastConsistency = consistencyLevel;
        sequence = nextSequence++;
    }

    struct VM { uint16 emitterChainId; bytes32 emitterAddress; uint64 sequence; uint8 consistencyLevel; bytes payload; }
    function parseAndVerifyVM(bytes calldata) external pure override returns (VM memory, bool, string memory) {
        revert("not used");
    }
}

contract WormholeBridgeTest is Test {
    MockWormhole      wormhole;
    WormholeBridge    bridge;
    address           owner = address(this);
    bytes32 constant  GRAPH_ID = keccak256("test-graph");
    uint16 constant   TARGET_CHAIN = 100;
    bytes32 constant  TARGET_BRIDGE = bytes32(uint256(0x1234));

    function setUp() public {
        wormhole = new MockWormhole();
        bridge = new WormholeBridge(
            address(wormhole),
            TARGET_CHAIN,
            TARGET_BRIDGE
        );
        // ownership is msg.sender
    }

    /// @notice Happy path: owner can send curation signal
    function test_sendCurationSignal_emitsEvent_andPublishesToWormhole() public {
        uint256 amount = 500;
        uint32  nonce  = 42;

        // Expect event
        vm.expectEmit(true, false, false, true);
        emit bridge.CurationSent(GRAPH_ID, amount, 1);

        uint64 seq = bridge.sendCurationSignal(GRAPH_ID, amount, nonce);
        assertEq(seq, 1);

        // MockWormhole recorded payload and params
        (bytes32 gId, uint256 a) = abi.decode(wormhole.lastPayload, (bytes32, uint256));
        assertEq(gId, GRAPH_ID, "payload graphId mismatch");
        assertEq(a, amount, "payload amount mismatch");

        assertEq(wormhole.lastNonce, nonce, "nonce mismatch");
        assertEq(wormhole.lastConsistency, 1, "consistency mismatch");
    }

    /// @notice Only owner can call
    function test_sendCurationSignal_onlyOwner() public {
        address attacker = address(0xBAD);
        vm.prank(attacker);
        vm.expectRevert("Ownable: caller is not the owner");
        bridge.sendCurationSignal(GRAPH_ID, 1, 0);
    }
}
