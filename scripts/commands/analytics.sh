#!/usr/bin/env bash
# ./thryx analytics pull — Pull volume/price data for all tokens

subcmd="${1:-pull}"

analytics_pull() {
  echo "=== Pulling Token Analytics ==="
  local today
  today=$(date -u +%Y-%m-%d)
  local dex_base
  dex_base=$(jq -r '.apis.dexScreener' "$STATE_DIR/config.json")

  # Sync analytics.json with tokens.json (add missing entries)
  local synced
  synced=$(jq -s '
    . as [$tokens, $analytics] |
    ($analytics | map({(.ticker): .}) | add // {}) as $existing |
    [$tokens[] | .ticker as $t |
      if $existing[$t] then $existing[$t]
      else {ticker: $t, address: .address, chain: .chain, volume24h: 0, price: null, fdv: null, txns24h: 0, lastPulled: null}
      end
    ]
  ' "$STATE_DIR/tokens.json" "$STATE_DIR/analytics.json")
  echo "$synced" > "$STATE_DIR/analytics.json"

  # Pull Base chain tokens from DexScreener
  echo "Fetching Base tokens from DexScreener..."

  # Read tokens into array to avoid subshell pipe issue
  local token_list
  token_list=$(jq -r '.[] | select(.chain == "base") | .ticker + "|" + .address' "$STATE_DIR/tokens.json")

  local count=0
  local indexed=0
  while IFS='|' read -r ticker addr; do
    [ -z "$ticker" ] && continue
    count=$((count + 1))

    local data
    data=$(curl -s "$dex_base/tokens/$addr" 2>/dev/null || echo '{}')
    local pairs
    pairs=$(echo "$data" | jq '.pairs // [] | length' 2>/dev/null || echo "0")

    if [ "$pairs" != "0" ] && [ "$pairs" != "" ] && [ "$pairs" != "null" ]; then
      indexed=$((indexed + 1))
      local vol price fdv txns
      vol=$(echo "$data" | jq '.pairs[0].volume.h24 // 0' 2>/dev/null || echo "0")
      price=$(echo "$data" | jq -r '.pairs[0].priceUsd // "null"' 2>/dev/null || echo "null")
      fdv=$(echo "$data" | jq -r '.pairs[0].fdv // "null"' 2>/dev/null || echo "null")
      txns=$(echo "$data" | jq '((.pairs[0].txns.h24.buys // 0) + (.pairs[0].txns.h24.sells // 0))' 2>/dev/null || echo "0")
      echo "  $ticker: vol=\$$vol price=\$$price fdv=\$$fdv txns=$txns"

      # Update analytics.json if the ticker exists there
      local file="$STATE_DIR/analytics.json"
      local tmp="$file.tmp"
      jq --arg t "$ticker" --argjson v "${vol:-0}" --arg p "$price" --arg f "$fdv" \
        --argjson tx "${txns:-0}" --arg d "$today" \
        'map(if .ticker == $t then .volume24h = $v | .price = (if $p == "null" then null else ($p | tonumber) end) | .fdv = (if $f == "null" then null else ($f | tonumber) end) | .txns24h = $tx | .lastPulled = $d else . end)' \
        "$file" > "$tmp" 2>/dev/null && mv "$tmp" "$file"
    else
      echo "  $ticker: no pairs indexed"
    fi

    sleep 0.3
  done <<< "$token_list"

  echo ""
  echo "Checked $count tokens, $indexed indexed on DexScreener."
  echo "=== Analytics Updated ==="
}

case "$subcmd" in
  pull)  analytics_pull ;;
  *)     echo "Usage: ./thryx analytics pull"; exit 1 ;;
esac
