// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../governance/SPYToken.sol";

interface IDelegationManager {
    function increaseDelegatedStake(address indexer, uint256 amount) external;
    function decreaseDelegatedStake(address indexer, uint256 amount) external;
}

/// @title   StakeManager
/// @notice  Handles indexer self-stake and withdrawal queue
contract StakeManager is ReentrancyGuard {
    using SafeERC20 for SPYToken;

    struct Stake {
        uint256 amount;
        uint256 lockedUntil;   // unix epoch seconds
    }

    /// EVENTS --------------------------------------------------------------
    event Staked(address indexed indexer, uint256 amount, uint256 newTotal);
    event UnstakeQueued(address indexed indexer, uint256 amount, uint256 unlockTime);
    event Withdrawn(address indexed indexer, uint256 amount);

    /// STATE ---------------------------------------------------------------
    SPYToken public immutable token;
    IDelegationManager public delegation;
    uint256 public immutable unbondingPeriod;          // e.g. 28 days
    mapping(address => Stake) public stakes;

    /// CONSTRUCTOR ---------------------------------------------------------
    constructor(address _token, address _delegation, uint256 _unbondingDays) {
        token = SPYToken(_token);
        delegation = IDelegationManager(_delegation);
        unbondingPeriod = _unbondingDays * 1 days;
    }

    /// EXTERNAL ------------------------------------------------------------
    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "ZERO");
        Stake storage s = stakes[msg.sender];
        s.amount += amount;
        token.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount, s.amount);

        // Notify delegation capacity increase (16× rule lives in DelegationManager)
        delegation.increaseDelegatedStake(msg.sender, amount);
    }

    /// Two-step unstake to prevent instant exit while allocated
    function queueUnstake(uint256 amount) external {
        Stake storage s = stakes[msg.sender];
        require(amount > 0 && amount <= s.amount, "INVALID");
        s.amount -= amount;
        uint256 unlock = block.timestamp + unbondingPeriod;
        s.lockedUntil = unlock > s.lockedUntil ? unlock : s.lockedUntil;
        emit UnstakeQueued(msg.sender, amount, s.lockedUntil);

        delegation.decreaseDelegatedStake(msg.sender, amount);
    }

    function withdraw() external nonReentrant {
        Stake storage s = stakes[msg.sender];
        require(s.lockedUntil != 0 && block.timestamp >= s.lockedUntil, "LOCKED");
        uint256 amt = s.amount;
        s.amount = 0;
        s.lockedUntil = 0;
        token.safeTransfer(msg.sender, amt);
        emit Withdrawn(msg.sender, amt);
    }

    /// VIEW ---------------------------------------------------------------
    function selfStakeOf(address indexer) external view returns (uint256) {
        return stakes[indexer].amount;
    }
}
