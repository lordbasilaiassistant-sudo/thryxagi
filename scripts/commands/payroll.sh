#!/usr/bin/env bash
# ./thryx payroll <subcommand>

subcmd="${1:-status}"
shift || true

payroll_status() {
  echo "=== Agent Payroll Status ==="
  echo ""

  local agent_count
  agent_count=$(jq '.agents | length' "$STATE_DIR/wallets.json")

  if [ "$agent_count" = "0" ]; then
    echo "No agent wallets registered."
    echo ""
    echo "Register an agent wallet:"
    echo "  ./thryx payroll add <agent_name> <address>"
    return
  fi

  # Treasury OBSD balance (the payroll checkbook)
  local treasury_obsd_wei
  treasury_obsd_wei=$(chain_call "$OBSD_TOKEN" "balanceOf(address)(uint256)" "$DEPLOYER" 2>/dev/null || echo "0")
  local treasury_obsd
  treasury_obsd=$(eth_to_human "$treasury_obsd_wei")
  echo "Treasury OBSD balance (payroll fund): $treasury_obsd OBSD"
  echo ""

  echo "Agent wallets and OBSD balances:"
  while read -r agent_name addr; do
    local obsd_bal_wei
    obsd_bal_wei=$(chain_call "$OBSD_TOKEN" "balanceOf(address)(uint256)" "$addr" 2>/dev/null || echo "0")
    local obsd_bal
    obsd_bal=$(eth_to_human "$obsd_bal_wei")
    echo "  $agent_name: $addr — $obsd_bal OBSD"
  done < <(jq -r '.agents | to_entries[] | "\(.key) \(.value.address)"' "$STATE_DIR/wallets.json" | tr -d '\r')
  echo ""

  local total
  total=$(jq -r '.payroll.totalDistributed' "$STATE_DIR/treasury.json")
  local last
  last=$(jq -r '.payroll.lastPayroll // "never"' "$STATE_DIR/treasury.json")
  echo "Total distributed: $total OBSD"
  echo "Last payroll: $last"
}

payroll_add() {
  local agent_name="${1:-}"
  local addr="${2:-}"

  if [ -z "$agent_name" ] || [ -z "$addr" ]; then
    echo "Usage: ./thryx payroll add <agent_name> <address>"
    echo "Example: ./thryx payroll add nova 0x1234...5678"
    exit 1
  fi

  local today
  today=$(date -u +%Y-%m-%d)
  state_update wallets.json ".agents.\"$agent_name\" = {\"address\": \"$addr\", \"registered\": \"$today\"}"
  echo "Registered agent wallet: $agent_name -> $addr"
}

payroll_run() {
  echo "=== Running Agent Payroll ==="

  local agent_count
  agent_count=$(jq '.agents | length' "$STATE_DIR/wallets.json")
  if [ "$agent_count" = "0" ]; then
    echo "No agent wallets registered. Use: ./thryx payroll add <name> <address>"
    exit 1
  fi

  local amount="${1:-1000000000000000000}"  # Default 1 OBSD (1e18)
  local amount_human
  amount_human=$(eth_to_human "$amount")

  echo "Distributing $amount_human OBSD to $agent_count agents..."
  echo ""

  while read -r agent_name addr; do
    echo "Paying $agent_name ($addr)..."
    OBSD_TOKEN="$OBSD_TOKEN" PAYROLL_RECIPIENT="$addr" PAYROLL_AMOUNT="$amount" \
      forge script script/Payroll.s.sol --rpc-url "$RPC" --broadcast 2>&1 | tail -5
    echo ""
  done < <(jq -r '.agents | to_entries[] | "\(.key) \(.value.address)"' "$STATE_DIR/wallets.json" | tr -d '\r')

  # Update treasury
  local total_paid
  total_paid=$(python3 -c "print($agent_count * $amount)")
  local prev
  prev=$(jq -r '.payroll.totalDistributed' "$STATE_DIR/treasury.json")
  local new_total
  new_total=$(python3 -c "print(int('$prev') + int('$total_paid'))")
  local today
  today=$(date -u +%Y-%m-%d)
  state_update treasury.json ".payroll.totalDistributed = \"$new_total\" | .payroll.lastPayroll = \"$today\""

  echo "=== Payroll Complete ==="
  echo "Paid $agent_count agents, $amount_human OBSD each."
}

case "$subcmd" in
  status)  payroll_status ;;
  add)     payroll_add "$@" ;;
  run)     payroll_run "$@" ;;
  *)       echo "Usage: ./thryx payroll [status|add|run]"; exit 1 ;;
esac
