// src/bin/spyro-node.rs or cmd/spyro-node.rs depending on workspace
// SPDX-License-Identifier: Apache-2.0
//
// ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
// ┃  Spyro‑Node – Main binary                                             ┃
// ┃                                                                       ┃
// ┃  A thin wrapper around Graph‑Node’s Components to ingest AI‑Graph     ┃
// ┃  provider streams (Render, TAO, Fetch) and expose the GraphQL query   ┃
// ┃  service.  Keeps CLI flags identical to graph‑node for familiarity.   ┃
// ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

use clap::Parser;
use std::path::PathBuf;
use tracing::{info, warn};
use tracing_subscriber::prelude::*;

mod ingest;   // Render/TAO/Fetch adapters → EntityStore
mod metrics;  // Prometheus exporter
mod schema;   // AI‑Graph schema helpers
mod mapper;   // WASM mapping runtime

/// Command‑line arguments (subset of graph‑node’s CLI)
#[derive(Debug, Parser)]
#[command(name = "spyro-node", version, about = "Spyro AI‑Graph indexer node")]
struct Cli {
    /// Postgres database URL (same format as graph‑node)
    #[arg(long, env = "POSTGRES_URL")]
    postgres_url: String,

    /// IP / port to bind GraphQL HTTP server
    #[arg(long, default_value = "0.0.0.0:8000")]
    http_addr: String,

    /// Path(s) to configuration files (spyro.toml, chains/*.yaml)
    #[arg(long, value_name = "FILE")] 
    config: Vec<PathBuf>,

    /// Increase verbosity (-v, -vv, -vvv)
    #[arg(short, long, action = clap::ArgAction::Count)]
    verbose: u8,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // ── CLI & logging ─────────────────────────────────────────────
    let cli = Cli::parse();
    init_tracing(cli.verbose);

    info!("🚀 Spyro‑Node starting‥");
    info!("postgres = {}", cli.postgres_url);
    info!(http = %cli.http_addr);

    // ── Load config -------------------------------------------------
    let cfg = ingest::load_config(cli.config)?;

    // ── Start Prometheus metrics -----------------------------------
    let (_metrics_srv, registry) = metrics::serve("0.0.0.0:8040").await?;
    info!("prometheus = 0.0.0.0:8040");

    // ── Initialise store + runtime ---------------------------------
    let store = schema::init_store(&cli.postgres_url).await?;
    let mapper_rt = mapper::MapperRuntime::new(store.clone());

    // ── Firehose / stream ingestion --------------------------------
    let ingest_handles = ingest::spawn_all_sources(cfg, store.clone()).await?;

    // ── GraphQL query server ---------------------------------------
    let gql_srv = schema::start_graphql_server(store, &cli.http_addr, registry).await?;

    // ── Await shutdown ---------------------------------------------
    futures::future::join_all(ingest_handles).await;
    gql_srv.await?;

    Ok(())
}

fn init_tracing(verbosity: u8) {
    let lvl = match verbosity {
        0 => tracing::Level::INFO,
        1 => tracing::Level::DEBUG,
        _ => tracing::Level::TRACE,
    };
    tracing_subscriber::fmt()
        .with_max_level(lvl)
        .with_target(false)
        .init();
}
