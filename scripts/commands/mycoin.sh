#!/usr/bin/env bash
# ./thryx mycoin [agent_name] — Show agent's token info

AGENT_NAME="${1:-}"

if [ -z "$AGENT_NAME" ]; then
  echo "Usage: ./thryx mycoin <agent_name>"
  echo "  e.g. ./thryx mycoin forge"
  exit 1
fi

# Look up agent wallet from wallets.json
AGENT_ADDR=$(jq -r --arg n "$AGENT_NAME" '.agents[$n].address // empty' "$STATE_DIR/wallets.json")

if [ -z "$AGENT_ADDR" ]; then
  echo "ERROR: Agent '$AGENT_NAME' not found in wallets.json"
  echo ""
  echo "Registered agents:"
  jq -r '.agents | keys[]' "$STATE_DIR/wallets.json" | sed 's/^/  /'
  exit 1
fi

echo "=========================================="
echo "  MY COIN — $AGENT_NAME"
echo "=========================================="
echo ""
echo "AGENT:     $AGENT_NAME"
echo "WALLET:    $AGENT_ADDR"
echo ""

# Find tokens created by this agent
# Check for creator field matching agent address, or wallet field matching agent name
TOKENS=$(jq -c --arg addr "$AGENT_ADDR" --arg name "$AGENT_NAME" \
  '[.[] | select(.creator == $addr or .wallet == $name)]' \
  "$STATE_DIR/tokens.json")

TOKEN_COUNT=$(echo "$TOKENS" | jq 'length')

if [ "$TOKEN_COUNT" = "0" ]; then
  echo "No token deployed yet. Use ./thryx launch to create one."
  echo ""
  echo "=========================================="
  exit 0
fi

echo "TOKENS:    $TOKEN_COUNT found"
echo ""

# Display each token
echo "$TOKENS" | jq -c '.[]' | while IFS= read -r token; do
  T_NAME=$(echo "$token" | jq -r '.name')
  T_TICKER=$(echo "$token" | jq -r '.ticker')
  T_ADDR=$(echo "$token" | jq -r '.address')
  T_STATUS=$(echo "$token" | jq -r '.status')
  T_PLATFORM=$(echo "$token" | jq -r '.platform')
  T_CHAIN=$(echo "$token" | jq -r '.chain')

  echo "  TOKEN:     $T_NAME (\$$T_TICKER)"
  echo "  ADDRESS:   $T_ADDR"
  echo "  STATUS:    $T_STATUS"
  echo "  PLATFORM:  $T_PLATFORM ($T_CHAIN)"
  echo "  EXPLORER:  $EXPLORER/address/$T_ADDR"

  # On-chain balances (Base tokens only)
  if [ "$T_CHAIN" = "base" ]; then
    # OBSD balance of agent wallet
    OBSD_BAL_WEI=$(chain_call "$OBSD_TOKEN" "balanceOf(address)(uint256)" "$AGENT_ADDR" 2>/dev/null || echo "0")
    OBSD_BAL=$(eth_to_human "$OBSD_BAL_WEI")
    echo "  OBSD BAL:  $OBSD_BAL OBSD"

    # Token balance of agent wallet
    TOKEN_BAL_WEI=$(chain_call "$T_ADDR" "balanceOf(address)(uint256)" "$AGENT_ADDR" 2>/dev/null || echo "0")
    TOKEN_BAL=$(eth_to_human "$TOKEN_BAL_WEI")
    echo "  TOKEN BAL: $TOKEN_BAL $T_TICKER"
  fi

  echo ""
done

echo "=========================================="
