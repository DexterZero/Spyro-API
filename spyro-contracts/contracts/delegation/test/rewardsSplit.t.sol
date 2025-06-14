// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "contracts/governance/SPYToken.sol";
import "contracts/delegation/DelegationPool.sol";

/**
 * @title RewardsSplitTest
 * @notice Ensures that DelegationPool.claimRewards() distributes
 *         query‑fee / inflation rewards proportionally to delegator shares.
 */
contract RewardsSplitTest is Test {
    SPYToken token;
    DelegationPool pool;

    address indexer = address(0xBEEF);
    address alice   = address(0xA11CE);
    address bob     = address(0xB0B);

    /* Mock simple distributor that just sends tokens to pool */
    contract MockDistributor {
        SPYToken tk;
        constructor(address _tk) { tk = SPYToken(_tk); }
        function pushRewards(address to, uint256 amt) external {
            tk.transfer(to, amt);
        }
    }
    MockDistributor dist;

    /* Mock stake manager returning fixed self‑stake of 1m SPY */
    contract MockStake {
        uint256 constant ONE_M = 1_000_000 ether;
        function selfStakeOf(address) external pure returns (uint256) {
            return ONE_M;
        }
    }
    MockStake stake;

    function setUp() public {
        token = new SPYToken();
        stake = new MockStake();
        dist  = new MockDistributor(address(token));

        pool  = new DelegationPool(address(token), address(stake), address(dist));
        pool.transferOwnership(address(this));

        // Seed test accounts
        token.mint(alice, 1_000 ether);
        token.mint(bob,   2_000 ether);

        vm.startPrank(alice);
        token.approve(address(pool), 1_000 ether);
        pool.delegate(indexer, 1_000 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        token.approve(address(pool), 2_000 ether);
        pool.delegate(indexer, 2_000 ether);
        vm.stopPrank();
    }

    function testRewardsSplitProRata() public {
        // total delegated = 3k, alice has 1/3 shares, bob 2/3
        uint256 reward = 300 ether;
        token.mint(address(dist), reward);
        dist.pushRewards(address(pool), reward);

        // claim
        vm.prank(alice);
        pool.claimRewards(indexer);
        vm.prank(bob);
        pool.claimRewards(indexer);

        // Alice should get 100, Bob 200
        assertEq(token.balanceOf(alice), 100 ether, "Alice reward incorrect");
        assertEq(token.balanceOf(bob),   200 ether, "Bob reward incorrect");
        assertEq(token.balanceOf(address(pool)), 0, "Pool should be empty");
    }
}
