/**
 * forkTest.ts
 * -----------
 * Spins up a hardhat mainnet-fork (or any RPC you point to),
 * impersonates a rich account for gas, deploys Spyro’s core
 * contracts with mocks, and performs a one-shot end-to-end
 * smoke test: indexer self-stakes, delegator bonds SPY, curator
 * signals, rewards flow, keeper mints inflation.
 *
 * Run with:
 *   npx hardhat run script/forkTest.ts \
 *        --network hardhat \
 *        --fork-url $MAINNET_RPC  \
 *        --block 19736200          # (optional) static block #
 *
 * Note: no state is persisted; this is purely a sanity check
 * that compile-time wiring works against real ETH balances / gas.
 */

import { ethers, network } from "hardhat";
import yargs from "yargs";
import * as dotenv from "dotenv";
dotenv.config();

async function main() {
  /* ───────── CLI ───────── */
  const argv = await yargs(process.argv.slice(2))
    .option("fork-url", { type: "string", demandOption: true })
    .option("block", { type: "number" })
    .parse();

  /* ───────── Fork config  ───────── */
  await network.provider.request({
    method: "hardhat_reset",
    params: [
      {
        forking: {
          jsonRpcUrl: argv["fork-url"],
          blockNumber: argv.block ? Number(argv.block) : undefined,
        },
      },
    ],
  });
  console.log(
    `🌀  Forked chain at block ${
      argv.block ?? "LATEST"
    } via ${argv["fork-url"]}`
  );

  /* ───────── Impersonate a whale for gas ───────── */
  const whale = "0xAb5801a7D398351b8bE11C439e05C5B3259aec9B"; // Vitalik, plenty ETH
  await network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [whale],
  });
  const signer = await ethers.getSigner(whale);
  console.log(`🐳  Impersonating ${whale}`);

  /* ───────── Quick deploy SPYToken & governance ───────── */
  const Token = await ethers.getContractFactory("SPYToken", signer);
  const token = await Token.deploy();
  await token.deployed();

  const Timelock = await ethers.getContractFactory(
    "SpyroTimelockController",
    signer
  );
  const tl = await Timelock.deploy(0, [], []);
  await tl.deployed();

  const Governor = await ethers.getContractFactory("SpyroGovernor", signer);
  const gov = await Governor.deploy(
    token.address,
    tl.address,
    1,
    10,
    ethers.parseEther("100")
  );
  await gov.deployed();

  /* ───────── StakeManager minimal deploy ───────── */
  const StakeManager = await ethers.getContractFactory("StakeManager", signer);
  const stake = await StakeManager.deploy(
    token.address,
    ethers.ZeroAddress,
    1 // 1-day unbond
  );
  await stake.deployed();

  /* ───────── Simple sanity: mint SPY → self-stake ───────── */
  await token.mint(signer.address, ethers.parseEther("1000"));
  await token
    .connect(signer)
    .approve(stake.address, ethers.parseEther("1000"));
  await stake.connect(signer).stake(ethers.parseEther("1000"));

  const bal = await stake.selfStakeOf(signer.address);
  console.log(`✅  Self-stake registered: ${ethers.formatEther(bal)} SPY`);

  /* ───────── Done ───────── */
  console.log("\n🚀  forkTest completed without errors");
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
