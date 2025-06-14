// SPDX-License-Identifier: MIT
// -----------------------------------------------------------------------------
// spyro-bridges-wormhole ▸ relayer/src/publisher.ts
// -----------------------------------------------------------------------------
// Verifies Wormhole VAAs and submits them to the WormholeReceiver contract

import { ethers } from 'ethers'
import { parseVaa } from '@certusone/wormhole-sdk'
import { IWormholeReceiver__factory } from './types' // generated from WormholeReceiver ABI
import { Config } from './config'

export class Publisher {
  private provider: ethers.providers.JsonRpcProvider
  private wallet: ethers.Wallet
  private receiver: ethers.Contract
  private config: Config

  constructor(config: Config) {
    this.config = config
    // set up target chain provider & signer
    this.provider = new ethers.providers.JsonRpcProvider(config.targetRpc)
    this.wallet = new ethers.Wallet(config.relayerPrivKey, this.provider)
    // connect to WormholeReceiver contract on target chain
    this.receiver = IWormholeReceiver__factory.connect(
      config.targetReceiverAddress,
      this.wallet
    )
  }

  /**
   * Verify and publish a VAA to the target chain's WormholeReceiver
   * @param vaaBytes - signed VAA bytes fetched from Wormhole guardian network
   */
  async publishVaa(vaaBytes: Uint8Array | Buffer | string): Promise<ethers.providers.TransactionResponse> {
    // parseVaa accepts Buffer or hex string
    const vaa = parseVaa(Buffer.isBuffer(vaaBytes) ? vaaBytes : Buffer.from(vaaBytes as string, 'base64'))

    // validate emitter chain and address
    if (vaa.emitterChain !== this.config.sourceChainId) {
      throw new Error(`Unexpected emitterChain ${vaa.emitterChain}`)
    }
    if (vaa.emitterAddress !== this.config.sourceBridgeAddress) {
      throw new Error(`Unexpected emitterAddress ${vaa.emitterAddress}`)
    }

    // re-encode VAA as hex string expected by contract
    const encodedVaaHex = ethers.utils.hexlify(vaaBytes)

    // submit to WormholeReceiver on target chain
    const tx = await this.receiver.receiveAndExecuteVAA(encodedVaaHex)
    console.log(`🔗 Submitted VAA to receiver, tx=${tx.hash}`)
    await tx.wait()
    console.log(`✅ VAA processed in block ${tx.blockNumber}`)
    return tx
  }
}
