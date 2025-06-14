// AssemblyScript helpers for Spyro Render adapter
// -----------------------------------------------
// These are **deterministic** (pure) helper functions that can be used from
// within the WASM mapping without pulling in @graphprotocol/graph-ts heavy
// utils every time.  Keep them `@inline`‑able and avoid dynamic allocation
// where possible.

import {
  Bytes,
  crypto,
  BigInt,
} from "@graphprotocol/graph-ts";

/**
 * Converts a hex string (with or without 0x) to `Bytes`.
 * Returns zero‑length Bytes on malformed input – caller may handle.
 */
export function hexToBytes(hex: string): Bytes {
  let clean = hex.startsWith("0x") ? hex.substr(2) : hex;
  if (clean.length % 2 != 0) clean = "0" + clean; // pad
  const out = new Uint8Array(clean.length / 2);
  for (let i = 0; i < clean.length; i += 2) {
    const byte = I32.parseInt(clean.substr(i, 2), 16);
    out[i / 2] = byte as u8;
  }
  return Bytes.fromUint8Array(out);
}

/**
 * Cheap keccak256 helper that returns a hex string.
 */
export function keccakHex(data: Bytes): string {
  const hash = crypto.keccak256(data);
  return "0x" + hash.toHexString().substr(2);
}

/**
 * Fixed‑point conversion (wei → ether) in 18‑dec format as string.
 * Avoids floating‑point ops for determinism.
 */
export function weiToEther(wei: BigInt): string {
  const divisor = BigInt.fromI32(10).pow(18 as u8);
  const whole = wei.div(divisor);
  const frac = wei.mod(divisor);
  const fracStr = frac.toString().padStart(18, "0");
  return whole.toString() + "." + fracStr;
}

/**
 * Rounds latency seconds to nearest millisecond for easier Prom metrics.
 */
export function secToMillis(latencySec: i32): i32 {
  return latencySec * 1000;
}
