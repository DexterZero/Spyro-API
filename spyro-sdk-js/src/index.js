// SPDX-License-Identifier: MIT
// ------------------------------------------------------------
// Spyro‑SDK Barrel File
// ------------------------------------------------------------
// This file re‑exports the public surface area of the SDK so
// consumers can simply `import { SpyroClient } from "spyro-sdk"`.
// Everything re‑exported here is considered **stable API**.
// ------------------------------------------------------------

/* High‑level client ------------------------------------------------------ */
export { SpyroClient, SpyroClientOptions } from "./client";
export default SpyroClient;

/* Contract wrappers ------------------------------------------------------ */
// Ethers‑v6 factories & typed interfaces auto‑generated via TypeChain.
// Consumers can import specific contracts if they need lower‑level access.
export * as Contracts from "./contracts";

/* GraphQL helpers -------------------------------------------------------- */
export * as GQL from "./graphql/queries";

/* Utility helpers -------------------------------------------------------- */
export { getAddresses, SpyroAddresses } from "./utils/addresses";
export * as Constants from "./utils/constants";
export { formatToken, formatPercent } from "./utils/format";
export * as SpyroErrors from "./utils/errors";
