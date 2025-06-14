// SPDX-License-Identifier: MIT
// tests/unit/mapping.test.ts
//
// Run with:  npm test        (as-pect)
//
// Calls the AssemblyScript handlers and checks that Provider, Model,
// InferenceJob, and ScoreUpdate entities are written correctly.

import {
  test,
  assert,
  store,
  Bytes,
  BigInt,
  BigDecimal,
  ethereum,
} from "@graphprotocol/graph-ts";

import { handleServe, handleScoreUpdate } from "../../src/index";
import { Provider, Model, InferenceJob, ScoreUpdate } from "../../src/types";

// ────────────────────────────────────────────────────────────────────────────
// Helpers to build mocked TAO events
// ────────────────────────────────────────────────────────────────────────────

function mockServeEvent(): ethereum.Event {
  const e = changetype<ethereum.Event>(new ethereum.Event());

  e.address        = Bytes.fromHexString("0x000000000000000000000000000000000000tao");
  e.block.number   = BigInt.fromI32(555_555);
  e.block.timestamp= BigInt.fromI32(1_700_000_001);
  e.transaction.hash = Bytes.fromHexString(
    "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  );
  e.transaction.from = Bytes.fromHexString(
    "0xca11ba5eba11ba5eba11ba5eba11ba5eba11ba5e"
  );

  e.parameters = [
    new ethereum.EventParam(
      "nodeId",
      ethereum.Value.fromUnsignedBigInt(BigInt.fromU32(21))
    ),
    new ethereum.EventParam(
      "modelHash",
      ethereum.Value.fromFixedBytes(Bytes.fromHexString("0x6d6f64656c54616f")) // "modelTao"
    ),
    new ethereum.EventParam(
      "modelVersion",
      ethereum.Value.fromString("v2")
    ),
    new ethereum.EventParam(
      "paramCount",
      ethereum.Value.fromUnsignedBigInt(BigInt.fromU32(450_000))
    ),
    new ethereum.EventParam(
      "latencySeconds",
      ethereum.Value.fromUnsignedBigInt(BigInt.fromU32(3))
    ),
    new ethereum.EventParam(
      "fee",
      ethereum.Value.fromUnsignedBigInt(BigInt.fromU32(17))
    ),
    new ethereum.EventParam(
      "inputHash",
      ethereum.Value.fromFixedBytes(Bytes.fromHexString("0xfeedfeedfeedfeedfeedfeedfeedfeedfeedfeed"))
    ),
  ];
  return e;
}

function mockScoreEvent(): ethereum.Event {
  const e = changetype<ethereum.Event>(new ethereum.Event());

  e.address        = Bytes.fromHexString("0x000000000000000000000000000000000000tao");
  e.block.number   = BigInt.fromI32(555_560);
  e.block.timestamp= BigInt.fromI32(1_700_000_100);

  e.parameters = [
    new ethereum.EventParam(
      "nodeId",
      ethereum.Value.fromUnsignedBigInt(BigInt.fromU32(21))
    ),
    new ethereum.EventParam(
      "modelHash",
      ethereum.Value.fromFixedBytes(Bytes.fromHexString("0x6d6f64656c54616f"))
    ),
    new ethereum.EventParam(
      "newScore",
      ethereum.Value.fromUnsignedBigInt(BigInt.fromU32(8765))
    ),
  ];
  return e;
}

// ────────────────────────────────────────────────────────────────────────────
// Tests
// ────────────────────────────────────────────────────────────────────────────

test("handleServe creates Provider, Model and InferenceJob", () => {
  const evt = mockServeEvent();
  handleServe(evt as unknown as ServeEvent);

  const provId  = "tao:0x15";                    // nodeId 21
  const modelId = "tao:0x6d6f64656c54616f";
  const jobId   = "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";

  assert.entityExists("Provider", provId);
  assert.entityExists("Model", modelId);
  assert.entityExists("InferenceJob", jobId);

  const p = store.get("Provider", provId) as Provider;
  assert.stringEquals(p.getString("network"), "Tao");

  const m = store.get("Model", modelId) as Model;
  assert.stringEquals(m.getString("currentVersion"), "v2");
});

test("handleScoreUpdate writes ScoreUpdate and updates Provider reputation", () => {
  const evtScore = mockScoreEvent();
  handleScoreUpdate(evtScore as unknown as ModelScoreUpdate);

  const scoreId = "tao:0x6d6f64656c54616f:555560";
  assert.entityExists("ScoreUpdate", scoreId);

  const su = store.get("ScoreUpdate", scoreId) as ScoreUpdate;
  assert.i64Equals(su.getI64("blockNumber"), 555_560);

  // Provider reputation should now equal 0.8765
  const provId = "tao:0x15";
  const p = store.get("Provider", provId) as Provider;
  assert.bigDecimalEquals(
    p.getBigDecimal("reputation"),
    BigDecimal.fromString("0.8765")
  );
});
