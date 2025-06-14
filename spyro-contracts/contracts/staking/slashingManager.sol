// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./StakeManager.sol";

/// @notice Handles disputes and stake slashes (≈2.5 %)
contract SlashingManager is Pausable, Ownable {
    uint256 public constant SLASH_PERCENT = 250; // 2.5% = 250 basis pts (10 000 bps = 100 %)
    uint256 public constant CHALLENGE_WINDOW = 2 days;

    struct Challenge {
        address challenger;
        address indexer;
        uint256 stakeAtRisk;
        uint256 timestamp;
        bytes   evidenceURI;  // off-chain IPFS hash to POI mismatch, etc.
        bool    resolved;
    }

    mapping(bytes32 => Challenge) public challenges;
    StakeManager public immutable stakeManager;

    event ChallengeOpened(bytes32 id, address indexed challenger, address indexed indexer, uint256 stake);
    event ChallengeResolved(bytes32 id, bool slashed);

    constructor(address _stakeMgr) {
        stakeManager = StakeManager(_stakeMgr);
    }

    function openChallenge(address indexer, bytes calldata evidenceURI) external whenNotPaused returns (bytes32 id) {
        uint256 stake = stakeManager.selfStakeOf(indexer);
        require(stake > 0, "NO_STAKE");
        id = keccak256(abi.encode(indexer, msg.sender, evidenceURI, block.timestamp));
        challenges[id] = Challenge(msg.sender, indexer, stake, block.timestamp, evidenceURI, false);
        emit ChallengeOpened(id, msg.sender, indexer, stake);
    }

    /// Governor-appointed arbitrator calls this
    function slash(bytes32 id, bool valid) external onlyOwner {
        Challenge storage c = challenges[id];
        require(!c.resolved, "DONE");
        require(block.timestamp <= c.timestamp + CHALLENGE_WINDOW, "TOO_LATE");
        c.resolved = true;
        if (valid) {
            uint256 penalty = (c.stakeAtRisk * SLASH_PERCENT) / 10_000;
            stakeManager.forceSlash(c.indexer, penalty, c.challenger);
        }
        emit ChallengeResolved(id, valid);
    }
}
