// SPDX-License-Identifier: Apache-2.0
//! Spyro Mapping Engine
//! --------------------
//! Transforms raw `IngestEvent`s emitted by the provider‑specific ingest
//! layer into Graph‑Node `EntityModification`s by executing deterministic
//! WASM mapping modules compiled from TypeScript adapters (see
//! `render-adapter`, `tao-adapter`, etc.).
//!
//! This mirrors The Graph’s AssemblyScript mapping runtime but uses
//! `wasmtime` for execution, allowing us to compile adapters from Rust or
//! TypeScript alike.

use std::sync::Arc;
use anyhow::Result;
use graph::prelude::{BlockPtr, EntityModification, HostMetrics, Logger};
use wasmtime::{Engine, Module, Store, Instance, Extern};
use crate::ingest::IngestEvent;
use crate::schema::{IntoEntity, Provider, Model, InferenceJob};

/*──────────────────────────────────────────────────────────────────────────*/
/*  MappingContext                                                         */
/*──────────────────────────────────────────────────────────────────────────*/

/// Holds shared components needed by every WASM instance.
#[derive(Clone)]
pub struct MappingContext {
    pub logger: Logger,
    pub engine: Engine,
    pub host_metrics: Arc<HostMetrics>,
}

/*──────────────────────────────────────────────────────────────────────────*/
/*  Mapper trait                                                           */
/*──────────────────────────────────────────────────────────────────────────*/

pub trait Mapper: Send + Sync + 'static {
    /// Load the WASM module and return a ready‑to‑run instance.
    fn instantiate(&self, ctx: &MappingContext) -> Result<Instance>;

    /// Given an `IngestEvent`, produce entity modifications suitable for
    /// insertion into the store.
    fn handle_event(&self, evt: IngestEvent, ptr: BlockPtr) -> Result<Vec<EntityModification>>;
}

/*──────────────────────────────────────────────────────────────────────────*/
/*  DefaultMapper – executes compiled WASM adapters                        */
/*──────────────────────────────────────────────────────────────────────────*/

pub struct DefaultMapper {
    module: Module,
}

impl DefaultMapper {
    pub fn new(wasm_bytes: &[u8], ctx: &MappingContext) -> Result<Self> {
        Ok(Self { module: Module::from_binary(&ctx.engine, wasm_bytes)? })
    }
}

impl Mapper for DefaultMapper {
    fn instantiate(&self, ctx: &MappingContext) -> Result<Instance> {
        let mut store = Store::new(&ctx.engine, ());
        Ok(Instance::new(&mut store, &self.module, &[])? )
    }

    fn handle_event(&self, evt: IngestEvent, ptr: BlockPtr) -> Result<Vec<EntityModification>> {
        // Minimal PoC: map JSON directly without executing WASM.
        // Real implementation would call exported WASM fn like `handle_event`.
        match evt {
            IngestEvent::Render { payload, .. } => {
                let provider: Provider = serde_json::from_value(payload)?;
                Ok(vec![provider.into_entity_mod(ptr)?])
            }
            IngestEvent::Tao { payload, .. } => {
                let model: Model = serde_json::from_value(payload)?;
                Ok(vec![model.into_entity_mod(ptr)?])
            }
            IngestEvent::Fetch { payload, .. } => {
                let job: InferenceJob = serde_json::from_value(payload)?;
                Ok(vec![job.into_entity_mod(ptr)?])
            }
            _ => Ok(vec![]),
        }
    }
}

/*──────────────────────────────────────────────────────────────────────────*/
/*  Helper extension trait                                                 */
/*──────────────────────────────────────────────────────────────────────────*/

trait IntoEntityMod {
    fn into_entity_mod(self, ptr: BlockPtr) -> Result<EntityModification>;
}

impl<T> IntoEntityMod for T
where
    T: IntoEntity,
{
    fn into_entity_mod(self, ptr: BlockPtr) -> Result<EntityModification> {
        let (key, data) = self.into_entity();
        Ok(EntityModification::Insert { key, data, block_ptr: ptr })
    }
}
