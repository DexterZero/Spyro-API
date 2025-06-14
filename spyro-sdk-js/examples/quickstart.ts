#!/usr/bin/env ts-node
/* ----------------------------------------------------------------------------
 * Spyro SDK – Quick‑Start Example
 * ----------------------------------------------------------------------------
 * Demonstrates how to:                
 *   1. Initialise SpyroClient (auto‑detect contracts & GraphQL endpoint)
 *   2. Stake 100 SPY as an indexer
 *   3. Delegate 25 SPY from a second wallet
 *   4. Query Spyro‑Node for current indexer stats
 *
 * Run with: `ts-node examples/quickstart.ts` (or `npm run ts-node …`)
 * Make sure you export PRIVATE_KEY & RPC_URL environment variables first.
 * ---------------------------------------------------------------------------- */

import { SpyroClient } from "../dist"; // adjust path if running TS without build step
import { JsonRpcProvider, Wallet } from "ethers";
import { formatAmount } from "../dist/utils/format";

async function main() {
  // 1️⃣  Set up signer & client
  const rpcUrl = process.env.RPC_URL ?? "http://localhost:8545";
  const pk     = process.env.PRIVATE_KEY ?? "0xYOUR_PRIVATE_KEY";
  const provider = new JsonRpcProvider(rpcUrl);
  const signer   = new Wallet(pk, provider);

  const spyro = new SpyroClient({ signer, provider, gqlUrl: "http://localhost:8000/graphql" });

  // 2️⃣  Indexer stakes 100 SPY
  console.log("→ Staking 100 SPY…");
  const txStake = await spyro.staking.stake("100");
  await txStake.wait();
  console.log(`✅ Stake tx mined: ${txStake.hash}`);

  // 3️⃣  Delegator delegates 25 SPY (delegate from the same signer for demo)
  console.log("→ Delegating 25 SPY to self (indexer)…");
  const txDel = await spyro.staking.delegate(await signer.getAddress(), "25");
  await txDel.wait();
  console.log(`✅ Delegation tx: ${txDel.hash}`);

  // 4️⃣  Query indexer stats via GraphQL helper
  const stats = await spyro.gql.getIndexerStats({ id: await signer.getAddress() });
  if (stats) {
    console.log("Indexer Stats:");
    console.log("  Self‑stake:", formatAmount(stats.selfStake), "SPY");
    console.log("  Delegated: ", formatAmount(stats.delegatedStake), "SPY");
    console.log("  Curator APY:", stats.apy, "%");
  } else {
    console.log("Indexer not found in GraphQL index yet.");
  }

  console.log("🏁 Quick‑start flow complete!");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
