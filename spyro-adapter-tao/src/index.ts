/**
 * Spyro‑Adapter‑TAO – AssemblyScript mapping entry point
 * ------------------------------------------------------
 * Compiled to WASM via `graph-cli build`.  Spyro‑Node loads the resulting
 * `adapter.wasm` and calls these handlers for every TAO / Bittensor event.
 *
 * Event bindings (`ServeEvent`, `ModelScoreUpdate`) are auto‑generated from
 * `abis/TaoBridge.json` (if ingesting via EVM bridge) *or*
 * Firehose proto definitions.  Replace the import path below with your own
 * `generated/*` output once `graph-cli codegen` runs.
 */

import {
  BigInt,
  Bytes,
  crypto,
  log,
  store,
} from "@graphprotocol/graph-ts";

// ---- generated ABI / proto bindings ---------------------------------------
// These will exist after running graph-cli codegen.  Keep placeholder types
// here so TypeScript compiler passes when the file is first created.
class ServeEvent {
  params!: {
    nodeId: BigInt;
    modelHash: Bytes;
    version: string;
    latency: BigInt; // sec
    fee: BigInt;
    txHash: Bytes;
  };
  block!: { timestamp: BigInt };
  transaction!: { from: Bytes; hash: Bytes };
}
class ModelScoreUpdate {
  params!: {
    modelHash: Bytes;
    newScore: BigInt;
  };
}

// ---- local entity definitions (must mirror schema.graphql) ----------------
class Provider {
  id: string;
  network: string;
  reputation: f32;
  constructor(id: string) {
    this.id = id;
  }
  save(): void {
    store.set("Provider", this.id, this);
  }
  static load(id: string): Provider | null {
    return changetype<Provider | null>(store.get("Provider", id));
  }
}
class Model {
  id: string;
  provider: string;
  currentVersion: string;
  score: BigInt;
  constructor(id: string) {
    this.id = id;
  }
  save(): void {
    store.set("Model", this.id, this);
  }
  static load(id: string): Model | null {
    return changetype<Model | null>(store.get("Model", id));
  }
}
class InferenceJob {
  id: string;
  model: string;
  requester: Bytes;
  latency: i32;
  cost: BigInt;
  blockTimestamp: BigInt;
  constructor(id: string) {
    this.id = id;
  }
  save(): void {
    store.set("InferenceJob", this.id, this);
  }
}

// ----------------------------------------------------------------------------
// Handler: ServeEvent (model inference served by TAO miner)
// ----------------------------------------------------------------------------
export function handleServe(evt: ServeEvent): void {
  const provId = `tao:${evt.params.nodeId.toHex()}`;
  let provider = Provider.load(provId);
  if (provider == null) {
    provider = new Provider(provId);
    provider.network = "TAO";
    provider.reputation = 0.0;
  }
  provider.save();

  const modelId = `tao:${evt.params.modelHash.toHex()}`;
  let model = Model.load(modelId);
  if (model == null) {
    model = new Model(modelId);
    model.provider = provider.id;
    model.score = BigInt.fromI32(0);
  }
  model.currentVersion = evt.params.version;
  model.save();

  const jobId = evt.params.txHash.toHex();
  const job = new InferenceJob(jobId);
  job.model = model.id;
  job.requester = evt.transaction.from;
  job.latency = evt.params.latency.toI32();
  job.cost = evt.params.fee;
  job.blockTimestamp = evt.block.timestamp;
  job.save();

  log.debug("ServeEvent processed for model {} by node {}", [modelId, provId]);
}

// ----------------------------------------------------------------------------
// Handler: ModelScoreUpdate (periodic quality update emitted by TAO chain)
// ----------------------------------------------------------------------------
export function handleScore(evt: ModelScoreUpdate): void {
  const modelId = `tao:${evt.params.modelHash.toHex()}`;
  let model = Model.load(modelId);
  if (model == null) {
    log.warning("ScoreUpdate for
