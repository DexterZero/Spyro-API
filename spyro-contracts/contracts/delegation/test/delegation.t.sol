// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "contracts/governance/SPYToken.sol";
import "contracts/delegation/DelegationPool.sol";
import "contracts/delegation/libraries/ShareMath.sol";

/// @dev Minimal mock StakeManager exposing only selfStakeOf()
contract MockStakeManager {
    mapping(address => uint256) public selfStake;
    function selfStakeOf(address idx) external view returns (uint256) {
        return selfStake[idx];
    }
    function setStake(address idx, uint256 amt) external {
        selfStake[idx] = amt;
    }
}

/// @dev Minimal mock RewardsDistributor which just sends tokens to pool
contract MockRewardsDistributor {
    SPYToken public token;
    constructor(address _token) { token = SPYToken(_token); }
    function drip(address pool, uint256 amt) external {
        token.mint(pool, amt);
    }
}

contract DelegationTest is Test {
    using stdStorage for StdStorage;

    SPYToken token;
    MockStakeManager stakeMgr;
    MockRewardsDistributor rewards;
    DelegationPool pool;

    address indexer = address(0xBEEF);
    address alice   = address(0xA11CE);
    address bob     = address(0xB0B);

    uint256 constant UNBOND_DAYS = 28;

    function setUp() public {
        token = new SPYToken();
        stakeMgr = new MockStakeManager();
        rewards  = new MockRewardsDistributor(address(token));
        pool     = new DelegationPool(address(token), address(stakeMgr), address(rewards));

        // Mint tokens to actors
        token.mint(indexer, 1_000 ether);
        token.mint(alice,   1_000 ether);
        token.mint(bob,     1_000 ether);

        // Approvals
        vm.prank(indexer); token.approve(address(pool), type(uint256).max);
        vm.prank(alice);   token.approve(address(pool), type(uint256).max);
        vm.prank(bob);     token.approve(address(pool), type(uint256).max);

        // Indexer self‑stakes 1000 SPY in StakeManager mock
        stakeMgr.setStake(indexer, 1_000 ether);
    }

    /*──────────────────────────────────────────────────────────────────
        testDelegateHappyPath
    ──────────────────────────────────────────────────────────────────*/
    function testDelegateHappyPath() public {
        // Alice delegates 100 SPY
        vm.startPrank(alice);
        pool.delegate(indexer, 100 ether);
        vm.stopPrank();

        // Pool should reflect delegated stake
        uint256 d = pool.delegatedStake(indexer);
        assertEq(d, 100 ether, "delegated stake mismatch");

        // Shares equal amount on first deposit (poolBalance==0 prior)
        uint256 sharesAlice = pool.delegatorShares(indexer, alice);
        assertEq(sharesAlice, 100 ether, "share calc error");

        // Capacity still far from limit (16× self‑stake = 16k)
        assertLt(d, 16_000 ether);
    }

    /*──────────────────────────────────────────────────────────────────
        testCapacityRevert
    ──────────────────────────────────────────────────────────────────*/
    function testCapacityRevert() public {
        // Delegator tries to exceed 16× cap
        stakeMgr.setStake(indexer, 1 ether); // small stake
        vm.startPrank(alice);
        vm.expectRevert(bytes("CAPACITY"));
        pool.delegate(indexer, 20 ether); // would exceed 16×
    }

    /*──────────────────────────────────────────────────────────────────
        testQueueAndClaimUndelegate
    ──────────────────────────────────────────────────────────────────*/
    function testQueueAndClaimUndelegate() public {
        // Alice delegates 200
        vm.startPrank(alice);
        pool.delegate(indexer, 200 ether);
        uint256 shares = pool.delegatorShares(indexer, alice);

        // Queue undelegation of all shares
        pool.queueUndelegate(indexer, shares);
        (, uint256 unlock) = pool.pendingUnbond(indexer, alice);
        assertGt(unlock, block.timestamp, "unlock not set");

        // Warp past unbonding period and claim
        vm.warp(block.timestamp + UNBOND_DAYS * 1 days + 1);
        pool.claimUndelegated(indexer);
        vm.stopPrank();

        // Alice should have full 200 back (no reward logic here)
        assertEq(token.balanceOf(alice), 1_000 ether);

        // Delegated stake for indexer should be zero
        assertEq(pool.delegatedStake(indexer), 0);
    }

    /*──────────────────────────────────────────────────────────────────
        testClaimRewards
    ──────────────────────────────────────────────────────────────────*/
    function testClaimRewards() public {
        // Alice delegates 100
        vm.prank(alice); pool.delegate(indexer, 100 ether);
        // drip 10 reward tokens into pool
        rewards.drip(address(pool), 10 ether);

        // Alice claims rewards
        vm.prank(alice); pool.claimRewards(indexer);
        // Expect ~10 reward (only delegator)
        assertEq(token.balanceOf(alice), 1_000 ether - 100 ether + 10 ether);
    }
}
