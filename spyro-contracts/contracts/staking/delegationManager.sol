// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../governance/SPYToken.sol";

/// @title DelegationManager
/// @notice Keeps delegator shares and capacity checks (16× indexer stake)
contract DelegationManager {
    using SafeERC20 for SPYToken;

    SPYToken public immutable token;
    mapping(address => uint256) public delegatedStake;           // per indexer
    mapping(address => uint256) public delegatorShares;          // delegator => shares
    uint256 public constant CAPACITY_MULTIPLE = 16;

    IStakeManager public stakeManager;

    event Delegated(address indexed delegator, address indexed indexer, uint256 amount, uint256 shares);
    event Undelegated(address indexed delegator, address indexed indexer, uint256 amount);

    constructor(address _token, address _stakeManager) {
        token = SPYToken(_token);
        stakeManager = IStakeManager(_stakeManager);
    }

    /* ------------------------------------------------------------ */
    function delegate(address indexer, uint256 amount) external {
        require(amount > 0, "ZERO");
        uint256 indexerSelfStake = stakeManager.selfStakeOf(indexer);
        uint256 capacity = indexerSelfStake * CAPACITY_MULTIPLE;
        require(delegatedStake[indexer] + amount <= capacity, "CAPACITY");

        // pool-share model:  shares = amount * totalShares / totalDelegated
        uint256 shares = _sharesForAmount(indexer, amount);
        delegatorShares[msg.sender] += shares;
        delegatedStake[indexer] += amount;

        token.safeTransferFrom(msg.sender, address(this), amount);
        emit Delegated(msg.sender, indexer, amount, shares);
    }

    function undelegate(address indexer, uint256 amount) external {
        uint256 shares = _sharesForAmount(indexer, amount);
        require(delegatorShares[msg.sender] >= shares, "INSUFFICIENT");
        delegatorShares[msg.sender] -= shares;
        delegatedStake[indexer] -= amount;

        // Respect indexer’s unbonding window: funds unlocked immediately for PoC
        token.safeTransfer(msg.sender, amount);
        emit Undelegated(msg.sender, indexer, amount);
    }

    /* ------------------------------------------------------------ */
    function _sharesForAmount(address indexer, uint256 amount) internal view returns (uint256) {
        uint256 totalDeleg = delegatedStake[indexer];
        if (totalDeleg == 0) return amount;              // first delegator
        uint256 totalShares = totalDeleg;                // 1-to-1 for simplicity
        return (amount * totalShares) / totalDeleg;
    }
}

interface IStakeManager {
    function selfStakeOf(address indexer) external view returns (uint256);
}
