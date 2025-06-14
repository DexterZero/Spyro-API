// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title DeployHelper
 * @notice Utility contract for Foundry/Hardhat *test suites* that need a
 *         fully‑wired Spyro stack in one call.  NOT meant for production
 *         deployment (use the TS scripts instead).
 *
 * Usage inside a test:
 *   import { DeployHelper } from "test/utils/DeployHelper.sol";
 *   (DeployHelper.Contracts memory c, address deployer) = DeployHelper.deploy();
 *
 * The helper deploys:
 *   • SPYToken
 *   • SpyroTimelockController (delay = 0 for tests)
 *   • SpyroGovernor
 *   • StakeManager (+ mock Delegation link)
 *   • RewardsDistributor
 *   • DelegationPool
 *   • Curation
 */

import "contracts/governance/SPYToken.sol";
import "contracts/governance/SpyroTimelockController.sol";
import "contracts/governance/SpyroGovernor.sol";
import "contracts/staking/StakeManager.sol";
import "contracts/staking/RewardsDistributor.sol";
import "contracts/delegation/DelegationPool.sol";
import "contracts/curation/Curation.sol";

library DeployHelper {
    struct Contracts {
        SPYToken token;
        SpyroGovernor governor;
        StakeManager stakeMgr;
        RewardsDistributor rewards;
        DelegationPool delegation;
        Curation curation;
    }

    /// @notice Deploy all Spyro core contracts for testing purposes.
    /// @return c   Struct bundle with references to all deployed contracts
    /// @return deployer Address used as msg.sender during deployment
    function deploy() internal returns (Contracts memory c, address deployer) {
        deployer = address(this); // in Foundry tests library deploys via current context

        /* ─── Token ─── */
        c.token = new SPYToken();

        /* ─── Timelock + Governor (0 delay for tests) ─── */
        SpyroTimelockController tl = new SpyroTimelockController(0, new address[](0), new address[](0));
        c.governor = new SpyroGovernor(
            c.token,
            tl,
            1,        // votingDelay
            10,       // votingPeriod
            0         // proposalThreshold
        );

        /* ─── Staking stack ─── */
        c.stakeMgr = new StakeManager(address(c.token), address(0), 1 /* day */);
        c.rewards  = new RewardsDistributor(address(c.token), address(c.stakeMgr));

        /* ─── Delegation + Curation ─── */
        c.delegation = new DelegationPool(
            address(c.token),
            address(c.stakeMgr),
            address(c.rewards)
        );
        c.curation   = new Curation(address(c.token));

        // Link delegation manager inside StakeManager
        c.stakeMgr.setDelegationManager(address(c.delegation));

        return (c, deployer);
    }
}
