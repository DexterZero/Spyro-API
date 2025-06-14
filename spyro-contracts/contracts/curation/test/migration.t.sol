// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "contracts/governance/SPYToken.sol";
import "contracts/curation/Curation.sol";

/// @title MigrationTest
/// @notice Verifies curator‑share auto‑migration between two AI‑Graph
///         versions, including the 1 % migration tax burn and correct
///         updates to bonding‑curve pools.
contract MigrationTest is Test {
    /* ------------------------------------------------------------------ */
    /* Constants / Helpers                                                */
    /* ------------------------------------------------------------------ */
    bytes32 constant OLD_ID = bytes32(uint256(0xBEEF));
    bytes32 constant NEW_ID = bytes32(uint256(0xCAFE));

    address owner   = address(this);
    address curator = vm.addr(1);

    SPYToken token;
    Curation curation;

    /* ------------------------------------------------------------------ */
    /* Set‑up                                                             */
    /* ------------------------------------------------------------------ */
    function setUp() public {
        token    = new SPYToken();               // deploy fresh ERC20Votes
        curation = new Curation(address(token));

        // Mint curator 1 000 000 SPY for testing
        token.mint(curator, 1_000_000 ether);

        // Give contract ownership to this test contract
        curation.transferOwnership(owner);
    }

    /* ------------------------------------------------------------------ */
    /* testMigration                                                      */
    /* ------------------------------------------------------------------ */
    function testMigration() public {
        uint256 initialCuratorBal = token.balanceOf(curator);

        // Curator approves & signals 100 000 SPY to OLD graph
        vm.startPrank(curator);
        token.approve(address(curation), type(uint256).max);
        uint256 sharesMinted = curation.signal(OLD_ID, 100_000 ether);
        vm.stopPrank();

        // Check 2.5 % tax burn
        uint256 expectedBurn = (100_000 ether * 250) / 10_000; // 2.5 %
        assertEq(token.balanceOf(address(0xdead)), expectedBurn, "burn mismatch");

        // Owner migrates 50 % of curator shares to NEW graph
        uint256 migrateShares = sharesMinted / 2;
        curation.migrateVersion(OLD_ID, NEW_ID, migrateShares);

        // After migration: OLD curve tokens reduced, NEW curve increased
        (uint256 oldPool,,) = _curveData(OLD_ID);
        (uint256 newPool,,) = _curveData(NEW_ID);

        // 1 % migration tax burn taken from tokensOut
        uint256 tokensOut = (migrateShares * oldPool) / (sharesMinted);
        uint256 expectedMigrationBurn = (tokensOut * 100) / 10_000;
        assertEq(token.balanceOf(address(0xdead)) - expectedBurn,
                 expectedMigrationBurn,
                 "migration burn incorrect");

        // New pool should have received (tokensOut - burn)
        assertEq(newPool, tokensOut - expectedMigrationBurn, "new pool bal");

        // Ensure curator share balances reflect migration
        uint256 curatorOldShares = curation.sharesOf(OLD_ID, curator);
        uint256 curatorNewShares = curation.sharesOf(NEW_ID, curator);
        assertEq(curatorOldShares, sharesMinted - migrateShares, "old share bal");
        assertEq(curatorNewShares, migrateShares /* 1:1 mint */, "new share bal");

        // No SPY lost from curator wallet except burn & pool deposit
        uint256 expectedWallet = initialCuratorBal - 100_000 ether; // net deposit only
        assertEq(token.balanceOf(curator), expectedWallet, "wallet balance wrong");
    }

    /* ------------------------------------------------------------------ */
    /* Internal helper to fetch curve data                                */
    /* ------------------------------------------------------------------ */
    function _curveData(bytes32 id) internal view returns (uint256 tokens,uint256 shares,address dummy) {
        (tokens, shares) = curation.curves(id);
        dummy = address(0); // placeholder to keep tuple structure
    }
}
