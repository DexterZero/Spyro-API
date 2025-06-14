// SPDX-License-Identifier: Apache-2.0
//! Spyro‑Node Schema Helpers
//! -------------------------
//! Contains strongly‑typed Rust representations of the AI‑Graph entity
//! schema (`Provider`, `Model`, `InferenceJob`, etc.) plus convenience
//! functions to map them to the Graph‑Node entity API.

use serde::{Deserialize, Serialize};
use graph::data::store::scalar::Bytes;
use graph::prelude::{Entity, EntityKey, Value, ValueType};

/* -----------------------------------------------------------
   ENTITY DEFINITIONS (mirrors schema.graphql in curation repo)
   ----------------------------------------------------------- */

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Provider {
    pub id: String,             // e.g. "render:node-42"
    pub network: String,        // Render | TAO | Fetch
    pub stake: i128,
    pub reputation: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Model {
    pub id: String,             // e.g. "render:stable-diffusion"
    pub provider: String,
    pub current_version: String,
    pub params: i64,
    pub license: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InferenceJob {
    pub id: Bytes,              // tx hash
    pub model: String,
    pub requester: Bytes,
    pub input_hash: Bytes,
    pub latency: i32,
    pub cost: i128,
    pub block_timestamp: i64,
}

/* -----------------------------------------------------------
   CONVERSION HELPERS → graph::prelude::Entity
   ----------------------------------------------------------- */

impl From<Provider> for Entity {
    fn from(p: Provider) -> Self {
        let mut e = Entity::new();
        e.insert("id", Value::String(p.id));
        e.insert("network", Value::String(p.network));
        e.insert("stake", Value::BigInt(p.stake.into()));
        e.insert("reputation", Value::BigDecimal(p.reputation.into()));
        e
    }
}

impl From<Model> for Entity {
    fn from(m: Model) -> Self {
        let mut e = Entity::new();
        e.insert("id", Value::String(m.id));
        e.insert("provider", Value::String(m.provider));
        e.insert("currentVersion", Value::String(m.current_version));
        e.insert("params", Value::BigInt(m.params.into()));
        e.insert("license", Value::String(m.license));
        e
    }
}

impl From<InferenceJob> for Entity {
    fn from(j: InferenceJob) -> Self {
        let mut e = Entity::new();
        e.insert("id", Value::Bytes(j.id));
        e.insert("model", Value::String(j.model));
        e.insert("requester", Value::Bytes(j.requester));
        e.insert("inputHash", Value::Bytes(j.input_hash));
        e.insert("latency", Value::Int(j.latency));
        e.insert("cost", Value::BigInt(j.cost.into()));
        e.insert("blockTimestamp", Value::BigInt(j.block_timestamp.into()));
        e
    }
}

/* -----------------------------------------------------------
   ENTITY KEYS (used by store layer)
   ----------------------------------------------------------- */

pub fn provider_key(id: &str) -> EntityKey {
    EntityKey::data("Provider", id.to_owned())
}

pub fn model_key(id: &str) -> EntityKey {
    EntityKey::data("Model", id.to_owned())
}

pub fn job_key(id: &Bytes) -> EntityKey {
    EntityKey::data("InferenceJob", id.to_string())
}

/* -----------------------------------------------------------
   Type registry for Graph‑Node runtime (optional helper)
   ----------------------------------------------------------- */

pub fn register_types() -> Vec<(&'static str, Vec<(&'static str, ValueType)>)> {
    vec![
        (
            "Provider",
            vec![
                ("id", ValueType::String),
                ("network", ValueType::String),
                ("stake", ValueType::BigInt),
                ("reputation", ValueType::BigDecimal),
            ],
        ),
        (
            "Model",
            vec![
                ("id", ValueType::String),
                ("provider", ValueType::String),
                ("currentVersion", ValueType::String),
                ("params", ValueType::BigInt),
                ("license", ValueType::String),
            ],
        ),
        (
            "InferenceJob",
            vec![
                ("id", ValueType::Bytes),
                ("model", ValueType::String),
                ("requester", ValueType::Bytes),
                ("inputHash", ValueType::Bytes),
                ("latency", ValueType::Int),
                ("cost", ValueType::BigInt),
                ("blockTimestamp", ValueType::BigInt),
            ],
        ),
    ]
}
