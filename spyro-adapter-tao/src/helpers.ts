// Helper utilities for the TAO / Bittensor AssemblyScript mapping
// ---------------------------------------------------------------
// NOTE: All helpers must remain *pure* and deterministic so the
// mapping can be safely re‑executed by Spyro‑Node.

import {
  Bytes,
  BigInt,
  BigDecimal,
  crypto,
  log,
} from "@graphprotocol/graph-ts";

/**
 * Convert a `0x…` hex string into AssemblyScript `Bytes`.
 * Reverts if the string is not valid hex.
 */
export function bytesFromHex(hex: string): Bytes {
  if (!hex.startsWith("0x")) hex = "0x" + hex;
  const b = Bytes.fromHexString(hex);
  if (b.byteLength == 0) {
    log.critical("bytesFromHex: invalid hex string {}", [hex]);
    assert(false);
  }
  return b;
}

/**
 * Take a UTF‑8 string → keccak256 → `Bytes` (32‑byte hash).
 */
export function keccak256String(s: string): Bytes {
  return Bytes.fromByteArray(crypto.keccak256(ByteArray.fromUTF8(s)));
}

/**
 * Convenience: BigInt from u64 literal (saves verbose casting in mapping).
 */
export function bigIntFromU64(v: u64): BigInt {
  return BigInt.fromUnsignedBytesBigEndian(Bytes.fromUint64(v));
}

/**
 * Map a raw TAO *model score* (0‑10_000) to a 0‑1 `BigDecimal` reputation.
 */
export function reputationFromScore(score: u32): BigDecimal {
  return BigDecimal.fromString(score.toString()).div(BigDecimal.fromString("10000"));
}

/**
 * Deterministic assert – mirrors the `assert` builtin but logs first.
 */
export function assertDeterministic(cond: bool, msg: string): void {
  if (!cond) {
    log.critical("deterministic assert failed: {}", [msg]);
    assert(false);
  }
}
