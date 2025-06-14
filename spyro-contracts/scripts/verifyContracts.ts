/**
 * verifyContracts.ts
 * ------------------
 * Batch-verifies every Spyro contract on Etherscan / Blockscout.
 *
 * Prerequisites
 *   • You’ve already run `script/deployAll.ts` on the same network
 *     and it produced artifacts/deployments/spyro-all.json
 *   • Your `.env` (or shell) contains ETHERSCAN_KEY (or respective
 *     BLOCKSCOUT key) recognised by hardhat-verify.
 *
 * Usage
 *   npx hardhat run script/verifyContracts.ts --network <net>
 */

import { execSync } from "child_process";
import { readFileSync } from "fs";
import { resolve } from "path";
import * as dotenv from "dotenv";
dotenv.config();

function main() {
  const network =
    process.argv.includes("--network")
      ? process.argv[process.argv.indexOf("--network") + 1]
      : "hardhat";

  const deploymentPath = resolve(
    "artifacts",
    "deployments",
    "spyro-all.json"
  );
  const addresses = JSON.parse(readFileSync(deploymentPath, "utf8"));

  console.log(`🔎  Verifying Spyro contracts on ${network}…`);

  // 1. simple key/value loop
  for (const [name, addr] of Object.entries(addresses)) {
    try {
      console.log(`\n➡️  ${name}  @  ${addr}`);
      execSync(
        `npx hardhat verify --network ${network} ${addr}`,
        { stdio: "inherit" }
      );
      console.log(`✅  ${name} verified`);
    } catch (err: any) {
      // common cases: already verified / rate-limits
      const msg = (err.stderr || err).toString();
      if (msg.includes("Already Verified")) {
        console.log("ℹ️  already verified, skipping");
      } else {
        console.error(`❌  verification failed for ${name}:`, msg);
      }
    }
  }

  console.log("\n🎉  Batch verification complete!");
}

main();
