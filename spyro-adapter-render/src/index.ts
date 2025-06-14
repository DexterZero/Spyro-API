import {
  Bytes, BigInt, log, store,
} from "@graphprotocol/graph-ts";
import { ProofSubmitted } from "../generated/RenderProofs/RenderProofs";
import { Provider, Model, InferenceJob } from "./types";

export function handleProof(evt: ProofSubmitted): void {
  const provId = `render:${evt.params.nodeId.toHex()}`;
  let provider = Provider.load(provId);
  if (provider == null) {
    provider = new Provider(provId);
    provider.network = "Render";
    provider.stake = evt.params.stake;
  }
  provider.reputation = evt.params.score.toF32() / 100.0;
  provider.save();

  const modelId = `render:${evt.params.modelHash}`;
  let model = Model.load(modelId);
  if (model == null) {
    model = new Model(modelId);
    model.provider = provider.id;
  }
  model.currentVersion = evt.params.modelVersion;
  model.params = evt.params.paramCount;
  model.save();

  const job = new InferenceJob(evt.transaction.hash.toHex());
  job.model = model.id;
  job.requester = evt.transaction.from;
  job.inputHash = evt.params.inputHash;
  job.latency = evt.params.latencySeconds;
  job.cost = evt.params.fee;
  job.blockTimestamp = evt.block.timestamp;
  job.save();

  log.debug("Handled proof for model {} by node {}", [modelId, provId]);
}
