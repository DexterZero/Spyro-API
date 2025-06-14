// SPDX-License-Identifier: MIT
// -----------------------------------------------------------------------------
// spyro-bridges-wormhole ▸ relayer/src/watcher.ts
// -----------------------------------------------------------------------------
// Watches Wormhole core contract events on source chain, fetches signed VAAs,
// and passes them to the provided handler for on-chain relay.

import { ethers } from 'ethers'
import {
  getEmitterAddressEth,
  getSignedVAAWithRetry,
  Transport,
} from '@certusone/wormhole-sdk'
import { RelayerConfig } from './config'

export type VAAHandler = (vaa: Uint8Array) => Promise<void>

/**
 * Creates and starts a watcher that listens for Wormhole messages
 * and invokes the handler with the raw VAA bytes.
 */
export async function startWatcher(
  config: RelayerConfig,
  handler: VAAHandler
): Promise<ethers.Contract> {
  const provider = new ethers.providers.JsonRpcProvider(config.sourceRpc)

  // Minimal Wormhole core ABI: subscribe to LogMessagePublished events
  const WormholeCoreABI = [
    'event LogMessagePublished(address indexed sender, uint64 sequence, uint32 nonce, bytes payload, uint8 consistencyLevel)'
  ]
  const wormholeCore = new ethers.Contract(
    config.sourceBridgeAddress,
    WormholeCoreABI,
    provider
  )

  // Compute the emitter address (lowercase hex, no 0x prefix)
  const emitterAddress = getEmitterAddressEth(config.sourceBridgeAddress)

  // Listen for published messages
  wormholeCore.on(
    wormholeCore.filters.LogMessagePublished(emitterAddress),
    async (
      sender: string,
      sequence: ethers.BigNumber,
      nonce: number,
      payload: string,
      consistency: number,
      event
    ) => {
      console.log(`🔍 Detected message seq=${sequence.toString()} nonce=${nonce}`)
      try {
        // Fetch signed VAA with retry until finality
        const vaaBytes = await getSignedVAAWithRetry(
          [config.wormholeRpc],               // array of RPC URLs
          config.sourceChainId,
          config.sourceBridgeAddress,
          sequence.toNumber(),
          {
            transport: Transport.RPC,
            /**
             * Optional parameters:
             *   retryAttempts: config.retryAttempts
             *   retryBackoffMs: config.retryBackoffMs
             */
          }
        )
        console.log(`✅ Fetched VAA size=${vaaBytes.length}`)
        await handler(vaaBytes)
      } catch (err) {
        console.error('❌ Failed to fetch VAA:', err)
      }
    }
  )

  console.log(`🔗 Watching Wormhole core at ${config.sourceRpc}`)
  return wormholeCore
}
