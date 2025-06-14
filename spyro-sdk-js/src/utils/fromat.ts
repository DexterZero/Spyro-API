// SPDX-License-Identifier: MIT
// -----------------------------------------------------------------------------
// spyro-sdk-js ▸ utils ▸ format.ts
// -----------------------------------------------------------------------------
// Human‑readable format helpers – convert BigInt / BigNumber values returned
// by on‑chain contracts into strings suitable for UI display, taking SPY
// decimals into account.  These functions have **no external dependencies**
// so the SDK stays lightweight and tree‑shakeable.
// -----------------------------------------------------------------------------

import { formatUnits } from "ethers";
import { SPY_DECIMALS } from "./constants";

/**
 * Format a SPY token amount (18‑dec BigInt) to a fixed‑precision string.
 * If `precision` not provided, defaults to 4 decimal places, trimming
 * trailing zeros. E.g.  `formatSPY(123_450_000_000_000_000_000n)` → "123.45".
 */
export function formatSPY(value: bigint, precision: number = 4): string {
  const raw = formatUnits(value, SPY_DECIMALS);
  return trimDecimals(raw, precision);
}

/**
 * Trim a decimal string to `precision` places without rounding errors and
 * strip trailing zeros / trailing dot.
 */
export function trimDecimals(raw: string, precision: number): string {
  const [intPart, fracPart = ""] = raw.split(".");
  if (precision === 0 || fracPart.length === 0) return intPart;
  const trimmed = fracPart.slice(0, precision).replace(/0+$/, "");
  return trimmed.length > 0 ? `${intPart}.${trimmed}` : intPart;
}

/**
 * Shorten an Ethereum address:  `0xAbc…1234`.
 */
export function shortAddress(addr: string, chars: number = 4): string {
  return addr.slice(0, 2 + chars) + "…" + addr.slice(-chars);
}

/**
 * Format a `Date` (or seconds since epoch) to ISO string w/o milliseconds.
 */
export function isoTime(ts: number | Date): string {
  const d = ts instanceof Date ? ts : new Date(ts * 1000);
  return d.toISOString().replace(/\.\d{3}Z$/, "Z");
}
