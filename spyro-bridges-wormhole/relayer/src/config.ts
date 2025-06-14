// SPDX-License-Identifier: MIT
// -----------------------------------------------------------------------------
// spyro-bridges-wormhole ▸ relayer/src/config.ts
// -----------------------------------------------------------------------------
// Configuration loader for the Wormhole relayer process.
// Supports CLI flags and environment variables (via dotenv).

import * as dotenv from 'dotenv'
import yargs from 'yargs'
import { hideBin } from 'yargs/helpers'

dotenv.config()

export interface RelayerConfig {
  /** Source chain JSON-RPC endpoint for Wormhole core */
  sourceRpc: string
  /** Target chain JSON-RPC endpoint for WormholeReceiver */
  targetRpc: string
  /** Wormhole emitter chain ID (source) */
  sourceChainId: number
  /** Wormhole emitter chain ID (target) */
  targetChainId:
