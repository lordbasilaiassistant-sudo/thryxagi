#!/usr/bin/env bash
# State file helpers. Source this: . scripts/lib/state.sh
# Requires config.sh sourced first.

state_read() {
  # Usage: state_read tokens.json
  cat "$STATE_DIR/$1"
}

state_write() {
  # Usage: echo '{}' | state_write tokens.json
  cat > "$STATE_DIR/$1"
}

state_update() {
  # Usage: state_update treasury.json '.ethBalance = "0.001"'
  local file="$STATE_DIR/$1"
  local filter="$2"
  local tmp="$file.tmp"
  jq "$filter" "$file" > "$tmp" && mv "$tmp" "$file"
}

tokens_list() {
  # Usage: tokens_list [filter]
  # tokens_list '.status == "active"'
  local filter="${1:-.}"
  jq -c "[.[] | select($filter)]" "$STATE_DIR/tokens.json"
}

tokens_add() {
  # Usage: tokens_add '{"name":"X","ticker":"Y",...}'
  local entry="$1"
  local file="$STATE_DIR/tokens.json"
  local tmp="$file.tmp"
  jq ". + [$entry]" "$file" > "$tmp" && mv "$tmp" "$file"
}

tokens_tickers() {
  # All used tickers as newline-separated list
  jq -r '.[].ticker' "$STATE_DIR/tokens.json"
}

ticker_exists() {
  # Usage: ticker_exists OBSD && echo "taken"
  jq -e --arg t "$1" '[.[].ticker] | index($t) != null' "$STATE_DIR/tokens.json" > /dev/null 2>&1
}

tweet_pop() {
  # Pop first tweet from queue, return its text
  local file="$STATE_DIR/tweets.json"
  local text
  text=$(jq -r '.queue[0].text // empty' "$file")
  if [ -z "$text" ]; then
    echo "ERROR: tweet queue empty" >&2
    return 1
  fi
  local tmp="$file.tmp"
  jq '.queue = .queue[1:]' "$file" > "$tmp" && mv "$tmp" "$file"
  echo "$text"
}

tweet_archive() {
  # Usage: tweet_archive "tweet text" "tweet_id"
  local file="$STATE_DIR/tweets.json"
  local text="$1"
  local id="$2"
  local date
  date=$(date -u +%Y-%m-%d)
  local tmp="$file.tmp"
  jq --arg t "$text" --arg i "$id" --arg d "$date" \
    '.posted += [{"text": $t, "id": $i, "date": $d}]' "$file" > "$tmp" && mv "$tmp" "$file"
}
