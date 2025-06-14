// tests/unit/mapping.test.ts
//
// Run with:  npm run test   (as-pect)
// ---------------------------------------------------------------------------

import {
  Bytes,
  BigInt,
  ethereum,
  test, assert,
  store,
} from "@graphprotocol/graph-ts";
import { handleProof } from "../../src/index";
import { Provider, Model, InferenceJob } from "../../src/types";

// ----------------------------------------------------------------------------
// Helper to build a mocked `ProofSubmitted` event equivalent
// ----------------------------------------------------------------------------
function createProofEvent(): ethereum.Event {
  let evt = changetype<ethereum.Event>(new ethereum.Event());
  evt.address = changetype<Bytes>(Bytes.fromHexString("0x000000000000000000000000000000000000render"));
  evt.block.number = BigInt.fromI32(123456);
  evt.block.timestamp = BigInt.fromI32(1_695_555_555);
  evt.transaction.hash = Bytes.fromHexString("0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef");
  evt.transaction.from = Bytes.fromHexString("0xbabe000000000000000000000000000000000000");

  // Construct params just like graph-cli ABI would
  const params: Array<ethereum.EventParam> = [
    new ethereum.EventParam("nodeId", ethereum.Value.fromUnsignedBigInt(BigInt.fromU32(42))),
    new ethereum.EventParam("modelHash", ethereum.Value.fromFixedBytes(Bytes.fromHexString("0x746573744d6f64656c"))), // "testModel"
    new ethereum.EventParam("modelVersion", ethereum.Value.fromString("v1")),
    new ethereum.EventParam("paramCount", ethereum.Value.fromUnsignedBigInt(BigInt.fromU32(900_000))),
    new ethereum.EventParam("stake", ethereum.Value.fromUnsignedBigInt(BigInt.fromU32(1_000_000))),
    new ethereum.EventParam("score", ethereum.Value.fromUnsignedBigInt(BigInt.fromU32(9876))),
    new ethereum.EventParam("latencySeconds", ethereum.Value.fromUnsignedBigInt(BigInt.fromU32(2))),
    new ethereum.EventParam("fee", ethereum.Value.fromSignedBigInt(BigInt.fromI32(5))),
    new ethereum.EventParam("inputHash", ethereum.Value.fromBytes(Bytes.fromHexString("0xfeedfacefeedfacefeedfacefeedfacefeedface")))
  ];
  evt.parameters = params;
  return evt;
}

// ----------------------------------------------------------------------------
// Tests
// ----------------------------------------------------------------------------
test("handleProof creates Provider, Model, InferenceJob", () => {
  const evt = createProofEvent();
  handleProof(evt as unknown as ProofSubmitted);

  // Provider assertions
  const provId = "render:0x2a"; // nodeId 42 in hex
  assert.entityExists("Provider", provId);
  const provider = store.get("Provider", provId) as Provider;
  assert.stringEquals(provider.getString("network"), "Render");
  assert.bigIntEquals(provider.getBigInt("stake"), BigInt.fromU32(1_000_000));

  // Model assertions
  const modelId = "render:0x746573744d6f64656c";
  assert.entityExists("Model", modelId);
  const model = store.get("Model", modelId) as Model;
  assert.i64Equals(model.getI64("params"), 900_000);

  // Job assertions
  const jobId = "0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef";
  assert.entityExists("InferenceJob", jobId);
  const job = store.get("InferenceJob", jobId) as InferenceJob;
  assert.i32Equals(job.getI32("latency"), 2);
});
