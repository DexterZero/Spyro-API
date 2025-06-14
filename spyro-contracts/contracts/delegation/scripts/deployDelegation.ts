/**
 * Deploy the DelegationPool contract and wire it to the rest of
 * the staking stack.
 *
 * Usage:
 *   npx hardhat run script/deployDelegation.ts \
 *        --network <net> \
 *        --token 0x...SPY \
 *        --stake 0x...StakeManager \
 *        --rewards 0x...RewardsDistributor \
 *        --governor 0x...GovernorOrTimelock
 *
 * Required args
 *  --token     Deployed SPYToken (ERC20Votes)
 *  --stake     StakeManager address (for self-stake & unbonding data)
 *  --rewards   RewardsDistributor address (pulls query-fee & inflation rewards)
 *  --governor  Governor / Timelock to own the pool
 */

import { ethers } from "hardhat";
import yargs from "yargs";

async function main() {
  /* ──────── CLI parsing ──────── */
  const argv = await yargs(process.argv.slice(2))
    .option("token",    { type: "string", demandOption: true })
    .option("stake",    { type: "string", demandOption: true })
    .option("rewards",  { type: "string", demandOption: true })
    .option("governor", { type: "string", demandOption: true })
    .parse();

  const [deployer] = await ethers.getSigners();
  console.log(`▶️  Deployer: ${deployer.address}`);

  /* ──────── Deploy DelegationPool ──────── */
  const DelegationPool = await ethers.getContractFactory("DelegationPool");
  const pool = await DelegationPool.deploy(
    argv.token,
    argv.stake,
    argv.rewards
  );
  await pool.deployed();
  console.log(`✅ DelegationPool:     ${pool.address}`);

  /* ──────── Transfer ownership ──────── */
  const tx = await pool.transferOwnership(argv.governor);
  await tx.wait();
  console.log(`🔗 Ownership moved to Governor @ ${argv.governor}`);

  /* ──────── Output summary ──────── */
  console.log(
    "\n📦  Deployment summary:\n" +
      JSON.stringify(
        {
          network: (await ethers.provider.getNetwork()).name,
          DelegationPool: pool.address,
          SPYToken: argv.token,
          StakeManager: argv.stake,
          RewardsDistributor: argv.rewards,
          Governor: argv.governor,
        },
        null,
        2
      )
  );
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
