#!/usr/bin/env bash
# ./thryx treasury — Treasury snapshot

echo "=== THRYXAGI TREASURY ==="
echo ""

# Live on-chain data
BAL=$(chain_balance)
REAL_ETH_WEI=$(obsd_real_eth)
REAL_ETH=$(eth_to_human "$REAL_ETH_WEI")
PENDING_WEI=$(obsd_pending_fees)
PENDING=$(eth_to_human "$PENDING_WEI")

echo "Deployer ETH:     $BAL"
echo "OBSD Treasury:    $REAL_ETH ETH"
echo "Pending Fees:     $PENDING ETH"
echo ""

# From state
REVENUE=$(jq -r '.totalRevenue' "$STATE_DIR/treasury.json")
OBSD_HELD=$(jq -r '.obsdHoldings' "$STATE_DIR/treasury.json")
STAGE=$(get_stage)

echo "Total Revenue:    $REVENUE ETH (lifetime)"
echo "OBSD Holdings:    $OBSD_HELD OBSD"
echo "Stage:            $STAGE"
echo ""

# Token fee status
echo "=== Fee Pipelines ==="
ACTIVE=$(jq '[.[] | select(.status == "active")] | length' "$STATE_DIR/tokens.json")
BANKR=$(jq '[.[] | select(.platform == "bankr")] | length' "$STATE_DIR/tokens.json")
PUMP=$(jq '[.[] | select(.platform == "pumpfun")] | length' "$STATE_DIR/tokens.json")
echo "Active tokens:    $ACTIVE"
echo "Bankr (auto-fee): $BANKR"
echo "Pump.fun:         $PUMP"
echo ""

# Payroll status
PAYROLL_DIST=$(jq -r '.payroll.totalDistributed' "$STATE_DIR/treasury.json")
LAST_PAYROLL=$(jq -r '.payroll.lastPayroll // "never"' "$STATE_DIR/treasury.json")
echo "=== Payroll ==="
echo "Total Distributed: $PAYROLL_DIST OBSD"
echo "Last Payroll:      $LAST_PAYROLL"

# OBSD balance of treasury wallet (payroll checkbook)
OBSD_BAL_WEI=$(chain_call "$OBSD_TOKEN" "balanceOf(address)(uint256)" "$DEPLOYER" 2>/dev/null || echo "0")
OBSD_BAL=$(eth_to_human "$OBSD_BAL_WEI")
echo "OBSD Available:    $OBSD_BAL OBSD (payroll fund)"

# Update state
local today 2>/dev/null || true
today=$(date -u +%Y-%m-%d)
state_update treasury.json ".ethBalance = \"$BAL\" | .obsdRealEth = \"$REAL_ETH\" | .lastUpdated = \"$today\""
