#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  Spyro‑Node Docker Entrypoint
# ---------------------------------------------------------------------------
#  Responsibilities
#    • Creates a writable config dir (if mounted read‑only)
#    • Expands simple env‑var tokens in spyro.toml      (e.g. $POSTGRES_URL)
#    • Runs migrations (graph‑node) when POSTGRES_MIGRATE=true
#    • Launches spyro‑node with all CLI flags forwarded
#    • Handles graceful shutdown on SIGTERM/SIGINT
# ---------------------------------------------------------------------------
set -euo pipefail

CONFIG_PATH=${CONFIG_PATH:-/app/config/spyro.toml}
MIGRATE=${POSTGRES_MIGRATE:-false}

# --- token replacement -----------------------------------------------------
# Allows docker‑compose to set POSTGRES_URL, IPFS_ENDPOINT etc via env vars
if grep -q "\$POSTGRES_URL" "$CONFIG_PATH"; then
  echo "🛠  Expanding env vars in config…"
  envsubst < "$CONFIG_PATH" > /tmp/spyro.toml
  CONFIG_PATH=/tmp/spyro.toml
fi

# --- optional DB migrations ------------------------------------------------
if [[ "$MIGRATE" == "true" ]]; then
  echo "📦  Running Postgres migrations…"
  graph-node --postgres-url "$POSTGRES_URL" --config "$CONFIG_PATH" --exit-after-startup
fi

# --- graceful shutdown trap -----------------------------------------------
_term() {
  echo "🛑  Caught SIGTERM, shutting down spyro-node…" >&2
  kill -TERM "$child" 2>/dev/null
}
trap _term SIGTERM SIGINT

# --- launch spyro-node -----------------------------------------------------
spyro-node --config "$CONFIG_PATH" "$@" &
child=$!
wait "$child"
