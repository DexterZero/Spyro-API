// SPDX-License-Identifier: Apache-2.0
//! Spyro Ingest Layer
//! ------------------
//! Abstractions and default implementations for pulling data from AI
//! providers (Render Network, TAO/Bittensor, Fetch.ai) and normalising them
//! into Spyro‑Node’s internal `BlockStream` so the rest of the Graph‑Node
//! pipeline can treat them like chain events.
//!
//! Provider‑specific crates implement the `ProviderIngest` trait below and
//! register themselves in `cmd/spyro-node.rs`.

use std::time::Duration;
use async_trait::async_trait;
use tokio_stream::{Stream, StreamExt};
use tracing::{info, warn, error};
use anyhow::Result;

/// Normalised event passed to the mapper.
#[derive(Clone, Debug)]
pub enum IngestEvent {
    /// Model metadata or version update
    ModelMeta {
        provider: String,
        model_id: String,
        version: String,
        params: u64,
        timestamp: u64,
    },
    /// Inference job completion / KPI
    InferenceJob {
        provider: String,
        job_id: String,
        latency_ms: u32,
        cost_wei: u128,
        success: bool,
        timestamp: u64,
    },
    /// Provider heartbeat / stats
    ProviderStats {
        provider: String,
        node_id: String,
        gpu_util: u8,
        score: u32,
        timestamp: u64,
    },
}

/// Trait every provider‑specific ingest adaptor must implement.
#[async_trait]
pub trait ProviderIngest: Send + Sync + 'static {
    /// A unique name (e.g. "Render" / "TAO" / "Fetch")
    fn id(&self) -> &'static str;

    /// Stream of normalised events for this provider.
    async fn stream(&self) -> Result<Box<dyn Stream<Item = IngestEvent> + Send + Unpin>>;
}

/// Utility that wraps a provider stream and restarts it on failure with back‑off.
/// Returns a fused stream of events that never terminates unless the containing
/// task is cancelled.
pub async fn resilient_stream<P: ProviderIngest>(provider: P) -> impl Stream<Item = IngestEvent> {
    let mut backoff = Duration::from_secs(1);
    let max_backoff = Duration::from_secs(30);

    tokio_stream::unfold((), move |_| async {
        loop {
            match provider.stream().await {
                Ok(mut s) => {
                    while let Some(evt) = s.next().await {
                        return Some((evt, ()))
                    }
                    warn!(provider = provider.id(), "stream ended unexpectedly; reconnecting");
                }
                Err(e) => error!(provider = provider.id(), err = %e, "stream error; reconnecting"),
            }
            tokio::time::sleep(backoff).await;
            backoff = (backoff * 2).min(max_backoff);
        }
    })
}
