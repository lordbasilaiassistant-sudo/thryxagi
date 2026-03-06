#!/usr/bin/env bash
# Load state/config.json values into shell variables.
# Source this: . scripts/lib/config.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_DIR="$PROJECT_ROOT/state"
CONFIG="$STATE_DIR/config.json"

# Set PATH first — jq and foundry may not be in default PATH on Windows
JQ_WINGET="/c/Users/drlor/AppData/Local/Microsoft/WinGet/Packages/jqlang.jq_Microsoft.Winget.Source_8wekyb3d8bbwe"
FOUNDRY_PATH="/c/Users/drlor/.foundry/bin"
export PATH="$PATH:$JQ_WINGET:$FOUNDRY_PATH"

# Now we can use jq to read config
RPC=$(jq -r '.chain.rpc' "$CONFIG")
CHAIN_ID=$(jq -r '.chain.chainId' "$CONFIG")
EXPLORER=$(jq -r '.chain.explorer' "$CONFIG")
DEPLOYER=$(jq -r '.deployer' "$CONFIG")
OBSD_TOKEN=$(jq -r '.obsd.token' "$CONFIG")
OBSD_ROUTER=$(jq -r '.obsd.router' "$CONFIG")
AERO_POOL=$(jq -r '.obsd.aeroPool' "$CONFIG")
