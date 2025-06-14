#!/usr/bin/env ts-node
/**
 * spyro-bridges-wormhole Relayer Bootstrap
 * ----------------------------------------
 * Watches Wormhole messages on source chain and submits them to the
 * WormholeReceiver on target chain. Supports curation signals.
 */
import yargs from 'yargs'
import { hideBin } from 'yargs/helpers'
import { ethers } from 'ethers'
import { parseVaa } from '@certusone/wormhole-sdk'
import { createWatcher } from './watcher'
import { publishToReceiver } from './publisher'
import { loadConfig, RelayerConfig } from './config'

async function main() {
  const argv = await yargs(hideBin(process.argv))
    .option('config', {
      alias: 'c',
      type: 'string',
      demandOption: true,
      describe: 'Path to relayer config JSON or YAML',
    })
    .help()
    .parse()

  // Load configuration
  const config: RelayerConfig = loadConfig(argv.config)
  console.log(`🔧 Loaded config for relayer: ${argv.config}`)

  // Initialize Ethereum providers and wallets
  const sourceProvider = new ethers.JsonRpcProvider(config.source.rpc)
  const targetProvider = new ethers.JsonRpcProvider(config.target.rpc)
  const relayerWallet = new ethers.Wallet(config.relayerPrivateKey, targetProvider)

  console.log(`🚀 Relayer wallet: ${relayerWallet.address}`)

  // Create Wormhole watcher
  const watcher = createWatcher(sourceProvider, config)
  console.log('👀 Starting Wormhole VAA watcher...')

  // Subscribe to messages
  watcher.on('vaa', async (vaaBytes: Buffer) => {
    try {
      console.log('📨 VAA received, verifying & publishing...')
      const { vaa, valid } = parseVaa(vaaBytes)
      if (!valid) {
        console.warn('⚠️  Received invalid VAA, skipping')
        return
      }

      // Forward to target chain
      const receipt = await publishToReceiver(
        vaaBytes,
        relayerWallet,
        config.target.receiverAddress
      )

      console.log(`✅ Message delivered in tx: ${receipt.hash}`)
    } catch (err) {
      console.error('❌ Error processing VAA:', err)
    }
  })

  // Handle watcher errors
  watcher.on('error', (err) => {
    console.error('Watcher error:', err)
  })
}

main().catch((err) => {
  console.error(err)
  process.exit(1)
})
