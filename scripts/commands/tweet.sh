#!/usr/bin/env bash
# ./thryx tweet <text> | ./thryx tweet next

subcmd="${1:-}"

tweet_post() {
  local text="$1"
  echo "Posting tweet..."
  echo "Text: ${text:0:80}..."

  local result
  result=$(python3 "$PROJECT_ROOT/scripts/lib/twitter.py" "$text" 2>&1)
  local ok
  ok=$(echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('ok', False))" 2>/dev/null || echo "False")

  if [ "$ok" = "True" ]; then
    local tweet_id
    tweet_id=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
    echo "Posted! ID: $tweet_id"
    echo "URL: https://twitter.com/i/web/status/$tweet_id"
    tweet_archive "$text" "$tweet_id"
    echo "Archived to state/tweets.json"
  else
    echo "FAILED: $result"
    echo "Twitter API may be rate-limited or credits depleted."
    return 1
  fi
}

case "$subcmd" in
  next)
    text=$(tweet_pop)
    if [ $? -ne 0 ]; then
      echo "Tweet queue is empty. Add tweets to state/tweets.json queue array."
      exit 1
    fi
    tweet_post "$text"
    ;;
  "")
    echo "Usage: ./thryx tweet <text> | ./thryx tweet next"
    exit 1
    ;;
  *)
    # Treat everything after "tweet" as the tweet text
    tweet_post "$*"
    ;;
esac
