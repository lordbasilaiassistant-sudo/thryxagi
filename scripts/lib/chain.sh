#!/usr/bin/env bash
# On-chain helpers. Source this: . scripts/lib/chain.sh
# Requires config.sh sourced first.

chain_balance() {
  # Usage: chain_balance [address]
  local addr="${1:-$DEPLOYER}"
  cast balance "$addr" --rpc-url "$RPC" -e
}

chain_balance_wei() {
  local addr="${1:-$DEPLOYER}"
  cast balance "$addr" --rpc-url "$RPC"
}

chain_call() {
  # Usage: chain_call <address> <sig> [args...]
  local addr="$1"; shift
  local sig="$1"; shift
  cast call "$addr" "$sig" "$@" --rpc-url "$RPC"
}

chain_send() {
  # Usage: chain_send <address> <sig> [args...]
  # Uses THRYXTREASURY_PRIVATE_KEY from env
  local addr="$1"; shift
  local sig="$1"; shift
  cast send "$addr" "$sig" "$@" --private-key "$THRYXTREASURY_PRIVATE_KEY" --rpc-url "$RPC"
}

obsd_real_eth() {
  chain_call "$OBSD_ROUTER" "realETH()(uint256)"
}

obsd_phase() {
  chain_call "$OBSD_ROUTER" "phase()(uint8)"
}

obsd_circulating() {
  chain_call "$OBSD_ROUTER" "circulating()(uint256)"
}

obsd_pending_fees() {
  chain_call "$OBSD_ROUTER" "pendingCreatorFees()(uint256)"
}

obsd_claim_fees() {
  chain_send "$OBSD_ROUTER" "claimFees()"
}

eth_to_human() {
  # Convert wei string to ETH with 6 decimals
  local wei="$1"
  python3 -c "print(f'{int(\"$wei\") / 1e18:.6f}')"
}

get_stage() {
  # Returns current company stage based on ETH balance
  local bal_wei
  bal_wei=$(chain_balance_wei)
  python3 -c "
bal = int('$bal_wei') / 1e18
stages = [(0.01,'SURVIVAL'),(0.1,'SEED'),(1,'GROWTH'),(10,'SCALE'),(float('inf'),'EMPIRE')]
for threshold, name in stages:
    if bal < threshold:
        print(f'{name} ({bal:.6f} ETH)')
        break
"
}
