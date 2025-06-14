// AssemblyScript types mirroring schema.graphql
export class Provider {
  id!: string;
  network!: string;   // "Render"
  stake!: u64;
  reputation!: f32;
}

export class Model {
  id!: string;
  provider!: string;
  currentVersion!: string;
  params!: u64;
}

export class InferenceJob {
  id!: string;
  model!: string;
  requester!: Bytes;
  inputHash!: Bytes;
  latency!: i32;
  cost!: BigInt;
  blockTimestamp!: i64;
}
