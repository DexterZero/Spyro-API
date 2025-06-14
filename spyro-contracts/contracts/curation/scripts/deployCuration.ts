/**
 * Deploy Spyro Curation contract
 *
 * Usage:
 *   npx hardhat run script/deployCuration.ts \
 *        --network <net> \
 *        --token 0x...SPY \
 *        --governor 0x...GOV
 *
 * Required args
 *  --token     Address of the already-deployed SPYToken (ERC20Votes)
 *  --governor  Governor (or Timelock) address that will own Curation
 */

import { ethers } from "hardhat";
import yargs from "yargs";
import * as dotenv from "dotenv";

dotenv.config();

async function main() {
  /* ───────────────────────────── CLI parsing ─────────────────────────── */
  const argv = await yargs(process.argv.slice(2))
    .option("token", {
      type: "string",
      demandOption: true,
      describe: "SPYToken address",
    })
    .option("governor", {
      type: "string",
      demandOption: true,
      describe: "Governor / Timelock owner address",
    })
    .parse();

  const [deployer] = await ethers.getSigners();
  console.log(`▶️  Deployer: ${deployer.address}`);

  /* ────────────────────────── Deploy Curation ────────────────────────── */
  const Curation = await ethers.getContractFactory("Curation");
  const curation = await Curation.deploy(argv.token);
  await curation.deployed();
  console.log(`✅ Curation contract:  ${curation.address}`);

  /* ─────────── Transfer ownership to on-chain governance ─────────────── */
  const tx = await curation.transferOwnership(argv.governor);
  await tx.wait();
  console.log(`🔗 Ownership moved to Governor @ ${argv.governor}`);

  /* ────────────────────────── Output summary ─────────────────────────── */
  console.log("\n📦  Deployment summary:");
  console.log(
    JSON.stringify(
      {
        network: (await ethers.provider.getNetwork()).name,
        Curation: curation.address,
        SPYToken: argv.token,
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
