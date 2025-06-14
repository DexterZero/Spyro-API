#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Spyro Hardhat Service Entrypoint
# -----------------------------------------------------------------------------
# 1. Starts a Hardhat JSON‑RPC node listening on 0.0.0.0:8545 so that other
#    containers in the devnet (spyro-node, SDK tests, etc.) can connect.
# 2. Waits briefly for the chain to boot, then runs the deployAll.ts script
#    inside spyro-contracts to deploy the entire Spyro contract...
