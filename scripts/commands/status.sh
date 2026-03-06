#!/usr/bin/env bash
# ./thryx status — Full dashboard for agents

echo "=========================================="
echo "  THRYXAGI STATUS DASHBOARD"
echo "=========================================="
echo ""

# Wallet balance
BAL=$(chain_balance)
STAGE=$(get_stage)
echo "WALLET:    $DEPLOYER"
echo "BALANCE:   $BAL"
echo "STAGE:     $STAGE"
echo ""

# OBSD state
REAL_ETH_WEI=$(obsd_real_eth)
REAL_ETH=$(eth_to_human "$REAL_ETH_WEI")
PHASE=$(obsd_phase)
PENDING_WEI=$(obsd_pending_fees)
PENDING=$(eth_to_human "$PENDING_WEI")

PHASE_NAME="BondingCurve"
[ "$PHASE" = "1" ] && PHASE_NAME="Hybrid"
[ "$PHASE" = "2" ] && PHASE_NAME="Graduated"

TIER=$(chain_call "$OBSD_ROUTER" "currentTier()(uint8)")

echo "OBSD:"
echo "  Phase:        $PHASE_NAME (tier $TIER)"
echo "  Treasury:     $REAL_ETH ETH"
echo "  Pending Fees: $PENDING ETH"
echo ""

# Token counts
TOTAL=$(jq 'length' "$STATE_DIR/tokens.json")
ACTIVE=$(jq '[.[] | select(.status == "active")] | length' "$STATE_DIR/tokens.json")
DEAD=$(jq '[.[] | select(.status == "dead")] | length' "$STATE_DIR/tokens.json")
BASE_COUNT=$(jq '[.[] | select(.chain == "base")] | length' "$STATE_DIR/tokens.json")
SOL_COUNT=$(jq '[.[] | select(.chain == "solana")] | length' "$STATE_DIR/tokens.json")

echo "TOKENS:    $TOTAL total ($ACTIVE active, $DEAD dead)"
echo "  Base:    $BASE_COUNT"
echo "  Solana:  $SOL_COUNT"
echo ""

# Tweet queue
QUEUE_SIZE=$(jq '.queue | length' "$STATE_DIR/tweets.json")
POSTED=$(jq '.posted | length' "$STATE_DIR/tweets.json")
echo "TWEETS:    $QUEUE_SIZE in queue, $POSTED posted"
echo ""

# Treasury from state
REVENUE=$(jq -r '.totalRevenue' "$STATE_DIR/treasury.json")
echo "REVENUE:   $REVENUE ETH (lifetime)"
echo ""

# Agent wallets
AGENT_COUNT=$(jq '.agents | length' "$STATE_DIR/wallets.json")
echo "AGENTS:    $AGENT_COUNT with wallets"

# Payroll
PAYROLL_DIST=$(jq -r '.payroll.totalDistributed' "$STATE_DIR/treasury.json")
echo "PAYROLL:   $PAYROLL_DIST OBSD distributed"

echo ""
echo "=========================================="
echo "  Run ./thryx help for available commands"
echo "=========================================="
