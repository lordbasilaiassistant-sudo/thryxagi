#!/usr/bin/env bash
# ./thryx monitor — One-shot health check for agent session start

echo "=========================================="
echo "  THRYXAGI MONITOR — Session Health Check"
echo "=========================================="
echo ""

ACTIONS=()

# --- Pull on-chain data (with fallback on RPC errors) ---
RPC_OK=true
REAL_ETH_WEI=$(obsd_real_eth 2>/dev/null) || { echo "  [ERROR] RPC rate limited. Retry in 30s."; echo ""; RPC_OK=false; }

if [ "$RPC_OK" = "true" ]; then
  PENDING_WEI=$(obsd_pending_fees 2>/dev/null) || PENDING_WEI="0"
  PHASE=$(obsd_phase 2>/dev/null) || PHASE="0"
  CIRC_WEI=$(obsd_circulating 2>/dev/null) || CIRC_WEI="0"
  CURRENT_TIER=$(chain_call "$OBSD_ROUTER" "currentTier()(uint8)" 2>/dev/null) || CURRENT_TIER="0"
  TOTAL_ETH_DEPLOYED_WEI=$(chain_call "$OBSD_ROUTER" "totalETHDeployed()(uint256)" 2>/dev/null) || TOTAL_ETH_DEPLOYED_WEI="0"
  V_ETH_WEI=$(chain_call "$OBSD_ROUTER" "vETH()(uint256)" 2>/dev/null) || V_ETH_WEI="0"
  V_TOK_WEI=$(chain_call "$OBSD_ROUTER" "vTOK()(uint256)" 2>/dev/null) || V_TOK_WEI="0"
  DEPLOYER_BAL_WEI=$(chain_balance_wei 2>/dev/null) || DEPLOYER_BAL_WEI="0"

  # Strip cast output annotations like "[4.452e15]"
  REAL_ETH_WEI=$(echo "$REAL_ETH_WEI" | awk '{print $1}')
  PENDING_WEI=$(echo "$PENDING_WEI" | awk '{print $1}')
  CIRC_WEI=$(echo "$CIRC_WEI" | awk '{print $1}')
  CURRENT_TIER=$(echo "$CURRENT_TIER" | awk '{print $1}' | tr -d '\r')
  TOTAL_ETH_DEPLOYED_WEI=$(echo "$TOTAL_ETH_DEPLOYED_WEI" | awk '{print $1}')
  V_ETH_WEI=$(echo "$V_ETH_WEI" | awk '{print $1}')
  V_TOK_WEI=$(echo "$V_TOK_WEI" | awk '{print $1}')
  DEPLOYER_BAL_WEI=$(echo "$DEPLOYER_BAL_WEI" | awk '{print $1}')

  # Phase name
  PHASE_NAME="BondingCurve"
  [ "$PHASE" = "1" ] && PHASE_NAME="Hybrid"
  [ "$PHASE" = "2" ] && PHASE_NAME="Graduated"

  # --- Compute values in Python for precision ---
  eval "$(python3 -c "
real_eth_wei = int('${REAL_ETH_WEI}')
total_deployed_wei = int('${TOTAL_ETH_DEPLOYED_WEI}')
pending_wei = int('${PENDING_WEI}')
circ_wei = int('${CIRC_WEI}')
v_eth_wei = int('${V_ETH_WEI}')
v_tok_wei = int('${V_TOK_WEI}')
deployer_wei = int('${DEPLOYER_BAL_WEI}')
current_tier = int('${CURRENT_TIER}')

real_eth = real_eth_wei / 1e18
cumulative = (real_eth_wei + total_deployed_wei) / 1e18
pending_eth = pending_wei / 1e18
deployer_eth = deployer_wei / 1e18

iv = real_eth_wei * 1e18 / circ_wei / 1e18 if circ_wei > 0 else 0
spot = v_eth_wei * 1e18 / v_tok_wei / 1e18 if v_tok_wei > 0 else 0

thresholds = [0.0005, 0.005, 0.02, 0.1, 0.5]
if current_tier < 5 and cumulative >= thresholds[current_tier]:
    tier_status = 'ACTION'
    tier_display = f'Tier {current_tier} threshold MET ({cumulative:.6f} >= {thresholds[current_tier]})'
elif current_tier < 5:
    tier_status = 'OK'
    gap = thresholds[current_tier] - cumulative
    pct = cumulative / thresholds[current_tier] * 100
    tier_display = f'Tier {current_tier}: {pct:.1f}% ({cumulative:.6f} / {thresholds[current_tier]:.4f} ETH, gap: {gap:.6f})'
else:
    tier_status = 'OK'
    tier_display = 'Fully graduated'

if deployer_eth < 0.00005:
    deployer_status = 'WARN_CRIT'
elif deployer_eth < 0.0005:
    deployer_status = 'WARN_LOW'
else:
    deployer_status = 'OK'

if pending_wei > 0:
    pending_status = 'ACTION' if (pending_eth - 0.000002) > 0 else 'WARN'
else:
    pending_status = 'OK'

txs_est = int(deployer_eth / 0.000002) if deployer_eth > 0 else 0

print(f'M_REAL_ETH=\"{real_eth:.6f}\"')
print(f'M_CUMULATIVE=\"{cumulative:.6f}\"')
print(f'M_IV=\"{iv:.15f}\"')
print(f'M_SPOT=\"{spot:.15f}\"')
print(f'M_PENDING_ETH=\"{pending_eth:.6f}\"')
print(f'M_DEPLOYER_ETH=\"{deployer_eth:.6f}\"')
print(f'M_TIER_STATUS=\"{tier_status}\"')
print(f'M_TIER_DISPLAY=\"{tier_display}\"')
print(f'M_DEPLOYER_STATUS=\"{deployer_status}\"')
print(f'M_PENDING_STATUS=\"{pending_status}\"')
print(f'M_TXS_REMAINING=\"{txs_est}\"')
" | tr -d '\r')"

  # --- Display OBSD State ---
  echo "OBSD State:"
  echo "  Phase:      $PHASE_NAME ($PHASE)"
  NEXT_THRESH="0.0005"
  [ "$CURRENT_TIER" = "1" ] && NEXT_THRESH="0.005"
  [ "$CURRENT_TIER" = "2" ] && NEXT_THRESH="0.02"
  [ "$CURRENT_TIER" = "3" ] && NEXT_THRESH="0.1"
  [ "$CURRENT_TIER" = "4" ] && NEXT_THRESH="0.5"
  [ "$CURRENT_TIER" = "5" ] && NEXT_THRESH="graduated"
  echo "  Tier:       $CURRENT_TIER (next threshold: $NEXT_THRESH ETH)"
  echo "  realETH:    $M_REAL_ETH ETH"
  echo "  Cumulative: $M_CUMULATIVE ETH"
  echo "  IV:         $M_IV ETH/token"
  echo "  Spot:       $M_SPOT ETH/token"
  echo ""

  # --- Checks ---
  echo "Checks:"

  # Tier check
  if [ "$M_TIER_STATUS" = "ACTION" ]; then
    echo "  [ACTION] $M_TIER_DISPLAY. Run: cast send \$OBSD_ROUTER 'graduateTier()' or it triggers on next buy."
    ACTIONS+=("$M_TIER_DISPLAY — run graduateTier()")
  else
    echo "  [OK] $M_TIER_DISPLAY"
  fi

  # Pending fees
  if [ "$M_PENDING_STATUS" = "ACTION" ]; then
    echo "  [ACTION] Pending fees: $M_PENDING_ETH ETH. Run: ./thryx claim obsd"
    ACTIONS+=("Pending fees: $M_PENDING_ETH ETH — run: ./thryx claim obsd")
  elif [ "$M_PENDING_STATUS" = "WARN" ]; then
    echo "  [WARN] Pending fees: $M_PENDING_ETH ETH but gas exceeds — not worth claiming yet"
  else
    echo "  [OK] No pending fees"
  fi

  # Deployer gas
  if [ "$M_DEPLOYER_STATUS" = "WARN_CRIT" ]; then
    echo "  [WARN] Deployer balance CRITICAL: $M_DEPLOYER_ETH ETH — cannot execute txs"
  elif [ "$M_DEPLOYER_STATUS" = "WARN_LOW" ]; then
    echo "  [WARN] Deployer balance LOW: $M_DEPLOYER_ETH ETH — ~$M_TXS_REMAINING txs remaining"
  else
    echo "  [OK] Deployer balance: $M_DEPLOYER_ETH ETH"
  fi

  echo ""

else
  echo "Skipping on-chain checks (RPC unavailable)."
  echo ""
fi

# --- DexScreener Volume Check ---
echo "DexScreener:"
DEX_BASE=$(jq -r '.apis.dexScreener' "$STATE_DIR/config.json")
TOKEN_LIST=$(jq -r '.[] | select(.chain == "base") | .ticker + "|" + .address' "$STATE_DIR/tokens.json")
HAS_VOLUME=0

while IFS='|' read -r ticker addr; do
  [ -z "$ticker" ] && continue
  data=$(curl -s "$DEX_BASE/tokens/$addr" 2>/dev/null || echo '{}')
  pairs=$(echo "$data" | jq '.pairs // [] | length' 2>/dev/null || echo "0")

  if [ "$pairs" != "0" ] && [ "$pairs" != "" ] && [ "$pairs" != "null" ]; then
    vol=$(echo "$data" | jq '.pairs[0].volume.h24 // 0' 2>/dev/null || echo "0")
    txns=$(echo "$data" | jq '((.pairs[0].txns.h24.buys // 0) + (.pairs[0].txns.h24.sells // 0))' 2>/dev/null || echo "0")

    if [ "$vol" != "0" ] && [ "$vol" != "null" ] && [ "$vol" != "" ]; then
      HAS_VOLUME=1
      echo "  [ACTION] $ticker has DexScreener volume! vol=\$$vol txns=$txns. Investigate."
      ACTIONS+=("$ticker has DexScreener volume — vol=\$$vol, investigate")
    else
      echo "  [OK] $ticker indexed on DexScreener (no volume)"
    fi
  fi

  sleep 0.3
done <<< "$TOKEN_LIST"

if [ "$HAS_VOLUME" = "0" ]; then
  echo "  (no tokens with volume)"
fi

echo ""

# --- Summary ---
ACTION_COUNT=${#ACTIONS[@]}
echo "=========================================="
if [ "$ACTION_COUNT" = "0" ]; then
  echo "  0 actions required"
else
  echo "  $ACTION_COUNT actions required:"
  for i in "${!ACTIONS[@]}"; do
    echo "  $((i+1)). ${ACTIONS[$i]}"
  done
fi
echo "=========================================="
