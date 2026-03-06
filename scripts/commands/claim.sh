#!/usr/bin/env bash
# ./thryx claim <subcommand>

subcmd="${1:-all}"

claim_obsd() {
  echo "=== Claiming OBSD Router Fees ==="
  PENDING_WEI=$(obsd_pending_fees)
  PENDING=$(eth_to_human "$PENDING_WEI")

  if [ "$PENDING_WEI" = "0" ]; then
    echo "No pending fees to claim."
    return 0
  fi

  echo "Pending: $PENDING ETH"
  echo "Claiming..."
  obsd_claim_fees
  echo "Claimed $PENDING ETH from OBSD router."

  # Update treasury state
  local current
  current=$(jq -r '.totalRevenue' "$STATE_DIR/treasury.json")
  local new_total
  new_total=$(python3 -c "print(f'{float(\"$current\") + float(\"$PENDING\"):.6f}')")
  local today
  today=$(date -u +%Y-%m-%d)
  state_update treasury.json ".totalRevenue = \"$new_total\" | .lastUpdated = \"$today\""
  echo "Treasury updated. Total revenue: $new_total ETH"
}

claim_all() {
  echo "=== Claiming All Fees ==="
  echo ""

  # 1. OBSD router fees
  claim_obsd
  echo ""

  # 2. Bankr tokens — auto-distributed, just report
  echo "=== Bankr Tokens ==="
  echo "Bankr fees are auto-distributed per swap. No manual claim needed."
  BANKR_COUNT=$(jq '[.[] | select(.platform == "bankr")] | length' "$STATE_DIR/tokens.json")
  echo "$BANKR_COUNT Bankr tokens deployed. Fees route to deployer wallet automatically."
  echo ""

  # 3. Pump.fun — needs dashboard check
  echo "=== Pump.fun Tokens ==="
  PUMP_COUNT=$(jq '[.[] | select(.platform == "pumpfun")] | length' "$STATE_DIR/tokens.json")
  echo "$PUMP_COUNT pump.fun tokens. Check creator dashboard at https://pump.fun (thryx account)."
  echo "API claiming blocked by Cloudflare. Manual check required."
  echo ""

  # Update balances
  NEW_BAL=$(chain_balance)
  local today
  today=$(date -u +%Y-%m-%d)
  state_update treasury.json ".ethBalance = \"$NEW_BAL\" | .lastUpdated = \"$today\""
  echo "=== Done. Wallet balance: $NEW_BAL ==="
}

case "$subcmd" in
  obsd)  claim_obsd ;;
  all)   claim_all ;;
  *)     echo "Usage: ./thryx claim [all|obsd]"; exit 1 ;;
esac
