// SPDX-License-Identifier: MIT
// -----------------------------------------------------------------------------
// spyro-sdk-js ▸ contracts ▸ types.ts
// -----------------------------------------------------------------------------
// Re-export all TypeChain-generated contract typings so consumers can:
//
//   import { SpyroGovernor, StakeManager } from "spyro-sdk-js/dist/contracts/types";
//
// without having to know internal paths like
// node_modules/@typechain/ethers-v6/SpyroGovernor.ts
// -----------------------------------------------------------------------------

// Governance
export type { SpyroGovernor } from "./abis/typechain/SpyroGovernor";
export type { SpyroTimelockController } from "./abis/typechain/SpyroTimelockController";

// Staking & Delegation
export type { StakeManager } from "./abis/typechain/StakeManager";
export type { DelegationPool } from "./abis/typechain/DelegationPool";
export type { RewardsDistributor } from "./abis/typechain/RewardsDistributor";

// Curation
export type { Curation } from "./abis/typechain/Curation";

// Token
export type { SPYToken } from "./abis/typechain/SPYToken";

// Helper to make sure this barrel compiles even if consumers tree-shake
export interface __SpyroContractTypesLoaded { /* no-op */ }
