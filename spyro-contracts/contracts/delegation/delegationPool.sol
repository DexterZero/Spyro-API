// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*───────────────────────────────────────────────────────────────────────────
│ Spyro – DelegationPool                                                     │
│                                                                           │
│ Indexers lock self‑stake in StakeManager. Delegators can bond additional   │
│ SPY to an indexer, receiving pool‑shares that track their proportional     │
│ ownership. Delegation capacity is capped at 16× self‑stake. Rewards added  │
│ by RewardsDistributor are claimable pro‑rata.                             │
└──────────────────────────────────────────────────────────────────────────*/

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../governance/SPYToken.sol";

interface IStakeManager {
    function selfStakeOf(address indexer) external view returns (uint256);
    function unbondingPeriod() external view returns (uint256);
}

interface IRewardsDistributor {
    function claimableRewards(address indexer) external view returns (uint256);
    function pullRewards(address indexer) external returns (uint256);
}

library ShareMath {
    /// @notice Calculates shares to mint for a deposit.
    function sharesForAmount(uint256 amount, uint256 pool, uint256 totalShares)
        internal
        pure
        returns (uint256 shares)
    {
        shares = (totalShares == 0) ? amount : (amount * totalShares) / pool;
    }

    /// @notice Calculates token amount for a share burn.
    function amountForShares(uint256 shares, uint256 pool, uint256 totalShares)
        internal
        pure
        returns (uint256 amount)
    {
        amount = (shares * pool) / totalShares;
    }
}

/// @title   DelegationPool
/// @notice  Delegators bond SPY to indexers and receive pool‑shares.
contract DelegationPool is ReentrancyGuard {
    using SafeERC20 for SPYToken;
    using ShareMath for uint256;

    /* ─────────────────────────────── Events ─────────────────────────────*/
    event Delegated(address indexed delegator, address indexed indexer, uint256 amount, uint256 sharesMinted);
    event Undelegated(address indexed delegator, address indexed indexer, uint256 amount, uint256 sharesBurned);
    event Withdrawn(address indexed delegator, uint256 amount);
    event RewardsClaimed(address indexed delegator, address indexed indexer, uint256 amount);

    /* ────────────────────────────── Structs ─────────────────────────────*/
    struct Pool {
        uint256 tokens;      // total delegated tokens
        uint256 shares;      // total pool‑shares
    }
    struct PendingWithdrawal {
        uint256 amount;
        uint256 unlockTime;
    }

    /* ────────────────────────────── Storage ─────────────────────────────*/
    SPYToken             public immutable token;
    IStakeManager        public immutable stakeManager;
    IRewardsDistributor  public immutable rewards;
    uint256 public constant CAPACITY_MULTIPLE = 16; // 16× self‑stake

    // indexer => pool metadata
    mapping(address => Pool) public pools;
    // delegator => indexer => shares
    mapping(address => mapping(address => uint256)) public sharesOf;
    // delegator => pending withdrawal
    mapping(address => PendingWithdrawal) public withdrawals;

    /* ───────────────────────────── Constructor ──────────────────────────*/
    constructor(address _token, address _stakeMgr, address _rewards) {
        token = SPYToken(_token);
        stakeManager = IStakeManager(_stakeMgr);
        rewards = IRewardsDistributor(_rewards);
    }

    /* ─────────────────────────── Delegation flow ────────────────────────*/
    function delegate(address indexer, uint256 amount) external nonReentrant {
        require(amount > 0, "ZERO");

        Pool storage p = pools[indexer];
        uint256 selfStake = stakeManager.selfStakeOf(indexer);
        uint256 capacity  = selfStake * CAPACITY_MULTIPLE;
        require(p.tokens + amount <= capacity, "CAPACITY");

        // mint shares
        uint256 shares = amount.sharesForAmount(p.tokens, p.shares);
        p.tokens += amount;
        p.shares += shares;
        sharesOf[msg.sender][indexer] += shares;

        token.safeTransferFrom(msg.sender, address(this), amount);
        emit Delegated(msg.sender, indexer, amount, shares);
    }

    /// @notice Request undelegation – tokens unlock after indexer unbonding period.
    function undelegate(address indexer, uint256 shares) external nonReentrant {
        uint256 userShares = sharesOf[msg.sender][indexer];
        require(shares > 0 && shares <= userShares, "SHARES");

        Pool storage p = pools[indexer];
        uint256 amountOut = ShareMath.amountForShares(shares, p.tokens, p.shares);

        // burn shares
        sharesOf[msg.sender][indexer] = userShares - shares;
        p.tokens -= amountOut;
        p.shares -= shares;

        // queue withdrawal
        PendingWithdrawal storage w = withdrawals[msg.sender];
        w.amount += amountOut;
        uint256 unlockAfter = block.timestamp + stakeManager.unbondingPeriod();
        w.unlockTime = unlockAfter > w.unlockTime ? unlockAfter : w.unlockTime;

        emit Undelegated(msg.sender, indexer, amountOut, shares);
    }

    /// @notice Finalise withdrawal once unbonding period elapses.
    function withdraw() external nonReentrant {
        PendingWithdrawal storage w = withdrawals[msg.sender];
        require(w.amount > 0 && block.timestamp >= w.unlockTime, "LOCKED");
        uint256 amt = w.amount;
        w.amount = 0;
        w.unlockTime = 0;
        token.safeTransfer(msg.sender, amt);
        emit Withdrawn(msg.sender, amt);
    }

    /* ─────────────────────────── Rewards flow ───────────────────────────*/
    function claimRewards(address indexer) external nonReentrant {
        uint256 shares = sharesOf[msg.sender][indexer];
        require(shares > 0, "NO_SHARES");

        // Pull indexer rewards into this contract (idempotent if already pulled this block)
        uint256 newRewards = rewards.pullRewards(indexer);
        if (newRewards > 0) {
            pools[indexer].tokens += newRewards; // compounding into pool balance
        }

        uint256 poolTokens = pools[indexer].tokens;
        uint256 poolShares = pools[indexer].shares;
        uint256 owed = ShareMath.amountForShares(shares, poolTokens, poolShares) -
                       ShareMath.amountForShares(shares, poolTokens - newRewards, poolShares);

        require(owed > 0, "NOTHING");
        token.safeTransfer(msg.sender, owed);
        emit RewardsClaimed(msg.sender, indexer, owed);
    }

    /* ──────────────────────────── View helpers ──────────────────────────*/
    function delegatedAmount(address delegator, address indexer) external view returns (uint256) {
        Pool storage p = pools[indexer];
        return ShareMath.amountForShares(sharesOf[delegator][indexer], p.tokens, p.shares);
    }

    function poolInfo(address indexer) external view returns (uint256 tokens, uint256 shares) {
        Pool storage p = pools[indexer];
        return (p.tokens, p.shares);
    }
}
