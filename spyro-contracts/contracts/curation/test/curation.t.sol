// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "contracts/governance/SPYToken.sol";
import "contracts/curation/Curation.sol";

/// @title MigrationTest
/// @notice Tests the curator share auto‑migration when an AI‑Graph upgrades.
contract MigrationTest is Test {
    SPYToken token;
    Curation curation;

    address owner = address(this);
    address curator = address(0xA1);

    GraphID oldId = GraphID.wrap(bytes32(uint256(1)));
    GraphID newId = GraphID.wrap(bytes32(uint256(2)));

    function setUp() public {
        token = new SPYToken();
        curation = new Curation(address(token));

        token.mint(curator, 1_000 ether);
        vm.prank(curator);
        token.approve(address(curation), type(uint256).max);
    }

    function testVersionMigration() public {
        uint256 deposit = 100 ether;
        vm.prank(curator);
        uint256 sharesIssued = curation.signal(oldId, deposit);

        // Record state before migration
        (uint256 oldTokensBefore, uint256 oldSharesBefore) = curation.curves(oldId);
        (uint256 newTokensBefore, uint256 newSharesBefore) = curation.curves(newId);

        // Migrate 50% of shares
        uint256 sharesToMove = sharesIssued / 2;
        curation.migrateVersion(oldId, newId, sharesToMove);

        // After migration, old curve tokens must shrink
        (uint256 oldTokensAfter, uint256 oldSharesAfter) = curation.curves(oldId);
        (uint256 newTokensAfter, uint256 newSharesAfter) = curation.curves(newId);

        assertEq(oldSharesAfter, oldSharesBefore - sharesToMove, "old shares reduced");
        assertEq(newSharesAfter, newSharesBefore + sharesToMove - 0, "new shares increased");
        assertLt(oldTokensAfter, oldTokensBefore, "old tokens reduced");
        assertGt(newTokensAfter, newTokensBefore, "new tokens grew");

        // Check migration tax: 1% burned
        uint256 netTokensMoved = curation.pricePerShare(newId) * sharesToMove / 1 ether; // approximate
        uint256 tax = (netTokensMoved * curation.MIGRATION_TAX_BPS()) / 10_000;
        assertApproxEqAbs(token.balanceOf(address(0xdead)), tax, 1,
            "burn address should receive migration tax");
    }
}
