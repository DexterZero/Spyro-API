// SPDX-License-Identifier: Apache-2.0
//! Spyro‑Node Metrics
//! ------------------
//! Centralised Prometheus metric registry so every subsystem (ingest, mapper,
//! store, GraphQL) can register counters/gauges/histograms without fighting
//! over static globals.

use once_cell::sync::Lazy;
use prometheus::{self, Encoder, IntCounterVec, IntGaugeVec, TextEncoder};
use std::net::{IpAddr, I...
