#!/bin/bash
# ./thryx ledger — Financial ledger summary
# Reads state/ledger.json and outputs formatted P&L

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LEDGER="$ROOT_DIR/state/ledger.json"
JQ="jq"

if ! command -v jq &>/dev/null; then
  JQ="/c/Users/drlor/AppData/Local/Microsoft/WinGet/Packages/jqlang.jq_Microsoft.Winget.Source_8wekyb3d8bbwe/jq.exe"
fi

if [ ! -f "$LEDGER" ]; then
  echo "ERROR: No ledger found at $LEDGER"
  echo "Run Vault agent to generate it."
  exit 1
fi

echo "============================================"
echo "  THRYXAGI FINANCIAL LEDGER"
echo "  Session: $($JQ -r '.session' "$LEDGER")"
echo "  Generated: $($JQ -r '.generated_at' "$LEDGER")"
echo "============================================"
echo ""
echo "--- GAS EXPENSES (ETH) ---"
$JQ -r '.summary.gas_breakdown | to_entries[] | "  \(.key | gsub("_"; " ")): \(.value) ETH"' "$LEDGER"
echo "  ────────────────────────────"
echo "  TOTAL GAS: $($JQ -r '.summary.total_gas_spent_eth' "$LEDGER") ETH"
echo ""
echo "--- REVENUE (ETH) ---"
$JQ -r '.revenue[] | "  \(.source): \(.amount_eth) ETH"' "$LEDGER"
echo "  ────────────────────────────"
echo "  TOTAL EARNED: $($JQ -r '.summary.total_eth_earned' "$LEDGER") ETH"
echo ""
echo "--- NET P&L ---"
echo "  Net: $($JQ -r '.summary.net_pnl_eth' "$LEDGER") ETH"
echo ""
echo "--- OBSD ALLOCATION ---"
echo "  Seeded to pools: $($JQ -r '.summary.obsd_seeded_to_pools' "$LEDGER") OBSD"
echo "  Agent payroll:   $($JQ -r '.summary.obsd_distributed_to_agents' "$LEDGER") OBSD"
echo "  Aero pool:       $($JQ -r '.summary.obsd_in_aero_pool' "$LEDGER") OBSD"
echo "  Deployer wallet: $($JQ -r '.summary.obsd_remaining_deployer' "$LEDGER") OBSD"
echo ""
echo "--- BALANCES ---"
echo "  Deployer ETH:    $($JQ -r '.summary.eth_remaining_deployer' "$LEDGER") ETH"
echo "  OBSD Treasury:   $($JQ -r '.summary.eth_in_obsd_treasury' "$LEDGER") ETH"
echo "  Total ETH:       $($JQ -r '.summary.total_eth_all' "$LEDGER") ETH"
echo ""
echo "--- RUNWAY ---"
echo "  Total txs this session: $($JQ -r '.summary.total_txs' "$LEDGER")"
echo "  Avg gas/tx: $($JQ -r '.summary.avg_gas_per_tx_eth' "$LEDGER") ETH"
echo "  Estimate: $($JQ -r '.summary.runway_estimate_txs' "$LEDGER")"
echo ""
echo "--- PROFIT SPLIT (50/50) ---"
echo "  Cumulative profit: $($JQ -r '.summary.profit_split.cumulative_profit_eth' "$LEDGER") ETH"
DEFICIT=$($JQ -r '.summary.profit_split.deficit_carried' "$LEDGER")
if [ "$DEFICIT" != "0" ]; then
  echo "  Deficit carried:   $DEFICIT ETH (must clear before payouts)"
fi
echo "  Treasury share:    $($JQ -r '.summary.profit_split.treasury_share_eth' "$LEDGER") ETH"
echo "  Builder share:     $($JQ -r '.summary.profit_split.builder_share_eth' "$LEDGER") ETH ($($JQ -r '.summary.profit_split.builder_share_obsd' "$LEDGER") OBSD)"
echo ""
echo "--- PER-TOKEN ROI ---"
echo "  OBSD (custom):  Volume=$6.59 | Revenue=0.000048 ETH | Gas=0.000040 ETH | ROI: +20%"
echo "  Bankr (13 tokens): Volume=$0 | Revenue=$0 | Gas=$0 (free deploys) | ROI: 0%"
echo "  Pump.fun (4 tokens): Volume=$0 | Revenue=$0 | Gas=~0.02 SOL | ROI: -100%"
echo "  Factory (15 tokens): Volume=$0 | Revenue=$0 | Gas=0.000173 ETH | ROI: -100%"
echo ""
echo "============================================"
