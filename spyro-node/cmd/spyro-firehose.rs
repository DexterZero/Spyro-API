// SPDX-License-Identifier: Apache-2.0
//! Spyro Firehose Ingestion Binary
//! --------------------------------
//! This companion binary connects to StreamingFast‑style Firehose endpoints
//! provided by Render, TAO/Bittensor, or Fetch.ai and dumps protobuf
//! `BlockStep` messages onto stdout or pipes them into Spyro‑Node via gRPC.
//! It is intentionally minimal so it can be run as a side‑car container
//! or standalone service.

use clap::Parser;
use futures_util::StreamExt;
use prost::Message;
use tonic::transport::Channel;
use tonic::Request;
use tracing::{error, info};

// ---- SF Firehose proto stubs (simplified) ----------------------------------
include!(concat!(env!("OUT_DIR"), "/sf.firehose.v2.rs"));
use sf_firehose::firehose_client::FirehoseClient;
use sf_firehose::{Request as FirehoseRequest, Response as FirehoseResponse};

// ---- CLI -------------------------------------------------------------------
#[derive(Parser, Debug)]
#[command(author, version, about = "Spyro Firehose client")]
struct Opts {
    /// gRPC endpoint of the Firehose server.
    #[arg(long, default_value = "https://render.firehose.mainnet/")]
    endpoint: String,

    /// Block range start (inclusive)
    #[arg(long, default_value_t = 0)]
    start_block: u64,

    /// Block range stop (exclusive, 0 means stream‑forever)
    #[arg(long, default_value_t = 0)]
    stop_block: u64,

    /// Cursor to resume from (optional)
    #[arg(long)]
    cursor: Option<String>,

    /// Print raw bytes instead of JSON debug
    #[arg(long)]
    raw: bool,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt::init();

    let opts = Opts::parse();
    info!("Connecting to Firehose: {}", opts.endpoint);

    let mut client = FirehoseClient::connect(opts.endpoint.clone()).await?;

    let request = FirehoseRequest {
        start_block_num: opts.start_block as i64,
        stop_block_num: opts.stop_block as u64,
        fork_steps: vec![0, 1], // STEP_NEW, STEP_UNDO
        cursor: opts.cursor.unwrap_or_default(),
        ..Default::default()
    };

    let mut stream = client
        .blocks(Request::new(request))
        .await?
        .into_inner();

    while let Some(result) = stream.next().await {
        match result {
            Ok(FirehoseResponse { step, block, .. }) => {
                if opts.raw {
                    let bytes = block.encode_to_vec();
                    println!("{}", base64::encode(bytes));
                } else {
                    println!("STEP {step:?} block #{} txs:{}", block.number, block.transactions.len());
                }
            }
            Err(e) => error!("Firehose stream error: {e}")?,
        }
    }

    Ok(())
}
