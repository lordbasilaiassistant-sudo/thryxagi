#!/usr/bin/env bash
# ./thryx gen-ops — Regenerate ops/ markdown files from state/ JSON

echo "=== Regenerating ops/ from state/ ==="

TODAY=$(date -u +%Y-%m-%d)

# --- deployed-tokens.md ---
{
  echo "# Deployed Tokens Registry"
  echo "> Auto-generated from state/tokens.json on $TODAY. Do not edit manually."
  echo "> Regenerate with: ./thryx gen-ops"
  echo ""
  echo "## Base Chain"
  echo "| Token | Ticker | Contract | Platform | Status | Fee Claim |"
  echo "|-------|--------|----------|----------|--------|-----------|"
  jq -r '.[] | select(.chain == "base") | "| \(.name) | \(.ticker) | \(.address) | \(.platform) | \(.status) | \(.feeClaim) |"' "$STATE_DIR/tokens.json"
  echo ""
  echo "## Solana"
  echo "| Token | Ticker | Contract | Platform | Status |"
  echo "|-------|--------|----------|----------|--------|"
  jq -r '.[] | select(.chain == "solana") | "| \(.name) | \(.ticker) | \(.address) | \(.platform) | \(.status) |"' "$STATE_DIR/tokens.json"
  echo ""
  echo "## Used Tickers (DO NOT REUSE)"
  jq -r '[.[].ticker] | join(", ")' "$STATE_DIR/tokens.json"
} > "$PROJECT_ROOT/ops/deployed-tokens.md"
echo "  ops/deployed-tokens.md"

# --- treasury.md ---
{
  echo "# THRYXAGI Treasury"
  echo "> Auto-generated from state/treasury.json on $TODAY. Do not edit manually."
  echo "> Regenerate with: ./thryx gen-ops"
  echo ""
  echo "| Metric | Value |"
  echo "|--------|-------|"
  jq -r '"| ETH Balance | \(.ethBalance) ETH |\n| OBSD Holdings | \(.obsdHoldings) OBSD |\n| OBSD Treasury | \(.obsdRealEth) ETH |\n| Total Revenue | \(.totalRevenue) ETH |\n| Stage | \(.stage) |\n| Payroll Distributed | \(.payroll.totalDistributed) OBSD |"' "$STATE_DIR/treasury.json"
} > "$PROJECT_ROOT/ops/treasury.md"
echo "  ops/treasury.md"

# --- wallet-rotation.md ---
{
  echo "# Wallet Rotation"
  echo "> Auto-generated from state/wallets.json on $TODAY. Do not edit manually."
  echo "> Regenerate with: ./thryx gen-ops"
  echo ""
  echo "## Primary"
  jq -r '"Address: \(.primary.address)\nBankr deploys: \(.primary.bankrDeploys)"' "$STATE_DIR/wallets.json"
  echo ""
  echo "## Rotation Wallets"
  rot_count=$(jq '.rotation | length' "$STATE_DIR/wallets.json")
  if [ "$rot_count" = "0" ]; then
    echo "None. Create with: ./thryx wallet new"
  else
    echo "| # | Address | Env Var | Deploys |"
    echo "|---|---------|---------|---------|"
    jq -r '.rotation | to_entries[] | "| \(.key + 1) | \(.value.address) | \(.value.envVar) | \(.value.bankrDeploys) |"' "$STATE_DIR/wallets.json"
  fi
  echo ""
  echo "## Agent Wallets"
  agent_count=$(jq '.agents | length' "$STATE_DIR/wallets.json")
  if [ "$agent_count" = "0" ]; then
    echo "None registered. Add with: ./thryx payroll add <name> <address>"
  else
    jq -r '.agents | to_entries[] | "- \(.key): \(.value.address)"' "$STATE_DIR/wallets.json"
  fi
} > "$PROJECT_ROOT/ops/wallet-rotation.md"
echo "  ops/wallet-rotation.md"

echo ""
echo "=== Done. ops/ files regenerated from state/ ==="
