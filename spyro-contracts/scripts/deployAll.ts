/**
 * Orchestrates deployment of every Spyro contract stack in
 * the correct order. Uses the component-local deploy helpers
 * you already have, so if a single step changes you edit just
 * that helper, not this orchestrator.
 *
 * Usage:
 *   npx hardhat run script/deployAll.ts --network <net>
 *
 * Requires .env with:
 *   SPY_DEPLOYER_PK, NETWORK_RPC, ETHERSCAN_KEY (optional)
 */

import { ethers } from "hardhat";
import * as dotenv from "dotenv";
import { execSync } from "child_process";
import { loadEnvVar, saveJson } from "./utils";

dotenv.config();

async function main() {
  /* ----- pick up signer ----- */
  const deployer = new ethers.Wallet(
    loadEnvVar("SPY_DEPLOYER_PK"),
    new ethers.JsonRpcProvider(loadEnvVar("NETWORK_RPC"))
  );
  console.log(`▶️  Deployer: ${deployer.address}`);

  /* ----- GOVERNANCE ----- */
  execSync(
    `npx hardhat run contracts/governance/script/deployGovernance.ts ` +
      `--network ${network()} --token ""`, // token deployed inside helper
    { stdio: "inherit" }
  );

  /* The deployGovernance script prints a JSON summary; read it back */
  const gov = require("../artifacts/deployments/governance.json");

  /* ----- STAKING ----- */
  execSync(
    `npx hardhat run contracts/staking/script/deployStaking.ts ` +
      `--network ${network()} ` +
      `--token ${gov.SPYToken} --governor ${gov.Governor}`,
    { stdio: "inherit" }
  );

  const stake = require("../artifacts/deployments/staking.json");

  /* ----- CURATION ----- */
  execSync(
    `npx hardhat run contracts/curation/scripts/deployCuration.ts ` +
      `--network ${network()} ` +
      `--token ${gov.SPYToken} --governor ${gov.Governor}`,
    { stdio: "inherit" }
  );

  /* ----- DELEGATION ----- */
  execSync(
    `npx hardhat run contracts/delegation/scripts/deployDelegation.ts ` +
      `--network ${network()} ` +
      `--token ${gov.SPYToken} ` +
      `--stake ${stake.StakeManager} ` +
      `--rewards ${stake.RewardsDistributor} ` +
      `--governor ${gov.Governor}`,
    { stdio: "inherit" }
  );

  /* collect all addresses */
  const delegation = require("../artifacts/deployments/delegation.json");
  const summary = { ...gov, ...stake, ...delegation };

  saveJson("artifacts/deployments/spyro-all.json", summary);
  console.log("\n🚀  Spyro protocol fully deployed!");
}

function network() {
  return process.argv.includes("--network")
    ? process.argv[process.argv.indexOf("--network") + 1]
    : "hardhat";
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
