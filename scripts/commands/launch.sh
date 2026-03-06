#!/usr/bin/env bash
# ./thryx launch "Token Name" TICKER
# Wraps factory deploy: approves OBSD, launches child token, registers in state

name="${1:-}"
ticker="${2:-}"

if [ -z "$name" ] || [ -z "$ticker" ]; then
  echo "Usage: ./thryx launch \"Token Name\" TICKER"
  echo "Example: ./thryx launch \"Moon Dog\" MDOG"
  exit 1
fi

# Security audit gate — runs before any on-chain action
echo "Running pre-deploy security audit..."
source "$SCRIPT_DIR/audit.sh" deploy 2>/dev/null
audit_result=$?
if [ "$audit_result" -ne 0 ]; then
  echo "BLOCKED: Security audit failed. Fix issues before deploying."
  exit 1
fi
echo ""

# Check ticker uniqueness
if ticker_exists "$ticker"; then
  echo "ERROR: Ticker $ticker already exists in state/tokens.json"
  exit 1
fi

# Defaults from config
FACTORY=$(jq -r '.factory.address' "$CONFIG")
OBSD_SEED=$(jq -r '.factory.defaultObsdSeed' "$CONFIG")
POOL_PERCENT=$(jq -r '.factory.defaultPoolPercent' "$CONFIG")
TOKEN_SUPPLY="1000000000000000000000000000"  # 1B tokens (1e27 wei)

echo "=== Launching Child Token ==="
echo "  Name:         $name"
echo "  Ticker:       $ticker"
echo "  OBSD Seed:    $OBSD_SEED (10K OBSD)"
echo "  Pool %:       $POOL_PERCENT%"
echo "  Supply:       1,000,000,000"
echo "  Factory:      $FACTORY"
echo ""

# Run the forge script
OUTPUT=$(FACTORY="$FACTORY" \
  TOKEN_NAME="$name" \
  TOKEN_SYMBOL="$ticker" \
  TOKEN_SUPPLY="$TOKEN_SUPPLY" \
  OBSD_SEED="$OBSD_SEED" \
  POOL_PERCENT="$POOL_PERCENT" \
  forge script script/LaunchChild.s.sol \
    --rpc-url "$RPC" \
    --broadcast 2>&1)

echo "$OUTPUT"

# Extract deployed addresses from forge output
TOKEN_ADDR=$(echo "$OUTPUT" | grep -oP 'Token deployed: \K0x[a-fA-F0-9]{40}' | head -1)
POOL_ADDR=$(echo "$OUTPUT" | grep -oP 'Aero pool: \K0x[a-fA-F0-9]{40}' | head -1)

if [ -z "$TOKEN_ADDR" ]; then
  echo ""
  echo "ERROR: Could not extract token address from forge output."
  echo "If the tx succeeded, register manually:"
  echo "  ./thryx deploy register factory <token_address> '$name' '$ticker'"
  exit 1
fi

echo ""
echo "=== Registering in state ==="

# Register token
today=$(date -u +%Y-%m-%d)
entry=$(jq -n \
  --arg n "$name" --arg t "$ticker" --arg a "$TOKEN_ADDR" \
  --arg p "factory" --arg d "$today" --arg pool "$POOL_ADDR" \
  '{name: $n, ticker: $t, address: $a, pool: $pool, platform: $p, chain: "base", wallet: "primary", date: $d, feeClaim: "lp-fees", status: "active", pairedWith: "OBSD"}')

tokens_add "$entry"

# Queue announcement tweet
tweet_text="\$$ticker just launched on the OBSD factory! Paired with \$OBSD on Aerodrome. CA: $TOKEN_ADDR @THRYXAGI"
tmp="$STATE_DIR/tweets.json.tmp"
jq --arg t "$tweet_text" '.queue += [{"text": $t, "category": "announcement"}]' "$STATE_DIR/tweets.json" > "$tmp" && mv "$tmp" "$STATE_DIR/tweets.json"

echo "Token: $TOKEN_ADDR"
echo "Pool:  $POOL_ADDR"
echo "Registered in state/tokens.json"
echo "Tweet queued. Post with: ./thryx tweet next"
echo ""
echo "=== Launch Complete ==="
