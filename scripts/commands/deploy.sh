#!/usr/bin/env bash
# ./thryx deploy <platform> <name> <ticker>
# ./thryx deploy register <platform> <address> <name> <ticker>

platform="${1:-}"
shift || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

deploy_bankr() {
  local name="${1:-}"
  local ticker="${2:-}"

  if [ -z "$name" ] || [ -z "$ticker" ]; then
    echo "Usage: ./thryx deploy bankr <name> <ticker>"
    echo "Example: ./thryx deploy bankr 'Agentic Mind' AMIND"
    exit 1
  fi

  # Security audit gate
  echo "Running pre-deploy security audit..."
  source "$SCRIPT_DIR/audit.sh" secrets 2>/dev/null
  echo ""

  # Check ticker uniqueness
  if ticker_exists "$ticker"; then
    echo "ERROR: Ticker $ticker already exists in state/tokens.json"
    echo "Pick a different ticker."
    exit 1
  fi

  # Check which wallet to use
  local primary_deploys
  primary_deploys=$(jq -r '.primary.bankrDeploys' "$STATE_DIR/wallets.json")
  local wallet_name="primary"

  if [ "$primary_deploys" -ge 15 ]; then
    local rot_count
    rot_count=$(jq '.rotation | length' "$STATE_DIR/wallets.json")
    if [ "$rot_count" -eq 0 ]; then
      echo "ERROR: Primary wallet at $primary_deploys deploys. Create a rotation wallet first:"
      echo "  ./thryx wallet new"
      exit 1
    fi
    for i in $(seq 0 $((rot_count - 1))); do
      local rd
      rd=$(jq -r ".rotation[$i].bankrDeploys" "$STATE_DIR/wallets.json")
      if [ "$rd" -lt 15 ]; then
        wallet_name="rotation_$i"
        echo "Using rotation wallet $((i+1)) (primary at limit)"
        break
      fi
    done
  fi

  echo "=== Deploy on Bankr ==="
  echo "Name:    $name"
  echo "Ticker:  $ticker"
  echo "Wallet:  $wallet_name ($primary_deploys deploys so far)"
  echo ""
  echo "AGENT: Run this MCP call now:"
  echo "  bankr_agent_submit_prompt: \"deploy a token called $name with ticker $ticker on base\""
  echo ""
  echo "After deployment succeeds, register it:"
  echo "  ./thryx deploy register bankr <contract_address> '$name' '$ticker'"
}

deploy_register() {
  local reg_platform="${1:-}"
  local reg_address="${2:-}"
  local reg_name="${3:-}"
  local reg_ticker="${4:-}"

  if [ -z "$reg_address" ] || [ -z "$reg_name" ] || [ -z "$reg_ticker" ]; then
    echo "Usage: ./thryx deploy register <platform> <address> <name> <ticker>"
    exit 1
  fi

  # Check ticker uniqueness before registering
  if ticker_exists "$reg_ticker"; then
    echo "ERROR: Ticker $reg_ticker already exists."
    exit 1
  fi

  local today
  today=$(date -u +%Y-%m-%d)

  local fee_claim="bankr-auto"
  [ "$reg_platform" = "pumpfun" ] && fee_claim="pumpfun-dashboard"
  [ "$reg_platform" = "custom" ] && fee_claim="router-pull"

  local chain="base"
  [ "$reg_platform" = "pumpfun" ] && chain="solana"

  local entry
  entry=$(jq -n \
    --arg n "$reg_name" --arg t "$reg_ticker" --arg a "$reg_address" \
    --arg p "$reg_platform" --arg c "$chain" --arg d "$today" --arg f "$fee_claim" \
    '{name: $n, ticker: $t, address: $a, platform: $p, chain: $c, wallet: "primary", date: $d, feeClaim: $f, status: "active"}')

  tokens_add "$entry"

  # Increment deploy count for bankr
  if [ "$reg_platform" = "bankr" ]; then
    state_update wallets.json '.primary.bankrDeploys += 1'
  fi

  # Queue announcement tweet
  local tweet_text="\$$reg_ticker just deployed on ${reg_platform^} (${chain^}). CA: $reg_address. All fees to treasury. @THRYXAGI"
  local tmp="$STATE_DIR/tweets.json.tmp"
  jq --arg t "$tweet_text" '.queue += [{"text": $t, "category": "announcement"}]' "$STATE_DIR/tweets.json" > "$tmp" && mv "$tmp" "$STATE_DIR/tweets.json"

  echo "Registered $reg_ticker ($reg_address) in state/tokens.json"
  echo "Deploy count incremented."
  echo "Announcement tweet queued. Post with: ./thryx tweet next"
}

case "$platform" in
  bankr)    deploy_bankr "$@" ;;
  register) deploy_register "$@" ;;
  "")       echo "Usage: ./thryx deploy [bankr|register] ..."; exit 1 ;;
  *)        echo "Unknown platform: $platform"; echo "Supported: bankr, register"; exit 1 ;;
esac
