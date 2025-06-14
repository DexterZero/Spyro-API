// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title Spyro Invariant Fuzz Tests
 * @dev   Uses Foundry's invariant test runner (`forge test --match-contract InvariantTest -vvvv`)
 *        to assert cross‑module properties across random sequences of user
 *        actions. The fuzzer repeatedly calls the public mutators below in
 *        random order with random params, while the `invariant_` functions
 *        must always hold true.
 */

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";

import "contracts/governance/SPYToken.sol";
import "contracts/staking/StakeManager.sol";
import "contracts/delegation/DelegationPool.sol";
import "contracts/staking/RewardsDistributor.sol";

contract InvariantTest is Test, StdInvariant {
    /* ───── Deployed system ─────────────────────────────────────────── */
    SPYToken            token;
    StakeManager        stake;
    DelegationPool      delegation;
    RewardsDistributor  rewards;

    address constant INDEXER_A = address(0xA11A);
    address constant INDEXER_B = address(0xB11B);
    address constant ALICE     = address(0xA71ce);
    address constant BOB       = address(0xB0b);

    /* ───── State counters for fuzz sanity ─────────────────────────── */
    uint256 public totalDelegated;

    /* ───── Setup ──────────────────────────────────────────────────── */
    function setUp() public {
        token   = new SPYToken();
        stake   = new StakeManager(address(token), address(0), 1 days);
        rewards = new RewardsDistributor(address(token), address(stake));
        delegation = new DelegationPool(address(token), address(stake), address(rewards));
        stake.setDelegationManager(address(delegation));

        // mint tokens
        token.mint(INDEXER_A, 10_000 ether);
        token.mint(INDEXER_B, 10_000 ether);
        token.mint(ALICE,     20_000 ether);
        token.mint(BOB,       20_000 ether);

        // approve once for all fuzz calls
        vm.prank(INDEXER_A); token.approve(address(stake), type(uint256).max);
        vm.prank(INDEXER_B); token.approve(address(stake), type(uint256).max);
        vm.prank(ALICE);     token.approve(address(delegation), type(uint256).max);
        vm.prank(BOB);       token.approve(address(delegation), type(uint256).max);

        // register contracts with invariant harness
        targetContract(address(stake));
        targetContract(address(delegation));
    }

    /* ───── Fuzz entry‑points ──────────────────────────────────────── */
    function stakeIndexer(uint256 amt, bool chooseB) public {
        address idx = chooseB ? INDEXER_B : INDEXER_A;
        amt = bound(amt, 1 ether, 1_000 ether);
        vm.prank(idx);
        stake.stake(amt);
    }

    function delegateToIndexer(uint256 amt, bool chooseB, bool alice) public {
        address idx   = chooseB ? INDEXER_B : INDEXER_A;
        address dlg   = alice ? ALICE : BOB;
        amt = bound(amt, 1 ether, 500 ether);
        vm.prank(dlg);
        delegation.delegate(idx, amt);
        totalDelegated += amt;
    }

    /* ───── Invariants ─────────────────────────────────────────────── */

    /// @dev Delegation capacity: delegated ≤ 16 × self‑stake for each indexer
    function invariant_capacityRatio() public view {
        _checkCapacity(INDEXER_A);
        _checkCapacity(INDEXER_B);
    }

    function _checkCapacity(address idx) internal view {
        uint256 selfStake = stake.selfStakeOf(idx);
        uint256 cap       = selfStake * delegation.CAPACITY_MULTIPLE();
        uint256 deleg     = delegation.delegatedStake(idx);
        assertLe(deleg, cap, "capacity exceeded");
    }

    /// @dev Delegator shares should always equal totalDelegatedSPY
    function invariant_shareAccounting() public view {
        address[2] memory idxs = [INDEXER_A, INDEXER_B];
        uint256 totalPoolBal;
        uint256 totalShares;
        for (uint8 i = 0; i < idxs.length; i++) {
            totalPoolBal += delegation.delegatedStake(idxs[i]);
            totalShares  += delegation.totalShares(idxs[i]);
        }
        // initial pool shares start 1:1 with amount so these should match
        assertEq(totalPoolBal, totalShares, "share mismatch");
