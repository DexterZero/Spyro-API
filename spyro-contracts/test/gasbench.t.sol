// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title GasBenchTest
 * @notice Quick gas‑usage snapshots for the hottest user flows: delegate,
 *         signal, and query‑fee claim. Run with `forge test --match-contract
 *         GasBenchTest --gas-report` to get a CSV‑style report.
 */

import "forge-std/Test.sol";
import "contracts/governance/SPYToken.sol";
import "contracts/staking/StakeManager.sol";
import "contracts/delegation/DelegationPool.sol";
import "contracts/curation/Curation.sol";
import "contracts/staking/RewardsDistributor.sol";

contract GasBenchTest is Test {
    SPYToken token;
    StakeManager stake;
    RewardsDistributor rewards;
    DelegationPool delegation;
    Curation curation;

    address indexer   = address(0xBEEF);
    address delegator = address(0xDEAD);
    address curator   = address(0xCAFE);

    function setUp() public {
        token = new SPYToken();
        stake = new StakeManager(address(token), address(0), 1);
        rewards = new RewardsDistributor(address(token), address(stake));
        delegation = new DelegationPool(address(token), address(stake), address(rewards));
        curation = new Curation(address(token));
        stake.setDelegationManager(address(delegation));

        // fund actors
        token.mint(indexer,   1_000 ether);
        token.mint(delegator,   800 ether);
        token.mint(curator,     500 ether);

        // indexer self‑stakes once up‑front (not included in gas bench)
        vm.startPrank(indexer);
        token.approve(address(stake), type(uint256).max);
        stake.stake(1_000 ether);
        vm.stopPrank();
    }

    /* ───────────────────────────────────────────────────────────── */
    /* Gas snapshots                                                 */
    /* Run forge with --gas-report to aggregate across test cases.    */
    /* ───────────────────────────────────────────────────────────── */

    function testGas_delegate() public {
        vm.startPrank(delegator);
        token.approve(address(delegation), 800 ether);
        delegation.delegate(indexer, 800 ether);
        vm.stopPrank();
    }

    function testGas_signal() public {
        bytes32 graphId = keccak256("render-v1");
        vm.startPrank(curator);
        token.approve(address(curation), 500 ether);
        curation.signal(graphId, 500 ether);
        vm.stopPrank();
    }

    function testGas_claimRewards() public {
        // Pre‑setup: delegator already delegated in previous test, push rewards
        testGas_delegate();
        token.mint(address(rewards), 100 ether);

        vm.startPrank(delegator);
        delegation.claimRewards(indexer);
        vm.stopPrank();
    }
}
