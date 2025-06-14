// SPDX-License-Identifier: MIT
// -----------------------------------------------------------------------------
// spyro-sdk-js ▸ utils ▸ constants.ts
// -----------------------------------------------------------------------------
// Compile-time constants shared across the SDK.  Keep this file dependency-free
// so it can be tree-shaken when bundled in browsers.
// -----------------------------------------------------------------------------

/** Current SPY token decimals (18). */
export const SPY_DECIMALS = 18;

/** Delegation capacity multiple (16 × self-stake). */
export const DELEGATION_CAPACITY = 16;

/** Annual inflation rate (on-chain default = 3 %). */
export const ANNUAL_INFLATION = 0.03;

/** Curation bonding-curve deposit burn (2.5 %). */
export const CURATION_TAX = 0.025;

/** Migration tax when a model upgrades (1 %). */
export const MIGRATION_TAX = 0.01;

/** Default GraphQL endpoint path relative to node host. */
export const DEFAULT_GQL_PATH = "/graphql";

/** Default Prometheus metrics path. */
export const DEFAULT_METRICS_PATH = "/metrics";

/** Ethers.js – default polling interval (ms) for Provider. */
export const DEFAULT_ETHERS_POLL_MS = 12_000;

/** Human-readable short name for the current SDK version. Update on release. */
export const SDK_VERSION = "0.1.0";
