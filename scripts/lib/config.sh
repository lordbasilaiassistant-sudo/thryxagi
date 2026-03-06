#!/usr/bin/env bash
# Load state/config.json values into shell variables.
# Source this: . scripts/lib/config.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_DIR="$PROJECT_ROOT/state"
CONFIG="$STATE_DIR/config.json"

RPC=$(jq -r '.chain.rpc' "$CONFIG")
CHAIN_ID=$(jq -r '.chain.chainId' "$CONFIG")
EXPLORER=$(jq -r '.chain.explorer' "$CONFIG")
DEPLOYER=$(jq -r '.deployer' "$CONFIG")
OBSD_TOKEN=$(jq -r '.obsd.token' "$CONFIG")
OBSD_ROUTER=$(jq -r '.obsd.router' "$CONFIG")
AERO_POOL=$(jq -r '.obsd.aeroPool' "$CONFIG")
FOUNDRY_BIN=$(jq -r '.foundryBin' "$CONFIG")

export PATH="$PATH:$FOUNDRY_BIN"
