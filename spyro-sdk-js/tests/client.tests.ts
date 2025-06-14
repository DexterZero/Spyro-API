// SPDX-License-Identifier: MIT
// -----------------------------------------------------------------------------
// spyro-sdk-js ▸ tests ▸ client.test.ts
// -----------------------------------------------------------------------------
// Jest unit tests for SpyroClient high‑level wrapper.
// These tests use ethers.js `AbstractProvider` with Hardhat's in‑memory
// JSON‑RPC to spin up a lightweight chain and deploy minimal mocks so we
// don’t require the full spyro-contracts suite.
//
// Run with:  npm t   (ts‑jest)
// -----------------------------------------------------------------------------

import { describe, it, expect, beforeAll } from "@jest/globals";
import { JsonRpcProvider, Wallet, parseEther } from "ethers";
import { SpyroClient } from "../src/client"; // adjust path if barrel
import * as addressesUtil from "../src/utils/addresses";
import { SPY_DECIMALS } from "../src/utils/constants";

// ─── Hardhat local node spinning via anvil (installed with foundry) ─────
const provider = new JsonRpcProvider("http://127.0.0.1:8545");

let signer: Wallet;
let client: SpyroClient;

beforeAll(async () => {
  // Use the first hardhat account
  const accounts = await provider.listAccounts();
  signer = provider.getSigner(accounts[0]) as Wallet;

  // Mock the address loader to return fixed addresses for tests
  jest.spyOn(addressesUtil, "loadAddresses").mockReturnValue({
    Governor: "0x0000000000000000000000000000000000000001",
    Timelock: "0x0000000000000000000000000000000000000002",
    SPYToken: "0x000000000000000000000000000000000000dead",
    StakeManager: "0x0000000000000000000000000000000000000003",
    DelegationPool: "0x0000000000000000000000000000000000000004",
    RewardsDistributor: "0x0000000000000000000000000000000000000005",
    Curation: "0x0000000000000000000000000000000000000006",
  } as any);

  // Initialise client (constructor will call loadAddresses)
  client = new SpyroClient({ provider, signer });
});

describe("SpyroClient basic instantiation", () => {
  it("instantiates governance, staking and curation modules", () => {
    expect(client.governance).toBeDefined();
    expect(client.staking).toBeDefined();
    expect(client.curation).toBeDefined();
  });
});

describe("Format helpers round‑trip", () => {
  it("converts SPY human → bigint and back", () => {
    const human = "123.456";
    const bi = client.utils.parseSpy(human);
    const back = client.utils.formatSpy(bi);
    // Allow small rounding diff beyond decimals
    expect(back.startsWith("123.456")).toBeTruthy();
  });
});
