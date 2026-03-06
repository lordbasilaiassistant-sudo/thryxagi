#!/usr/bin/env bash
# ./thryx buy TICKER 0.0001    — buy TICKER with ETH
# ./thryx sell TICKER 1000     — sell TICKER tokens for ETH
# Uses ChildRouter for factory tokens, OBSD Router for OBSD

action="${1:-}"
ticker="${2:-}"
amount="${3:-}"

if [ -z "$action" ] || [ -z "$ticker" ] || [ -z "$amount" ]; then
  echo "Usage:"
  echo "  ./thryx buy TICKER ETH_AMOUNT    (e.g., ./thryx buy WORK 0.0001)"
  echo "  ./thryx sell TICKER TOKEN_AMOUNT  (e.g., ./thryx sell WORK 1000)"
  exit 1
fi

CHILD_ROUTER=$(jq -r '.childRouter.address' "$CONFIG")

# Resolve ticker to address
TOKEN_ADDR=$(jq -r --arg t "$ticker" '.[] | select(.ticker == $t) | .address' "$STATE_DIR/tokens.json")
PLATFORM=$(jq -r --arg t "$ticker" '.[] | select(.ticker == $t) | .platform' "$STATE_DIR/tokens.json")

if [ -z "$TOKEN_ADDR" ] || [ "$TOKEN_ADDR" = "null" ]; then
  echo "ERROR: Ticker $ticker not found in state/tokens.json"
  echo "Available tickers:"
  jq -r '.[] | select(.chain == "base") | "  " + .ticker + " (" + .address + ")"' "$STATE_DIR/tokens.json"
  exit 1
fi

case "$action" in
  buy)
    # Convert ETH amount to wei
    AMOUNT_WEI=$(python3 -c "print(int(float('$amount') * 1e18))")

    if [ "$PLATFORM" = "custom" ] && [ "$ticker" = "OBSD" ]; then
      # Buy OBSD directly through its router
      echo "=== Buying OBSD via Router ==="
      echo "  Amount: $amount ETH ($AMOUNT_WEI wei)"
      BUY_AMOUNT="$AMOUNT_WEI" \
        forge script script/Buy.s.sol \
          --rpc-url "$RPC" \
          --broadcast 2>&1
    else
      # Buy via ChildRouter
      echo "=== Buying $ticker via ChildRouter ==="
      echo "  Token:  $TOKEN_ADDR"
      echo "  Amount: $amount ETH ($AMOUNT_WEI wei)"
      CHILD_TOKEN="$TOKEN_ADDR" BUY_AMOUNT="$AMOUNT_WEI" \
        forge script script/BuyChild.s.sol \
          --rpc-url "$RPC" \
          --broadcast 2>&1
    fi
    ;;

  sell)
    # Convert token amount to wei (18 decimals)
    AMOUNT_WEI=$(python3 -c "print(int(float('$amount') * 1e18))")

    if [ "$PLATFORM" = "custom" ] && [ "$ticker" = "OBSD" ]; then
      # Sell OBSD directly through its router
      echo "=== Selling OBSD via Router ==="
      echo "  Amount: $amount OBSD ($AMOUNT_WEI wei)"
      SELL_AMOUNT="$AMOUNT_WEI" \
        forge script script/MicroSell.s.sol \
          --rpc-url "$RPC" \
          --broadcast 2>&1
    else
      # Sell via ChildRouter
      echo "=== Selling $ticker via ChildRouter ==="
      echo "  Token:  $TOKEN_ADDR"
      echo "  Amount: $amount $ticker ($AMOUNT_WEI wei)"
      CHILD_TOKEN="$TOKEN_ADDR" SELL_AMOUNT="$AMOUNT_WEI" \
        forge script script/SellChild.s.sol \
          --rpc-url "$RPC" \
          --broadcast 2>&1
    fi
    ;;

  *)
    echo "Unknown trade action: $action"
    echo "Use: buy or sell"
    exit 1
    ;;
esac
