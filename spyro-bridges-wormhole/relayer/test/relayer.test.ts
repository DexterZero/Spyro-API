// SPDX-License-Identifier: MIT
// -----------------------------------------------------------------------------
// spyro-bridges-wormhole ▸ relayer/test/relayer.test.ts
// -----------------------------------------------------------------------------
// Jest unit tests for the Wormhole relayer modules: config, watcher, and publisher.

import { loadConfig } from "../src/config"
import { createPublisher } from "../src/publisher"
import { createWatcher } from "../src/watcher"
import { parseVaa, getEmitterAddressEth } from "@certusone/wormhole-sdk"
import { ethers } from "ethers"

jest.mock("@certusone/wormhole-sdk", () => ({
  parseVaa: jest.fn(),
  getEmitterAddressEth: jest.fn()
}))

describe("Config Loader", () => {
  const OLD_ENV = process.env

  beforeEach(() => {
    jest.resetModules()
    process.env = { ...OLD_ENV }
  })

  afterAll(() => {
    process.env = OLD_ENV
  })

  it("throws when required vars are missing", () => {
    delete process.env.SOURCE_RPC
    expect(() => loadConfig()).toThrow(/Missing required config parameter/)
  })

  it("loads config from env vars successfully", () => {
    process.env.SOURCE_RPC = "http://src"
    process.env.TARGET_RPC = "http://tgt"
    process.env.SOURCE_CHAIN_ID = "1"
    process.env.TARGET_CHAIN_ID = "2"
    process.env.SOURCE_BRIDGE_ADDR = "0xabcdef"
    process.env.TARGET_BRIDGE_ADDR = "0x123456"
    process.env.RELAYER_PRIVATE_KEY = "0xdeadbeef"

    const cfg = loadConfig()
    expect(cfg.sourceRpc).toBe("http://src")
    expect(cfg.targetRpc).toBe("http://tgt")
    expect(cfg.sourceChainId).toBe(1)
    expect(cfg.targetChainId).toBe(2)
    expect(cfg.sourceBridgeAddress).toBe("0xabcdef")
    expect(cfg.targetBridgeAddress).toBe("0x123456")
    expect(cfg.privateKey).toBe("0xdeadbeef")
    expect(cfg.retryAttempts).toBe(5)
    expect(cfg.retryBackoffMs).toBe(2000)
  })
})

describe("Publisher", () => {
  let publisher: ReturnType<typeof createPublisher>
  let mockContract: any
  let cfg: any

  beforeEach(() => {
    // Mock config
    cfg = {
      targetRpc: "http://tgt",
      privateKey: "0xabc",
      targetBridgeAddress: "0xbridge",
      targetChainId: 2,
    }
    jest.spyOn(require("../src/config"), "loadConfig").mockReturnValue(cfg)

    // Mock ethers
    mockContract = {
      receiveAndExecuteVAA: jest.fn().mockResolvedValue({
        wait: jest.fn().mockResolvedValue({ status: 1 })
      })
    }
    jest.spyOn(ethers, "Contract").mockImplementation(() => mockContract)

    // Mock parseVaa output
    ;(parseVaa as jest.Mock).mockReturnValue({
      emitterChain: 1,
      emitterAddress: Buffer.from("").toString(),
      payload: Buffer.from("payload"),
    })

    publisher = createPublisher()
  })

  it("successfully publishes a valid VAA", async () => {
    const vaaBytes = Buffer.from([1,2,3])
    const receipt = await publisher.publishVaa(vaaBytes)
    expect(parseVaa).toHaveBeenCalledWith(vaaBytes)
    expect(mockContract.receiveAndExecuteVAA).toHaveBeenCalledWith(vaaBytes)
    expect(receipt.status).toBe(1)
  })

  it("throws if emitterChainId mismatches config", async () => {
    ;(parseVaa as jest.Mock).mockReturnValue({
      emitterChain: 99,
      emitterAddress: Buffer.from("").toString(),
      payload: Buffer.from("p"),
    })
    await expect(publisher.publishVaa(Buffer.from([0]))).rejects.toThrow(/Invalid emitter chainId/)
  })
})

describe("Watcher", () => {
  it("throws if handler is not a function", () => {
    expect(() => createWatcher(null as any)).toThrow(/handler must be a function/)
  })
  // Note: full integration test of watcher requires mocking ethers.providers and Wormhole core,
  // which can be done in integration suite using a local Hardhat node.
})
