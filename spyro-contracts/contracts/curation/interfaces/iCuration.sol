// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "contracts/governance/SPYToken.sol";
import "contracts/curation/Curation.sol";

/// @title Curation module unit tests
/// @notice Covers signal/unsignal flow, tax burn, share math and version migration.
contract Curation_Test is Test {
    /* --------------------------------------------------------------------- */
    /* Test actors                                                           */
    /* --------------------------------------------------------------------- */
    address alice = vm.addr(0xA11CE);
    address bob   = vm.addr(0xB0B);

    /* --------------------------------------------------------------------- */
    /* Deployed contracts                                                    */
    /* --------------------------------------------------------------------- */
    SPYToken   token;
    Curation   curation;

    /* Graph IDs */
    Curation.GraphID internal graphV1;
    Curation.GraphID internal graphV2;

    /* Constants */
    uint256 constant ONE = 1 ether;

    function setUp() public {
        token    = new SPYToken();
        curation = new Curation(address(token));

        // give Alice & Bob some SPY and approve curation contract
        token.mint(alice, 1_000_000 * ONE);
        token.mint(bob,   1_000_000 * ONE);
        vm.prank(alice); token.approve(address(curation), type(uint256).max);
        vm.prank(bob);   token.approve(address(curation), type(uint256).max);

        graphV1 = Curation.GraphID.wrap(keccak256("render:stable-diffusion@v1"));
        graphV2 = Curation.GraphID.wrap(keccak256("render:stable-diffusion@v2"));
    }

    /* --------------------------------------------------------------------- */
    /* testSignalInitial: First curator gets 1‑to‑1 shares                    */
    /* --------------------------------------------------------------------- */
    function testSignalInitial() public {
        vm.prank(alice);
        uint256 shares = curation.signal(graphV1, 100 * ONE);
        // 2.5 % tax burned – net deposit = 97.5
        uint256 expectedShares = 97_500_000_000_000_000_000; // 97.5 * 1e18
        assertEq(shares, expectedShares, "Incorrect shares minted");
        assertEq(curation.pricePerShare(graphV1), ONE, "PPS should be 1 on first signal");
    }

    /* --------------------------------------------------------------------- */
    /* testSignalAddsLiquidity: later curators pay higher price               */
    /* --------------------------------------------------------------------- */
    function testSignalAddsLiquidity() public {
        // Alice signals first
        vm.prank(alice);
        curation.signal(graphV1, 100 * ONE);
        // Bob signals later
        vm.prank(bob);
        uint256 bobShares = curation.signal(graphV1, 100 * ONE);
        // Bob should get < Alice because price increased
        assertLt(bobShares, 97_500_000_000_000_000_000);
    }

    /* --------------------------------------------------------------------- */
    /* testUnsignalReturnsFunds                                              */
    /* --------------------------------------------------------------------- */
    function testUnsignalReturnsFunds() public {
        vm.prank(alice);
        uint256 shares = curation.signal(graphV1, 100 * ONE);

        uint256 balanceBefore = token.balanceOf(alice);
        vm.prank(alice);
        uint256 withdrawn = curation.unsignal(graphV1, shares);
        uint256 balanceAfter = token.balanceOf(alice);
        assertEq(balanceAfter - balanceBefore, withdrawn, "Alice did not receive tokens");
    }

    /* --------------------------------------------------------------------- */
    /* testMigrationFlow: Owner migrates shares to new version                */
    /* --------------------------------------------------------------------- */
    function testMigrationFlow() public {
        // Alice signals
        vm.prank(alice);
        uint256 shares = curation.signal(graphV1, 100 * ONE);

        // Give ownership to this test contract so we can call migrate
        curation.transferOwnership(address(this));

        // migrate 50 % shares
        uint256 migrateShares = shares / 2;
        curation.migrateVersion(graphV1, graphV2, migrateShares);

        // Old curve shares reduced
        assertEq(curation.sharesOf(graphV1, alice), shares - migrateShares);
        // New curve shares credited
        assertGt(curation.sharesOf(graphV2, alice), 0, "Shares not migrated");

        // 1 % tax burned => total tokens in system reduced by 1 %
    }
}
