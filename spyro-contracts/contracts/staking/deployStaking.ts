/**
 * Deploy Spyro staking stack
 *   1. StakeManager         – indexer self-stake + unbonding queue
 *   2. DelegationManager    – delegator shares & capacity rule (16× self-stake)
 *   3. SlashingManager      – dispute → arbitration → 2.5 % slash
 *   4. RewardsDistributor   – 3 % inflation mint + 1 % fee-burn
 *
 * Constructor params & wiring match the Solidity stubs shared earlier.
 * ---------------------------------------------------------------
 * Usage:
 *   npx hardhat run script/deployStaking.ts --network <net> \
 *     --token 0x...SPY   (already-deployed ERC20Votes token)
 *
 * The script prints JSON you can feed into frontend env files.
 */

import { ethers } from "hardhat";
import * as dotenv from "dotenv";
import yargs from "yargs";

dotenv.config();

async function main() {
  /* ------------------------------------------------------------ */
  /* CLI & signer                                                */
  /* ------------------------------------------------------------ */
  const argv = await yargs(process.argv.slice(2))
    .option("token", {
      type: "string",
      demandOption: true,
      describe: "Address of the deployed SPYToken (ERC20Votes)",
    })
    .option("unbondingDays", {
      type: "number",
      default: 28,
      describe: "Unbonding period for indexers (days)",
    })
    .parse();

  const [deployer] = await ethers.getSigners();
  console.log(`▶️  Deployer: ${deployer.address}`);

  const spyToken = await ethers.getContractAt("SPYToken", argv.token);

  /* ------------------------------------------------------------ */
  /* 1. Deploy StakeManager with placeholder delegation address   */
  /* ------------------------------------------------------------ */
  const StakeManager = await ethers.getContractFactory("StakeManager");
  const stakeManager = await StakeManager.deploy(
    spyToken.address,
    ethers.constants.AddressZero,         // placeholder DelegationManager
    argv.unbondingDays
  );
  await stakeManager.deployed();
  console.log(`✅ StakeManager:        ${stakeManager.address}`);

  /* ------------------------------------------------------------ */
  /* 2. Deploy DelegationManager, now we know stakeManager addr   */
  /* ------------------------------------------------------------ */
  const DelegationManager = await ethers.getContractFactory(
    "DelegationManager"
  );
  const delegationManager = await DelegationManager.deploy(
    spyToken.address,
    stakeManager.address
  );
  await delegationManager.deployed();
  console.log(`✅ DelegationManager:   ${delegationManager.address}`);

  /* ------------------------------------------------------------ */
  /* 3. Wire StakeManager → DelegationManager                    */
  /*    (requires StakeManager.setDelegationManager() in stub)    */
  /* ------------------------------------------------------------ */
  const txWire = await stakeManager.setDelegationManager(
    delegationManager.address
  );
  await txWire.wait();
  console.log("🔗 StakeManager linked to DelegationManager");

  /* ------------------------------------------------------------ */
  /* 4. Deploy SlashingManager                                   */
  /* ------------------------------------------------------------ */
  const SlashingManager = await ethers.getContractFactory("SlashingManager");
  const slashingManager = await SlashingManager.deploy(stakeManager.address);
  await slashingManager.deployed();
  console.log(`✅ SlashingManager:     ${slashingManager.address}`);

  /* ------------------------------------------------------------ */
  /* 5. Deploy RewardsDistributor                                */
  /* ------------------------------------------------------------ */
  const RewardsDistributor = await ethers.getContractFactory(
    "RewardsDistributor"
  );
  const rewardsDistributor = await RewardsDistributor.deploy(
    spyToken.address,
    stakeManager.address
  );
  await rewardsDistributor.deployed();
  console.log(`✅ RewardsDistributor:  ${rewardsDistributor.address}`);

  /* ------------------------------------------------------------ */
  /* 6. Optional ownership hand-off to Timelock / Governor        */
  /* ------------------------------------------------------------ */
  // const GOVERNOR = "0xYourGovernorAddress";
  // await slashingManager.transferOwnership(GOVERNOR);
  // await rewardsDistributor.transferOwnership(GOVERNOR);

  /* ------------------------------------------------------------ */
  /* 7. Output as JSON for front-end enviros                      */
  /* ------------------------------------------------------------ */
  const addresses = {
    SPYToken: spyToken.address,
    StakeManager: stakeManager.address,
    DelegationManager: delegationManager.address,
    SlashingManager: slashingManager.address,
    RewardsDistributor: rewardsDistributor.address,
  };
  console.log("\n📦  Deployment summary:");
  console.log(JSON.stringify(addresses, null, 2));
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
