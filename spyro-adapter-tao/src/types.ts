// SPDX-License-Identifier: MIT
// AssemblyScript entity classes for TAO/Bittensor adapter
// -------------------------------------------------------

export class Provider {
  id!: string;             // "tao:<nodeId>"
  network!: string;        // "Tao"
  stake!: u64;             // self-stake in TAO tokens
  reputation!: f32;        // 0.0 – 1.0 (derived from score/10000)
}

export class Model {
  id!: string;             // "tao:<modelHash>"
  provider!: string;       // FK → Provider.id
  currentVersion!: string; // semantic version string
  params!: u64;            // number of trainable parameters
}

export class InferenceJob {
  id!: string;             // tx.hash
  model!: string;          // FK → Model.id
  requester!: Bytes;       // EVM address or substrate pubkey
  inputHash!: Bytes;       // keccak256 of serialized input
  latency!: i32;           // seconds
  cost!: BigInt;           // TAO paid
  blockTimestamp!: i64;    // unix epoch seconds
}

export class ScoreUpdate {
  id!: string;             // `${modelId}:${blockNumber}`
  model!: string;          // FK → Model.id
  provider!: string;       // FK → Provider.id
  newScore!: u32;          // 0-10000
  reputation!: f32;        // cached reputationFromScore(newScore)
  blockNumber!: i64;
  blockTimestamp!: i64;
}
