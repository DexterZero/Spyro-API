#!/usr/bin/env ts-node
import { ethers } from "hardhat"
import yargs from "yargs"
import * as dotenv from "dotenv"

dotenv.config()

async function main() {
  const argv = await yargs(process.argv.slice(2))
    .option("wormhole", {
      type: "string",
      demandOption: true,
      describe: "Address of the Wormhole core contract",
    })
    .option("sourceChainId", {
      type: "number",
      demandOption: true,
      describe: "Wormhole emitter chain ID for incoming messages",
    })
    .option("sourceBridgeAddress", {
      type: "string",
      demandOption: true,
      describe: "32-byte Wormhole emitter address for this chain's bridge",
    })
    .option("targetChainId", {
      type: "number",
      demandOption: true,
      describe: "Wormhole chain ID for the target chain",
    })
    .option("targetBridgeAddress", {
      type: "string",
      demandOption: true,
      describe: "32-byte Wormhole emitter address of the bridge on target chain",
    })
    .option("curation", {
      type: "string",
      demandOption: true,
      describe: "Address of the Spyro Curation contract on target chain",
    })
    .option("governor", {
      type: "string",
      demandOption: true,
      describe: "Owner address to transfer bridge and receiver ownership to",
    })
    .parse()

  const [deployer] = await ethers.getSigners()
  console.log(`▶️  Deployer: ${deployer.address}`)

  // Deploy WormholeBridge
  const Bridge = await ethers.getContractFactory("WormholeBridge")
  const bridge = await Bridge.deploy(
    argv.wormhole,
    argv.targetChainId,
    argv.targetBridgeAddress
  )
  await bridge.deployed()
  console.log(`✅ WormholeBridge deployed at ${bridge.address}`)

  // Transfer bridge ownership
  await (await bridge.transferOwnership(argv.governor)).wait()
  console.log(`🔑 WormholeBridge ownership transferred to ${argv.governor}`)

  // Deploy WormholeReceiver
  const Receiver = await ethers.getContractFactory("WormholeReceiver")
  const receiver = await Receiver.deploy(
    argv.wormhole,
    argv.sourceChainId,
    ethers.utils.hexlify(ethers.utils.arrayify(argv.sourceBridgeAddress)),
    argv.curation
  )
  await receiver.deployed()
  console.log(`✅ WormholeReceiver deployed at ${receiver.address}`)

  // Transfer receiver ownership
  await (await receiver.transferOwnership(argv.governor)).wait()
  console.log(`🔑 WormholeReceiver ownership transferred to ${argv.governor}`)

  // Summary
  console.log("\n📦 Deployment summary:")
  console.log(
    JSON.stringify(
      {
        network: (await ethers.provider.getNetwork()).name,
        wormholeCore: argv.wormhole,
        sourceChainId: argv.sourceChainId,
        sourceBridgeAddress: argv.sourceBridgeAddress,
        targetChainId: argv.targetChainId,
        targetBridgeAddress: argv.targetBridgeAddress,
        WormholeBridge: bridge.address,
        WormholeReceiver: receiver.address,
        SpyroCuration: argv.curation,
        Governor: argv.governor,
      },
      null,
      2
    )
  )
}

main().catch((err) => {
  console.error(err)
  process.exitCode = 1
})
