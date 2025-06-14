// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/governance/SPYToken.sol";
import "../contracts/governance/SpyroTimelockController.sol";
import "../contracts/governance/SpyroGovernor.sol";
import "../contracts/staking/StakeManager.sol";
import "../contracts/delegation/DelegationPool.sol";
import "../contracts/curation/Curation.sol";
import "../contracts/staking/RewardsDistributor.sol";

contract EndToEndTest is Test {
    SPYToken token;
    SpyroGovernor gov;
    StakeManager stake;
    DelegationPool delegation;
    Curation curation;
    RewardsDistributor rewards;

    address indexer = address(0xBEEF);
    address curator = address(0xCAFE);
    address delegator = address(0xF00D);

    function setUp() public {
        // 1. Deploy token & governance bits (short-circuit timelock for test)
        token = new SPYToken();
        SpyroTimelockController tl = new SpyroTimelockController(0, new address, new address);
        gov = new SpyroGovernor(token, tl, 1, 10, 0);

        // 2. Deploy staking stack
        stake = new StakeManager(address(token), address(0), 1);
        rewards = new RewardsDistributor(address(token), address(stake));

        // 3. Deploy delegation & curation pools
        delegation = new DelegationPool(address(token), address(stake), address(rewards));
        curation = new Curation(address(token));

        // wire missing pointers
        stake.setDelegationManager(address(delegation));

        // fund actors
        token.mint(indexer, 1000 ether);
        token.mint(curator, 500 ether);
        token.mint(delegator, 800 ether);

        vm.startPrank(indexer);
        token.approve(address(stake), type(uint256).max);
        stake.stake(1000 ether);
        vm.stopPrank();
    }

    function testFullFlow() public {
        /* curator signals on fake graph id */
        bytes32 graphId = keccak256("render-v1");
        vm.prank(curator);
        token.approve(address(curation), 500 ether);
        curation.signal(graphId, 500 ether);

        /* delegator bonds */
        vm.prank(delegator);
        token.approve(address(delegation), 800 ether);
        delegation.delegate(indexer, 800 ether);

        /* push rewards & claim */
        token.mint(address(rewards), 100 ether);
        vm.prank(delegator);
        delegation.claimRewards(indexer);

        assertGt(token.balanceOf(delegator), 800 ether); // earned something

        /* keeper mints inflation */
        vm.warp(block.timestamp + 1 days + 1);
        rewards.mintInflation();
        assertGt(token.totalSupply(), 1000 ether + 500 ether + 800 ether);
    }
}
