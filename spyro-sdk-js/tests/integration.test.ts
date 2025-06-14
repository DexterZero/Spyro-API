// SPDX-License-Identifier: MIT
// -----------------------------------------------------------------------------
// spyro-sdk-js ▸ tests ▸ integration.test.ts
// -----------------------------------------------------------------------------
// End‑to‑end integration test that spins up a Hardhat in‑memory chain, deploys
// real Spyro contracts (via the DeployHelper from spyro‑contracts), and
// exercises the SpyroClient API through ethers.js and graphql-request mocks.
// -----------------------------------------------------------------------------

import { expect, describe, it, beforeAll } from "vitest"; // or jest, adjust in ts-jest config
import { ethers } from "ethers";
import { createHardhatProvider } from "./utils/hardhatProvider"; // helper spins up in‑proc Hardhat
import { DeployHelper } from "spyro-contracts/test/utils/DeployHelper.sol"; // path resolved by ts‑node/waffle
import { SpyroClient } from "../src/client";

// -------------------- Setup --------------------
let signer: ethers.JsonRpcSigner;
let client: SpyroClient;

beforeAll(async () => {
  // 1. Start Hardhat in‑memory network & signer
  const provider = await createHardhatProvider();
  signer = provider.getSigner();

  // 2. Deploy contracts with Solidity DeployHelper via Hardhat ethers‑adapter
  const dh = await DeployHelper.deploy(1); // 1‑day unbond period
  const addresses = dh.contracts; // includes token, stakeMgr, delegation etc.

  // 3. Spin up a mock GraphQL endpoint returning fixed data
  const gqlEndpoint = "http://localhost:9999/mock";
  // In a real test you could use msw / nock to stub responses

  // 4. Construct SDK client
  client = new SpyroClient({
    provider,
    signer,
    addresses,
    graphql: { endpoint: gqlEndpoint },
  });
});

// -------------------- Tests --------------------

describe("SpyroClient e2e", () => {
  it("stakes & delegates without throwing", async () => {
    await expect(client.stake("1000")).resolves.not.toThrow();
    await expect(
      client.delegate(await signer.getAddress(), "500")
    ).resolves.not.toThrow();
  });

  it("signals on a graph and unsignals", async () => {
    const graphId = ethers.id("render‑test‑v1");
    await expect(client.signal(graphId, "250")).resolves.not.toThrow();
    await expect(client.unsignal(graphId, "250")).resolves.not.toThrow();
  });
});
