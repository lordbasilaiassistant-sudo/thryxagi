#!/usr/bin/env bash
# ./thryx wallet <subcommand>

subcmd="${1:-balance}"

wallet_balance() {
  echo "=== Wallet Balances ==="
  echo ""

  # Primary
  local addr
  addr=$(jq -r '.primary.address' "$STATE_DIR/wallets.json")
  local bal
  bal=$(chain_balance "$addr")
  local deploys
  deploys=$(jq -r '.primary.bankrDeploys' "$STATE_DIR/wallets.json")
  echo "PRIMARY: $addr"
  echo "  Balance:       $bal"
  echo "  Bankr deploys: $deploys"
  echo ""

  # Rotation wallets
  local count
  count=$(jq '.rotation | length' "$STATE_DIR/wallets.json")
  if [ "$count" -gt 0 ]; then
    echo "ROTATION WALLETS:"
    for i in $(seq 0 $((count - 1))); do
      local raddr
      raddr=$(jq -r ".rotation[$i].address" "$STATE_DIR/wallets.json")
      local rbal
      rbal=$(chain_balance "$raddr")
      local rdeploys
      rdeploys=$(jq -r ".rotation[$i].bankrDeploys" "$STATE_DIR/wallets.json")
      echo "  [$((i+1))] $raddr — $rbal (deploys: $rdeploys)"
    done
    echo ""
  fi

  # Agent wallets
  local agent_count
  agent_count=$(jq '.agents | length' "$STATE_DIR/wallets.json")
  if [ "$agent_count" -gt 0 ]; then
    echo "AGENT WALLETS:"
    jq -r '.agents | to_entries[] | "\(.key) \(.value.address)"' "$STATE_DIR/wallets.json" | while read -r agent_name addr; do
      local abal
      abal=$(chain_balance "$addr")
      local obsd_bal_wei
      obsd_bal_wei=$(chain_call "$OBSD_TOKEN" "balanceOf(address)(uint256)" "$addr" 2>/dev/null || echo "0")
      local obsd_bal
      obsd_bal=$(eth_to_human "$obsd_bal_wei")
      echo "  $agent_name: $addr — $abal ETH, $obsd_bal OBSD"
    done
    echo ""
  fi

  # Update treasury balance
  local primary_bal
  primary_bal=$(chain_balance "$DEPLOYER")
  local today
  today=$(date -u +%Y-%m-%d)
  state_update treasury.json ".ethBalance = \"$primary_bal\" | .lastUpdated = \"$today\""
}

wallet_new() {
  echo "=== Creating Rotation Wallet ==="
  local output
  output=$(cast wallet new 2>&1)
  local addr
  addr=$(echo "$output" | grep -i "address" | head -1 | grep -oP '0x[a-fA-F0-9]{40}')
  local pk
  pk=$(echo "$output" | grep -i "private" | head -1 | grep -oP '0x[a-fA-F0-9]{64}')

  if [ -z "$addr" ] || [ -z "$pk" ]; then
    echo "ERROR: Failed to generate wallet"
    echo "$output"
    exit 1
  fi

  local idx
  idx=$(jq '.rotation | length' "$STATE_DIR/wallets.json")
  local env_var="WALLET_$((idx + 1))_PRIVATE_KEY"

  # Add to wallets.json
  state_update wallets.json ".rotation += [{\"address\": \"$addr\", \"envVar\": \"$env_var\", \"bankrDeploys\": 0}]"

  echo "Address:  $addr"
  echo "Env var:  $env_var"
  echo ""
  echo "IMPORTANT: Set the private key as an environment variable:"
  echo "  export $env_var=$pk"
  echo ""
  echo "DO NOT commit this key anywhere. Added to state/wallets.json."
}

case "$subcmd" in
  balance)  wallet_balance ;;
  new)      wallet_new ;;
  *)        echo "Usage: ./thryx wallet [balance|new]"; exit 1 ;;
esac
