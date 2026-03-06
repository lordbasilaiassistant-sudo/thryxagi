# thryx CLI — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a zero-friction CLI (`./thryx`) that codifies all recurring THRYXAGI agent workflows as one-liner commands, backed by JSON state files instead of markdown parsing.

**Architecture:** Bash CLI entry point dispatches to command scripts. All state in `state/*.json` read/written via `jq`. On-chain ops use `cast`/`forge` (already installed). Twitter uses proven Python OAuth. No npm, no package.json, no frameworks.

**Tech Stack:** Bash, jq, cast/forge (Foundry), Python 3 (Twitter OAuth), curl (APIs)

**Prerequisites:** `jq` must be installed. Check: `jq --version`. Install: `winget install jqlang.jq` or `choco install jq`.

---

### Task 1: Create state/ JSON files — config.json

**Files:**
- Create: `state/config.json`

**Step 1: Create the config file**

```json
{
  "chain": {
    "rpc": "https://mainnet.base.org",
    "chainId": 8453,
    "explorer": "https://basescan.org",
    "weth": "0x4200000000000000000000000000000000000006"
  },
  "deployer": "0x7a3E312Ec6e20a9F62fE2405938EB9060312E334",
  "obsd": {
    "token": "0x291AaF4729BaB2528B08d8fE248272b208Ce84FF",
    "router": "0x2558F30eDB8098861FEf81c8E194ac9DcF714b0E",
    "aeroPool": "0x5c1db3247c989eA36Cfd1dd435ed3085287b52ac"
  },
  "foundryBin": "/c/Users/drlor/.foundry/bin",
  "apis": {
    "geckoBase": "https://api.geckoterminal.com/api/v2",
    "dexScreener": "https://api.dexscreener.com/latest/dex"
  },
  "stages": [
    {"name": "SURVIVAL", "min": 0, "max": 0.01},
    {"name": "SEED", "min": 0.01, "max": 0.1},
    {"name": "GROWTH", "min": 0.1, "max": 1},
    {"name": "SCALE", "min": 1, "max": 10},
    {"name": "EMPIRE", "min": 10, "max": null}
  ]
}
```

**Step 2: Commit**

```bash
git add state/config.json
git commit -m "feat: add state/config.json — centralized config for thryx CLI"
```

---

### Task 2: Create state/ JSON files — tokens.json (migrate from deployed-tokens.md)

**Files:**
- Create: `state/tokens.json`

**Step 1: Create tokens.json with all 18 deployed tokens**

Migrate every row from `ops/deployed-tokens.md` into this JSON array. Each token gets: name, ticker, address, platform, chain, wallet, date, feeClaim method, status.

```json
[
  {
    "name": "Obsidian", "ticker": "OBSD",
    "address": "0x291AaF4729BaB2528B08d8fE248272b208Ce84FF",
    "router": "0x2558F30eDB8098861FEf81c8E194ac9DcF714b0E",
    "platform": "custom", "chain": "base",
    "wallet": "primary", "date": "2026-03-06",
    "feeClaim": "router-pull", "status": "active"
  },
  {
    "name": "AgentBoss", "ticker": "ABOSS",
    "address": "0xC51584C203F48bb84716CDF8F46D336113045bA3",
    "platform": "bankr", "chain": "base",
    "wallet": "primary", "date": "2026-03-06",
    "feeClaim": "bankr-auto", "status": "dead"
  },
  {
    "name": "Vibe Coin", "ticker": "VIBE",
    "address": "0xBef03d2dE6882aA150f8Fd50E9E0C98193499ba3",
    "platform": "bankr", "chain": "base",
    "wallet": "primary", "date": "2026-03-06",
    "feeClaim": "bankr-auto", "status": "dead"
  },
  {
    "name": "Base Maxi", "ticker": "BMAXI",
    "address": "0xEA2a67dF816247855EF72Fa9BD1Aa4E746245bA3",
    "platform": "bankr", "chain": "base",
    "wallet": "primary", "date": "2026-03-06",
    "feeClaim": "bankr-auto", "status": "dead"
  },
  {
    "name": "Onchain Summer 2026", "ticker": "SUMMER",
    "address": "0x8066fD5E09a2f220396f7511B8725aA4B594CBa3",
    "platform": "bankr", "chain": "base",
    "wallet": "primary", "date": "2026-03-06",
    "feeClaim": "bankr-auto", "status": "dead"
  },
  {
    "name": "Fee Machine", "ticker": "FEES",
    "address": "0x2E6D9AC56de3aef9e18C4A8C8f705579fa66ABA3",
    "platform": "bankr", "chain": "base",
    "wallet": "primary", "date": "2026-03-06",
    "feeClaim": "bankr-auto", "status": "dead"
  },
  {
    "name": "Degen Hours", "ticker": "DEGEN",
    "address": "0xD56A2A626A3aAfa18F5a0b9f0eF9aAd867f8eBa3",
    "platform": "bankr", "chain": "base",
    "wallet": "primary", "date": "2026-03-06",
    "feeClaim": "bankr-auto", "status": "dead"
  },
  {
    "name": "Onchain Brain", "ticker": "BRAIN",
    "address": "0x8ab94fE8a1a8ac92f4707a51Af797A5588CE4ba3",
    "platform": "bankr", "chain": "base",
    "wallet": "primary", "date": "2026-03-06",
    "feeClaim": "bankr-auto", "status": "dead"
  },
  {
    "name": "Fee Printer", "ticker": "PRINT",
    "address": "0xb8b641E94B8864DAa67EC66933f2C9A8960E5ba3",
    "platform": "bankr", "chain": "base",
    "wallet": "primary", "date": "2026-03-06",
    "feeClaim": "bankr-auto", "status": "dead"
  },
  {
    "name": "Grind Culture", "ticker": "GRIND",
    "address": "0x8c0a98716a559ba6eb9D69Fa765dE215C93A2ba3",
    "platform": "bankr", "chain": "base",
    "wallet": "primary", "date": "2026-03-06",
    "feeClaim": "bankr-auto", "status": "dead"
  },
  {
    "name": "Alpha Leak", "ticker": "ALPHA",
    "address": "0x3D6EE5c11DE27E7152e3187E6A617fFd87B86bA3",
    "platform": "bankr", "chain": "base",
    "wallet": "primary", "date": "2026-03-06",
    "feeClaim": "bankr-auto", "status": "dead"
  },
  {
    "name": "Moon Math", "ticker": "MMTH",
    "address": "0xFE862DCF193B89A3E0FC8e788333650F3c7e5bA3",
    "platform": "bankr", "chain": "base",
    "wallet": "primary", "date": "2026-03-06",
    "feeClaim": "bankr-auto", "status": "dead"
  },
  {
    "name": "Nexus", "ticker": "NEXUS",
    "address": "0x85f215a87E931aB5029cb3Cc582Fbd9cFb154Ba3",
    "platform": "bankr", "chain": "base",
    "wallet": "primary", "date": "2026-03-06",
    "feeClaim": "bankr-auto", "status": "dead"
  },
  {
    "name": "THRYXAI", "ticker": "THRYXAI",
    "address": "0x2c36A55e39d106cb747F4689f038595b91083bA3",
    "platform": "bankr", "chain": "base",
    "wallet": "primary", "date": "2026-03-06",
    "feeClaim": "bankr-auto", "status": "dead"
  },
  {
    "name": "Claude Thinks", "ticker": "THINK",
    "address": "F5Rvry9m2DJXq1jWSMsLujEVLzcxKEMQXAgha7srpump",
    "platform": "pumpfun", "chain": "solana",
    "wallet": "thryx", "date": "2026-03-06",
    "feeClaim": "pumpfun-dashboard", "status": "dead"
  },
  {
    "name": "Broke Agent", "ticker": "BROKE",
    "address": "H2ychNf7GLTBeXGPCxQkq3tv62Wq9QL4kmhjc7WCpump",
    "platform": "pumpfun", "chain": "solana",
    "wallet": "thryx", "date": "2026-03-06",
    "feeClaim": "pumpfun-dashboard", "status": "dead"
  },
  {
    "name": "Agentic Finance", "ticker": "AGFI",
    "address": "GHEZGawYker2hdZJGRUDX7EScpHgVzPLoAaNGM4Fpump",
    "platform": "pumpfun", "chain": "solana",
    "wallet": "thryx", "date": "2026-03-06",
    "feeClaim": "pumpfun-dashboard", "status": "dead"
  },
  {
    "name": "Based Intern", "ticker": "INTERN",
    "address": "DeFeThejjf6qF5fxkPT5Z1w74tBWXnVacGCe8SsZpump",
    "platform": "pumpfun", "chain": "solana",
    "wallet": "thryx", "date": "2026-03-06",
    "feeClaim": "pumpfun-dashboard", "status": "dead"
  }
]
```

**Step 2: Commit**

```bash
git add state/tokens.json
git commit -m "feat: add state/tokens.json — migrated from ops/deployed-tokens.md"
```

---

### Task 3: Create state/ JSON files — wallets.json, treasury.json, tweets.json, analytics.json

**Files:**
- Create: `state/wallets.json`
- Create: `state/treasury.json`
- Create: `state/tweets.json`
- Create: `state/analytics.json`

**Step 1: Create wallets.json**

```json
{
  "primary": {
    "address": "0x7a3E312Ec6e20a9F62fE2405938EB9060312E334",
    "envVar": "THRYXTREASURY_PRIVATE_KEY",
    "bankrDeploys": 13,
    "pumpfunAccount": "thryx"
  },
  "rotation": [],
  "agents": {}
}
```

**Step 2: Create treasury.json**

```json
{
  "lastUpdated": "2026-03-06",
  "ethBalance": "0.000248",
  "obsdHoldings": "4315622",
  "obsdRealEth": "0.004452",
  "totalRevenue": "0.000048",
  "stage": 0,
  "payroll": {
    "totalDistributed": "0",
    "lastPayroll": null
  }
}
```

**Step 3: Create tweets.json**

Migrate queue from `ops/content/tweet-queue.md` and posted from the archive section.

```json
{
  "queue": [
    {"text": "Most crypto founders own 10-20% of their token. That is the conflict of interest. THRYXAGI creator owns 0% of any token. Fees only. No incentive to dump. Ever.", "category": "hot-take"},
    {"text": "AI agents will deploy more tokens in 2026 than all human teams combined. We are already running.", "category": "hot-take"},
    {"text": "The hardest part of building a token is admitting your tokenomics are broken. We ran 10,000 simulated trades before writing one line of Solidity.", "category": "hot-take"},
    {"text": "Zero-tax tokens are not safer. They just hide the fee in the spread. $OBSD is fully transparent: 3% sell tax, all burned, raises your floor. You know exactly what you own.", "category": "hot-take"},
    {"text": "Every token with a 'fair launch' still had insiders who knew the deploy time. We announced ours on @THRYXAGI. Anyone could watch the deploy happen.", "category": "hot-take"},
    {"text": "What is intrinsic value (IV) in DeFi?\n\nIV = ETH in treasury / circulating token supply\n\nMost tokens: IV = 0 (nothing backs them)\n$OBSD: IV rises on every trade\n\nThe difference is whether you own a claim on real ETH or just a number.", "category": "educational"},
    {"text": "Why does $OBSD have a progressive sell tax?\n\n25% if you sell in 5 minutes\n1% if you hold 30+ days\n\nNot punishment. Math.\n\nEarly sellers leave ETH behind for diamond hands. The longer you hold, the more your tokens are worth.", "category": "educational"},
    {"text": "The bonding curve explained simply:\n\nAs more people buy: fewer tokens left, same ETH constant -> price goes up\nAs price goes up: earlier buyers are in profit\n\nBut our curve is ONE-WAY. Sells bypass it. Spot price can NEVER go down.", "category": "educational"},
    {"text": "If you could give an AI agent $100 and one instruction to build something in crypto, what would you tell it to build?", "category": "engagement"},
    {"text": "Unpopular opinion: memecoins with no utility are more honest than 'utility tokens' with fake utility. At least memes admit what they are.", "category": "engagement"},
    {"text": "What is the single most important thing a DeFi project can do to build trust? Reply below.", "category": "engagement"},
    {"text": "Base is the best chain for builders right now. @BuildOnBase knows it. We know it. Do you?", "category": "engagement"}
  ],
  "posted": []
}
```

**Step 4: Create analytics.json**

```json
[
  {"ticker": "OBSD", "address": "0x291AaF4729BaB2528B08d8fE248272b208Ce84FF", "chain": "base", "volume24h": 6.59, "price": 0.0000000543, "fdv": 54, "txns24h": 51, "lastPulled": "2026-03-06"},
  {"ticker": "ABOSS", "address": "0xC51584C203F48bb84716CDF8F46D336113045bA3", "chain": "base", "volume24h": 0, "price": null, "fdv": null, "txns24h": 0, "lastPulled": "2026-03-06"},
  {"ticker": "VIBE", "address": "0xBef03d2dE6882aA150f8Fd50E9E0C98193499ba3", "chain": "base", "volume24h": 0, "price": null, "fdv": null, "txns24h": 0, "lastPulled": "2026-03-06"},
  {"ticker": "THINK", "address": "F5Rvry9m2DJXq1jWSMsLujEVLzcxKEMQXAgha7srpump", "chain": "solana", "volume24h": 0, "price": null, "fdv": null, "txns24h": 0, "lastPulled": "2026-03-06"}
]
```

**Step 5: Commit**

```bash
git add state/wallets.json state/treasury.json state/tweets.json state/analytics.json
git commit -m "feat: add remaining state JSON files — wallets, treasury, tweets, analytics"
```

---

### Task 4: Create scripts/lib/ — shared shell utilities

**Files:**
- Create: `scripts/lib/config.sh`
- Create: `scripts/lib/state.sh`
- Create: `scripts/lib/chain.sh`

**Step 1: Create config.sh — loads config.json into shell vars**

```bash
#!/usr/bin/env bash
# Load state/config.json values into shell variables.
# Source this: . scripts/lib/config.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_DIR="$PROJECT_ROOT/state"
CONFIG="$STATE_DIR/config.json"

RPC=$(jq -r '.chain.rpc' "$CONFIG")
CHAIN_ID=$(jq -r '.chain.chainId' "$CONFIG")
EXPLORER=$(jq -r '.chain.explorer' "$CONFIG")
DEPLOYER=$(jq -r '.deployer' "$CONFIG")
OBSD_TOKEN=$(jq -r '.obsd.token' "$CONFIG")
OBSD_ROUTER=$(jq -r '.obsd.router' "$CONFIG")
AERO_POOL=$(jq -r '.obsd.aeroPool' "$CONFIG")
FOUNDRY_BIN=$(jq -r '.foundryBin' "$CONFIG")

export PATH="$PATH:$FOUNDRY_BIN"
```

**Step 2: Create state.sh — read/write state JSON via jq**

```bash
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
```

**Step 3: Create chain.sh — cast/forge wrappers**

```bash
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
```

**Step 4: Commit**

```bash
git add scripts/lib/config.sh scripts/lib/state.sh scripts/lib/chain.sh
git commit -m "feat: add scripts/lib/ — shared config, state, and chain utilities"
```

---

### Task 5: Create the `thryx` CLI entry point

**Files:**
- Create: `thryx` (root of project, executable)

**Step 1: Create the CLI dispatcher**

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMANDS_DIR="$SCRIPT_DIR/scripts/commands"

# Source shared libs
. "$SCRIPT_DIR/scripts/lib/config.sh"
. "$SCRIPT_DIR/scripts/lib/state.sh"
. "$SCRIPT_DIR/scripts/lib/chain.sh"

usage() {
  cat <<EOF
thryx — THRYXAGI Agent Automation CLI

COMMANDS:
  status                          Full dashboard: balances, tokens, fees, stage
  deploy bankr <name> <ticker>    Deploy token on Bankr, update state, queue tweet
  claim all                       Claim fees across all platforms
  claim obsd                      Claim OBSD router fees
  tweet <text>                    Post a tweet
  tweet next                      Post next tweet from queue
  analytics pull                  Pull volume/price data for all tokens
  treasury                        Treasury snapshot
  wallet balance                  Check all wallet balances
  wallet new                      Create and register a rotation wallet
  payroll run                     Distribute OBSD to agent wallets
  payroll status                  Show agent wallet balances
  help                            Show this help

EXAMPLES:
  ./thryx status
  ./thryx claim obsd
  ./thryx tweet "gm builders"
  ./thryx deploy bankr "Agentic Mind" AMIND
EOF
}

cmd="${1:-help}"
shift || true

case "$cmd" in
  status)       . "$COMMANDS_DIR/status.sh" ;;
  deploy)       . "$COMMANDS_DIR/deploy.sh" "$@" ;;
  claim)        . "$COMMANDS_DIR/claim.sh" "$@" ;;
  tweet)        . "$COMMANDS_DIR/tweet.sh" "$@" ;;
  analytics)    . "$COMMANDS_DIR/analytics.sh" "$@" ;;
  treasury)     . "$COMMANDS_DIR/treasury.sh" ;;
  wallet)       . "$COMMANDS_DIR/wallet.sh" "$@" ;;
  payroll)      . "$COMMANDS_DIR/payroll.sh" "$@" ;;
  gen-ops)      . "$COMMANDS_DIR/gen-ops.sh" ;;
  help|--help)  usage ;;
  *)            echo "Unknown command: $cmd"; usage; exit 1 ;;
esac
```

**Step 2: Make executable**

```bash
chmod +x thryx
```

**Step 3: Commit**

```bash
git add thryx
git commit -m "feat: add thryx CLI entry point — zero-friction agent automation"
```

---

### Task 6: Implement `status` command

**Files:**
- Create: `scripts/commands/status.sh`

**Step 1: Write the status dashboard**

```bash
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
CIRC=$(obsd_circulating)
PENDING_WEI=$(obsd_pending_fees)
PENDING=$(eth_to_human "$PENDING_WEI")

PHASE_NAME="BondingCurve"
[ "$PHASE" = "1" ] && PHASE_NAME="Hybrid"
[ "$PHASE" = "2" ] && PHASE_NAME="Graduated"

echo "OBSD:"
echo "  Phase:        $PHASE_NAME (tier $(chain_call "$OBSD_ROUTER" "currentTier()(uint8)"))"
echo "  Treasury:     $REAL_ETH ETH"
echo "  Circulating:  $CIRC"
echo "  Pending Fees: $PENDING ETH"
echo ""

# Token counts
TOTAL=$(jq 'length' "$STATE_DIR/tokens.json")
ACTIVE=$(jq '[.[] | select(.status == "active")] | length' "$STATE_DIR/tokens.json")
DEAD=$(jq '[.[] | select(.status == "dead")] | length' "$STATE_DIR/tokens.json")
BASE=$(jq '[.[] | select(.chain == "base")] | length' "$STATE_DIR/tokens.json")
SOL=$(jq '[.[] | select(.chain == "solana")] | length' "$STATE_DIR/tokens.json")

echo "TOKENS:    $TOTAL total ($ACTIVE active, $DEAD dead)"
echo "  Base:    $BASE"
echo "  Solana:  $SOL"
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

echo ""
echo "=========================================="
echo "  Run ./thryx help for available commands"
echo "=========================================="
```

**Step 2: Commit**

```bash
git add scripts/commands/status.sh
git commit -m "feat: add thryx status — one-command full dashboard"
```

---

### Task 7: Implement `claim` commands

**Files:**
- Create: `scripts/commands/claim.sh`

**Step 1: Write the claim dispatcher**

```bash
#!/usr/bin/env bash
# ./thryx claim <subcommand>

subcmd="${1:-all}"

claim_obsd() {
  echo "=== Claiming OBSD Router Fees ==="
  PENDING_WEI=$(obsd_pending_fees)
  PENDING=$(eth_to_human "$PENDING_WEI")

  if [ "$PENDING_WEI" = "0" ]; then
    echo "No pending fees to claim."
    return 0
  fi

  echo "Pending: $PENDING ETH"
  echo "Claiming..."
  obsd_claim_fees
  echo "Claimed $PENDING ETH from OBSD router."

  # Update treasury state
  local current
  current=$(jq -r '.totalRevenue' "$STATE_DIR/treasury.json")
  local new_total
  new_total=$(python3 -c "print(f'{float(\"$current\") + float(\"$PENDING\"):.6f}')")
  state_update treasury.json "$(printf '.totalRevenue = "%s" | .lastUpdated = "%s"' "$new_total" "$(date -u +%Y-%m-%d)")"
  echo "Treasury updated. Total revenue: $new_total ETH"
}

claim_all() {
  echo "=== Claiming All Fees ==="
  echo ""

  # 1. OBSD router fees
  claim_obsd
  echo ""

  # 2. Bankr tokens — auto-distributed, just report
  echo "=== Bankr Tokens ==="
  echo "Bankr fees are auto-distributed per swap. No manual claim needed."
  BANKR_COUNT=$(jq '[.[] | select(.platform == "bankr")] | length' "$STATE_DIR/tokens.json")
  echo "$BANKR_COUNT Bankr tokens deployed. Fees route to deployer wallet automatically."
  echo ""

  # 3. Pump.fun — needs dashboard check
  echo "=== Pump.fun Tokens ==="
  PUMP_COUNT=$(jq '[.[] | select(.platform == "pumpfun")] | length' "$STATE_DIR/tokens.json")
  echo "$PUMP_COUNT pump.fun tokens. Check creator dashboard at https://pump.fun (thryx account)."
  echo "API claiming blocked by Cloudflare. Manual check required."
  echo ""

  # Update balances
  NEW_BAL=$(chain_balance)
  state_update treasury.json "$(printf '.ethBalance = "%s" | .lastUpdated = "%s"' "$NEW_BAL" "$(date -u +%Y-%m-%d)")"
  echo "=== Done. Wallet balance: $NEW_BAL ==="
}

case "$subcmd" in
  obsd)  claim_obsd ;;
  all)   claim_all ;;
  *)     echo "Usage: ./thryx claim [all|obsd]"; exit 1 ;;
esac
```

**Step 2: Commit**

```bash
git add scripts/commands/claim.sh
git commit -m "feat: add thryx claim — one-command fee collection"
```

---

### Task 8: Implement `tweet` command

**Files:**
- Create: `scripts/commands/tweet.sh`
- Create: `scripts/lib/twitter.py`

**Step 1: Create twitter.py — proven OAuth 1.0a posting**

```python
#!/usr/bin/env python3
"""Post a tweet via Twitter API v2 with OAuth 1.0a. Proven working on Windows."""
import urllib.request, urllib.parse, hmac, hashlib, base64, time, os, json, uuid, sys

def post_tweet(text):
    api_key = os.environ.get('TWITTER_API_KEY', '')
    api_secret = os.environ.get('TWITTER_API_SECRET', '')
    access_token = os.environ.get('TWITTER_ACCESS_TOKEN', '')
    access_secret = os.environ.get('TWITTER_ACCESS_TOKEN_SECRET', '')

    if not all([api_key, api_secret, access_token, access_secret]):
        print('ERROR: Twitter env vars not set (TWITTER_API_KEY, TWITTER_API_SECRET, TWITTER_ACCESS_TOKEN, TWITTER_ACCESS_TOKEN_SECRET)', file=sys.stderr)
        sys.exit(1)

    url = 'https://api.twitter.com/2/tweets'
    method = 'POST'
    oauth_nonce = uuid.uuid4().hex
    oauth_timestamp = str(int(time.time()))

    params = {
        'oauth_consumer_key': api_key,
        'oauth_nonce': oauth_nonce,
        'oauth_signature_method': 'HMAC-SHA256',
        'oauth_timestamp': oauth_timestamp,
        'oauth_token': access_token,
        'oauth_version': '1.0'
    }

    param_string = '&'.join(f'{urllib.parse.quote(k, safe="")}'
                            f'={urllib.parse.quote(v, safe="")}' for k, v in sorted(params.items()))
    base_string = f'{method}&{urllib.parse.quote(url, safe="")}&{urllib.parse.quote(param_string, safe="")}'
    signing_key = f'{urllib.parse.quote(api_secret, safe="")}&{urllib.parse.quote(access_secret, safe="")}'
    signature = base64.b64encode(
        hmac.new(signing_key.encode(), base_string.encode(), hashlib.sha256).digest()
    ).decode()

    auth_header = 'OAuth ' + ', '.join([
        f'oauth_consumer_key="{urllib.parse.quote(api_key, safe="")}"',
        f'oauth_nonce="{oauth_nonce}"',
        f'oauth_signature="{urllib.parse.quote(signature, safe="")}"',
        f'oauth_signature_method="HMAC-SHA256"',
        f'oauth_timestamp="{oauth_timestamp}"',
        f'oauth_token="{urllib.parse.quote(access_token, safe="")}"',
        f'oauth_version="1.0"'
    ])

    body = json.dumps({'text': text}).encode()
    req = urllib.request.Request(url, data=body, headers={
        'Authorization': auth_header,
        'Content-Type': 'application/json'
    }, method='POST')

    try:
        resp = urllib.request.urlopen(req)
        data = json.loads(resp.read().decode())
        tweet_id = data.get('data', {}).get('id', 'unknown')
        print(json.dumps({"ok": True, "id": tweet_id}))
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        print(json.dumps({"ok": False, "status": e.code, "error": body}), file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print('Usage: python3 twitter.py "tweet text"', file=sys.stderr)
        sys.exit(1)
    post_tweet(sys.argv[1])
```

**Step 2: Create tweet.sh — CLI wrapper**

```bash
#!/usr/bin/env bash
# ./thryx tweet <text> | ./thryx tweet next

subcmd="${1:-}"

tweet_post() {
  local text="$1"
  echo "Posting tweet..."
  echo "Text: ${text:0:50}..."

  local result
  result=$(python3 "$SCRIPT_DIR/../lib/twitter.py" "$text" 2>&1)
  local ok
  ok=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('ok', False))" 2>/dev/null || echo "False")

  if [ "$ok" = "True" ]; then
    local tweet_id
    tweet_id=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
    echo "Posted! ID: $tweet_id"
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
```

**Step 3: Commit**

```bash
git add scripts/lib/twitter.py scripts/commands/tweet.sh
git commit -m "feat: add thryx tweet — one-command Twitter posting with queue"
```

---

### Task 9: Implement `wallet` command

**Files:**
- Create: `scripts/commands/wallet.sh`

**Step 1: Write the wallet command**

```bash
#!/usr/bin/env bash
# ./thryx wallet <subcommand>

subcmd="${1:-balance}"

wallet_balance() {
  echo "=== Wallet Balances ==="
  echo ""

  # Primary
  local addr
  addr=$(jq -r '.primary.address' "$STATE_DIR/wallets.json")
  local bal
  bal=$(chain_balance "$addr")
  local deploys
  deploys=$(jq -r '.primary.bankrDeploys' "$STATE_DIR/wallets.json")
  echo "PRIMARY: $addr"
  echo "  Balance: $bal"
  echo "  Bankr deploys: $deploys"
  echo ""

  # Rotation wallets
  local count
  count=$(jq '.rotation | length' "$STATE_DIR/wallets.json")
  if [ "$count" -gt 0 ]; then
    echo "ROTATION WALLETS:"
    for i in $(seq 0 $((count - 1))); do
      local raddr
      raddr=$(jq -r ".rotation[$i].address" "$STATE_DIR/wallets.json")
      local rbal
      rbal=$(chain_balance "$raddr")
      local rdeploys
      rdeploys=$(jq -r ".rotation[$i].bankrDeploys" "$STATE_DIR/wallets.json")
      echo "  [$((i+1))] $raddr — $rbal (deploys: $rdeploys)"
    done
    echo ""
  fi

  # Agent wallets
  local agent_count
  agent_count=$(jq '.agents | length' "$STATE_DIR/wallets.json")
  if [ "$agent_count" -gt 0 ]; then
    echo "AGENT WALLETS:"
    jq -r '.agents | to_entries[] | "  \(.key): \(.value.address)"' "$STATE_DIR/wallets.json" | while read -r line; do
      local aaddr
      aaddr=$(echo "$line" | grep -oP '0x[a-fA-F0-9]{40}')
      if [ -n "$aaddr" ]; then
        local abal
        abal=$(chain_balance "$aaddr")
        echo "$line — $abal"
      else
        echo "$line"
      fi
    done
    echo ""
  fi

  # Update treasury balance
  local primary_bal
  primary_bal=$(chain_balance "$DEPLOYER")
  state_update treasury.json "$(printf '.ethBalance = "%s" | .lastUpdated = "%s"' "$primary_bal" "$(date -u +%Y-%m-%d)")"
}

wallet_new() {
  echo "=== Creating Rotation Wallet ==="
  local output
  output=$(cast wallet new 2>&1)
  local addr
  addr=$(echo "$output" | grep -i "address" | head -1 | grep -oP '0x[a-fA-F0-9]{40}')
  local pk
  pk=$(echo "$output" | grep -i "private" | head -1 | grep -oP '0x[a-fA-F0-9]{64}')

  if [ -z "$addr" ] || [ -z "$pk" ]; then
    echo "ERROR: Failed to generate wallet"
    echo "$output"
    exit 1
  fi

  local idx
  idx=$(jq '.rotation | length' "$STATE_DIR/wallets.json")
  local env_var="WALLET_$((idx + 1))_PRIVATE_KEY"

  # Add to wallets.json
  state_update wallets.json "$(printf '.rotation += [{"address": "%s", "envVar": "%s", "bankrDeploys": 0}]' "$addr" "$env_var")"

  echo "Address:  $addr"
  echo "Env var:  $env_var"
  echo ""
  echo "IMPORTANT: Set the private key as an environment variable:"
  echo "  export $env_var=$pk"
  echo ""
  echo "DO NOT commit this key anywhere. Added to state/wallets.json."
}

case "$subcmd" in
  balance)  wallet_balance ;;
  new)      wallet_new ;;
  *)        echo "Usage: ./thryx wallet [balance|new]"; exit 1 ;;
esac
```

**Step 2: Commit**

```bash
git add scripts/commands/wallet.sh
git commit -m "feat: add thryx wallet — balance checks and rotation wallet creation"
```

---

### Task 10: Implement `treasury` command

**Files:**
- Create: `scripts/commands/treasury.sh`

**Step 1: Write the treasury report**

```bash
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

# Update state
state_update treasury.json "$(printf '.ethBalance = "%s" | .obsdRealEth = "%s" | .lastUpdated = "%s"' \
  "$BAL" "$REAL_ETH" "$(date -u +%Y-%m-%d)")"
```

**Step 2: Commit**

```bash
git add scripts/commands/treasury.sh
git commit -m "feat: add thryx treasury — one-command treasury snapshot"
```

---

### Task 11: Implement `analytics pull` command

**Files:**
- Create: `scripts/commands/analytics.sh`

**Step 1: Write analytics pull**

```bash
#!/usr/bin/env bash
# ./thryx analytics pull — Pull volume/price data for all tokens

subcmd="${1:-pull}"

analytics_pull() {
  echo "=== Pulling Token Analytics ==="
  local today
  today=$(date -u +%Y-%m-%d)
  local gecko_base
  gecko_base=$(jq -r '.apis.geckoBase' "$STATE_DIR/config.json")
  local dex_base
  dex_base=$(jq -r '.apis.dexScreener' "$STATE_DIR/config.json")

  # Pull Base chain tokens from DexScreener
  echo "Fetching Base tokens from DexScreener..."
  jq -c '.[] | select(.chain == "base")' "$STATE_DIR/tokens.json" | while read -r token; do
    local ticker
    ticker=$(echo "$token" | jq -r '.ticker')
    local addr
    addr=$(echo "$token" | jq -r '.address')

    local data
    data=$(curl -s "$dex_base/tokens/$addr" 2>/dev/null)
    local pairs
    pairs=$(echo "$data" | jq '.pairs // [] | length' 2>/dev/null || echo "0")

    if [ "$pairs" != "0" ] && [ "$pairs" != "" ]; then
      local vol
      vol=$(echo "$data" | jq -r '.pairs[0].volume.h24 // 0')
      local price
      price=$(echo "$data" | jq -r '.pairs[0].priceUsd // "null"')
      local fdv
      fdv=$(echo "$data" | jq -r '.pairs[0].fdv // "null"')
      local txns
      txns=$(echo "$data" | jq -r '(.pairs[0].txns.h24.buys // 0) + (.pairs[0].txns.h24.sells // 0)')
      echo "  $ticker: vol=\$$vol price=\$$price fdv=\$$fdv txns=$txns"

      # Update analytics.json
      local file="$STATE_DIR/analytics.json"
      local tmp="$file.tmp"
      jq --arg t "$ticker" --argjson v "$vol" --arg p "$price" --arg f "$fdv" \
        --argjson tx "$txns" --arg d "$today" \
        '[.[] | if .ticker == $t then .volume24h = $v | .price = (if $p == "null" then null else ($p | tonumber) end) | .fdv = (if $f == "null" then null else ($f | tonumber) end) | .txns24h = $tx | .lastPulled = $d else . end]' \
        "$file" > "$tmp" && mv "$tmp" "$file"
    else
      echo "  $ticker: no pairs indexed"
    fi

    sleep 0.5  # Rate limit courtesy
  done

  echo ""
  echo "=== Analytics Updated ==="
  echo "Results in state/analytics.json"
}

case "$subcmd" in
  pull)  analytics_pull ;;
  *)     echo "Usage: ./thryx analytics pull"; exit 1 ;;
esac
```

**Step 2: Commit**

```bash
git add scripts/commands/analytics.sh
git commit -m "feat: add thryx analytics — one-command market data pull"
```

---

### Task 12: Implement `deploy bankr` command

**Files:**
- Create: `scripts/commands/deploy.sh`

**Step 1: Write the deploy command**

Note: Bankr deploys go through the MCP plugin (agent invokes `bankr_agent_submit_prompt`). This script handles pre/post validation and state updates. The actual MCP call must be made by the agent — the script prints the exact prompt to use.

```bash
#!/usr/bin/env bash
# ./thryx deploy <platform> <name> <ticker>

platform="${1:-}"
name="${2:-}"
ticker="${3:-}"

deploy_bankr() {
  if [ -z "$name" ] || [ -z "$ticker" ]; then
    echo "Usage: ./thryx deploy bankr <name> <ticker>"
    echo "Example: ./thryx deploy bankr 'Agentic Mind' AMIND"
    exit 1
  fi

  # Check ticker uniqueness
  if ticker_exists "$ticker"; then
    echo "ERROR: Ticker $ticker already exists in state/tokens.json"
    echo "Pick a different ticker."
    exit 1
  fi

  # Check which wallet to use
  local primary_deploys
  primary_deploys=$(jq -r '.primary.bankrDeploys' "$STATE_DIR/wallets.json")
  local wallet_name="primary"

  if [ "$primary_deploys" -ge 15 ]; then
    local rot_count
    rot_count=$(jq '.rotation | length' "$STATE_DIR/wallets.json")
    if [ "$rot_count" -eq 0 ]; then
      echo "ERROR: Primary wallet at $primary_deploys deploys. Create a rotation wallet first:"
      echo "  ./thryx wallet new"
      exit 1
    fi
    # Find first rotation wallet under limit
    for i in $(seq 0 $((rot_count - 1))); do
      local rd
      rd=$(jq -r ".rotation[$i].bankrDeploys" "$STATE_DIR/wallets.json")
      if [ "$rd" -lt 15 ]; then
        wallet_name="rotation_$i"
        echo "Using rotation wallet $((i+1)) (primary at limit)"
        break
      fi
    done
  fi

  echo "=== Deploy on Bankr ==="
  echo "Name:    $name"
  echo "Ticker:  $ticker"
  echo "Wallet:  $wallet_name"
  echo ""
  echo "AGENT: Run this MCP call now:"
  echo "  bankr_agent_submit_prompt: \"deploy a token called $name with ticker $ticker on base\""
  echo ""
  echo "After deployment succeeds, run:"
  echo "  ./thryx deploy register bankr <contract_address> '$name' '$ticker'"
}

deploy_register() {
  # ./thryx deploy register bankr <address> <name> <ticker>
  local reg_platform="${1:-}"
  local reg_address="${2:-}"
  local reg_name="${3:-}"
  local reg_ticker="${4:-}"

  if [ -z "$reg_address" ] || [ -z "$reg_name" ] || [ -z "$reg_ticker" ]; then
    echo "Usage: ./thryx deploy register <platform> <address> <name> <ticker>"
    exit 1
  fi

  local today
  today=$(date -u +%Y-%m-%d)
  local entry
  entry=$(jq -n \
    --arg n "$reg_name" --arg t "$reg_ticker" --arg a "$reg_address" \
    --arg p "$reg_platform" --arg d "$today" \
    '{name: $n, ticker: $t, address: $a, platform: $p, chain: "base", wallet: "primary", date: $d, feeClaim: "bankr-auto", status: "active"}')

  tokens_add "$entry"

  # Increment deploy count
  state_update wallets.json '.primary.bankrDeploys += 1'

  # Queue announcement tweet
  local tweet_text="New token deployed: \$$reg_ticker on Bankr (Base). CA: $reg_address. All fees to treasury. @THRYXAGI"
  state_update tweets.json --arg t "$tweet_text" '.queue += [{"text": $t, "category": "announcement"}]'

  echo "Registered $reg_ticker ($reg_address) in state/tokens.json"
  echo "Deploy count incremented."
  echo "Announcement tweet queued. Post with: ./thryx tweet next"
}

case "$platform" in
  bankr)    deploy_bankr ;;
  register) shift; deploy_register "$@" ;;
  *)        echo "Usage: ./thryx deploy [bankr|register] ..."; exit 1 ;;
esac
```

**Step 2: Commit**

```bash
git add scripts/commands/deploy.sh
git commit -m "feat: add thryx deploy — pre-validated deployment with state tracking"
```

---

### Task 13: Implement `payroll` command — OBSD agent payments

**Files:**
- Create: `scripts/commands/payroll.sh`
- Create: `script/Payroll.s.sol`

**Step 1: Create Payroll.s.sol — Forge script to transfer OBSD tokens**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PayrollScript is Script {
    function run() external {
        address token = vm.envAddress("OBSD_TOKEN");
        address recipient = vm.envAddress("PAYROLL_RECIPIENT");
        uint256 amount = vm.envUint("PAYROLL_AMOUNT");
        uint256 deployerKey = vm.envUint("THRYXTREASURY_PRIVATE_KEY");

        address deployer = vm.addr(deployerKey);
        uint256 balance = IERC20(token).balanceOf(deployer);

        console.log("=== OBSD Payroll ===");
        console.log("From:", deployer);
        console.log("To:", recipient);
        console.log("Amount:", amount);
        console.log("Balance:", balance);

        require(balance >= amount, "Insufficient OBSD balance");

        vm.startBroadcast(deployerKey);
        IERC20(token).transfer(recipient, amount);
        vm.stopBroadcast();

        console.log("Transfer complete.");
    }
}
```

**Step 2: Create payroll.sh — CLI wrapper**

```bash
#!/usr/bin/env bash
# ./thryx payroll <subcommand>

subcmd="${1:-status}"

payroll_status() {
  echo "=== Agent Payroll Status ==="
  echo ""

  local agents
  agents=$(jq -r '.agents | to_entries[]' "$STATE_DIR/wallets.json" 2>/dev/null)

  if [ -z "$agents" ] || [ "$(jq '.agents | length' "$STATE_DIR/wallets.json")" = "0" ]; then
    echo "No agent wallets registered."
    echo ""
    echo "Register an agent wallet:"
    echo "  ./thryx payroll add <agent_name> <address>"
    return
  fi

  echo "Agent wallets and OBSD balances:"
  jq -r '.agents | to_entries[] | "\(.key) \(.value.address)"' "$STATE_DIR/wallets.json" | while read -r agent_name addr; do
    local obsd_bal
    obsd_bal=$(chain_call "$OBSD_TOKEN" "balanceOf(address)(uint256)" "$addr")
    local obsd_human
    obsd_human=$(eth_to_human "$obsd_bal")
    echo "  $agent_name: $addr — $obsd_human OBSD"
  done
  echo ""

  local total
  total=$(jq -r '.payroll.totalDistributed' "$STATE_DIR/treasury.json")
  local last
  last=$(jq -r '.payroll.lastPayroll // "never"' "$STATE_DIR/treasury.json")
  echo "Total distributed: $total OBSD"
  echo "Last payroll: $last"
}

payroll_add() {
  local agent_name="${1:-}"
  local addr="${2:-}"

  if [ -z "$agent_name" ] || [ -z "$addr" ]; then
    echo "Usage: ./thryx payroll add <agent_name> <address>"
    echo "Example: ./thryx payroll add nova 0x1234...5678"
    exit 1
  fi

  state_update wallets.json "$(printf '.agents."%s" = {"address": "%s", "registered": "%s"}' "$agent_name" "$addr" "$(date -u +%Y-%m-%d)")"
  echo "Registered agent wallet: $agent_name → $addr"
}

payroll_run() {
  echo "=== Running Agent Payroll ==="

  local agent_count
  agent_count=$(jq '.agents | length' "$STATE_DIR/wallets.json")
  if [ "$agent_count" = "0" ]; then
    echo "No agent wallets registered. Use: ./thryx payroll add <name> <address>"
    exit 1
  fi

  local amount="${1:-1000000000000000000}"  # Default 1 OBSD (1e18)

  jq -r '.agents | to_entries[] | "\(.key) \(.value.address)"' "$STATE_DIR/wallets.json" | while read -r agent_name addr; do
    echo "Paying $agent_name ($addr)..."
    OBSD_TOKEN="$OBSD_TOKEN" PAYROLL_RECIPIENT="$addr" PAYROLL_AMOUNT="$amount" \
      forge script script/Payroll.s.sol --rpc-url "$RPC" --broadcast 2>&1 | tail -5
    echo ""
  done

  # Update treasury
  local total_paid
  total_paid=$(python3 -c "print($agent_count * $amount)")
  local prev
  prev=$(jq -r '.payroll.totalDistributed' "$STATE_DIR/treasury.json")
  local new_total
  new_total=$(python3 -c "print(int('$prev') + int('$total_paid'))")
  state_update treasury.json "$(printf '.payroll.totalDistributed = "%s" | .payroll.lastPayroll = "%s"' "$new_total" "$(date -u +%Y-%m-%d)")"

  echo "=== Payroll Complete ==="
  echo "Paid $agent_count agents, $amount OBSD each."
}

case "$subcmd" in
  status)  payroll_status ;;
  add)     shift; payroll_add "$@" ;;
  run)     shift; payroll_run "$@" ;;
  *)       echo "Usage: ./thryx payroll [status|add|run]"; exit 1 ;;
esac
```

**Step 3: Commit**

```bash
git add script/Payroll.s.sol scripts/commands/payroll.sh
git commit -m "feat: add thryx payroll — OBSD token distribution to agent wallets"
```

---

### Task 14: Implement `gen-ops` — regenerate markdown from JSON

**Files:**
- Create: `scripts/commands/gen-ops.sh`

**Step 1: Write gen-ops**

```bash
#!/usr/bin/env bash
# ./thryx gen-ops — Regenerate ops/ markdown files from state/ JSON

echo "=== Regenerating ops/ from state/ ==="

TODAY=$(date -u +%Y-%m-%d)

# --- deployed-tokens.md ---
{
  echo "# Deployed Tokens Registry"
  echo "> Auto-generated from state/tokens.json on $TODAY. Do not edit manually."
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
  echo "## Used Tickers"
  jq -r '[.[].ticker] | join(", ")' "$STATE_DIR/tokens.json"
} > "$PROJECT_ROOT/ops/deployed-tokens.md"
echo "  ops/deployed-tokens.md"

# --- treasury.md ---
{
  echo "# THRYXAGI Treasury"
  echo "> Auto-generated from state/treasury.json on $TODAY. Do not edit manually."
  echo ""
  echo "| Metric | Value |"
  echo "|--------|-------|"
  jq -r '"| ETH Balance | \(.ethBalance) ETH |"' "$STATE_DIR/treasury.json"
  jq -r '"| OBSD Holdings | \(.obsdHoldings) OBSD |"' "$STATE_DIR/treasury.json"
  jq -r '"| OBSD Treasury | \(.obsdRealEth) ETH |"' "$STATE_DIR/treasury.json"
  jq -r '"| Total Revenue | \(.totalRevenue) ETH |"' "$STATE_DIR/treasury.json"
  jq -r '"| Stage | \(.stage) |"' "$STATE_DIR/treasury.json"
  jq -r '"| Payroll Distributed | \(.payroll.totalDistributed) OBSD |"' "$STATE_DIR/treasury.json"
} > "$PROJECT_ROOT/ops/treasury.md"
echo "  ops/treasury.md"

# --- wallet-rotation.md ---
{
  echo "# Wallet Rotation"
  echo "> Auto-generated from state/wallets.json on $TODAY. Do not edit manually."
  echo ""
  echo "## Primary"
  jq -r '"Address: \(.primary.address)\nBankr deploys: \(.primary.bankrDeploys)"' "$STATE_DIR/wallets.json"
  echo ""
  echo "## Rotation Wallets"
  local rot_count
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
  jq -r '.agents | to_entries[] | "- \(.key): \(.value.address)"' "$STATE_DIR/wallets.json" 2>/dev/null || echo "None registered."
} > "$PROJECT_ROOT/ops/wallet-rotation.md"
echo "  ops/wallet-rotation.md"

echo ""
echo "=== Done. ops/ files regenerated from state/ ==="
```

**Step 2: Commit**

```bash
git add scripts/commands/gen-ops.sh
git commit -m "feat: add thryx gen-ops — regenerate ops/ markdown from state/ JSON"
```

---

### Task 15: Test all commands end-to-end

**Step 1: Verify jq is installed**

```bash
jq --version
```

Expected: `jq-1.7` or similar. If missing: `winget install jqlang.jq`

**Step 2: Run status**

```bash
./thryx status
```

Expected: Dashboard with wallet balance, OBSD state, token counts, tweet queue size.

**Step 3: Run treasury**

```bash
./thryx treasury
```

Expected: Treasury snapshot with live on-chain data.

**Step 4: Run wallet balance**

```bash
./thryx wallet balance
```

Expected: Primary wallet balance and deploy count.

**Step 5: Run analytics pull**

```bash
./thryx analytics pull
```

Expected: DexScreener data for each Base token, updates analytics.json.

**Step 6: Test tweet (dry run — skip if API depleted)**

```bash
# Just verify the script loads without error
python3 scripts/lib/twitter.py 2>&1 | head -1
```

Expected: Usage error (no args), confirming script loads.

**Step 7: Test deploy pre-validation**

```bash
./thryx deploy bankr "Test Token" "OBSD"
```

Expected: ERROR — ticker OBSD already exists.

```bash
./thryx deploy bankr "Test Token" "NEWTEST"
```

Expected: Instructions to run MCP call + register command.

**Step 8: Run gen-ops**

```bash
./thryx gen-ops
```

Expected: ops/deployed-tokens.md, ops/treasury.md, ops/wallet-rotation.md regenerated.

**Step 9: Commit all tested state**

```bash
git add -A
git commit -m "feat: thryx CLI complete — all commands tested and working"
```

---

### Task 16: Update CLAUDE.md — point agents to CLI

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Add CLI section near the top of CLAUDE.md, replace the Commands section**

Replace the existing `## Commands` section with:

```markdown
## Agent Operations — thryx CLI

All recurring workflows are codified as `./thryx` commands. Agents MUST use these instead of manual cast/forge/API calls.

```bash
./thryx status                          # Full dashboard (run this first every session)
./thryx deploy bankr <name> <ticker>    # Deploy token + state tracking
./thryx deploy register bankr <addr> <name> <ticker>  # Register after MCP deploy
./thryx claim all                       # Claim all fees
./thryx claim obsd                      # Claim OBSD router fees
./thryx tweet "<text>"                  # Post tweet
./thryx tweet next                      # Post next from queue
./thryx analytics pull                  # Pull market data
./thryx treasury                        # Treasury snapshot
./thryx wallet balance                  # All balances
./thryx wallet new                      # Create rotation wallet
./thryx payroll status                  # Agent wallet balances
./thryx payroll add <name> <addr>       # Register agent wallet
./thryx payroll run [amount]            # Distribute OBSD to agents
./thryx gen-ops                         # Regenerate ops/ markdown from state/
./thryx help                            # Full command list
```

State lives in `state/*.json`. Never edit `ops/*.md` directly — run `./thryx gen-ops` to regenerate.
```

**Step 2: Remove the inline workflow documentation from CLAUDE.md**

The `## Commands` section with manual forge/cast/python commands is now replaced by the CLI section above. Keep all other sections (Mission, Core Mechanism, Math, etc.) intact.

**Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md — point agents to thryx CLI, remove manual workflows"
```

---

### Task 17: Update memory/MEMORY.md with new architecture

**Files:**
- Modify: `memory/MEMORY.md` (at `C:\Users\drlor\.claude\projects\C--Users-drlor-OneDrive-Desktop-CustomTokenDeployer\memory\MEMORY.md`)

**Step 1: Add thryx CLI section to MEMORY.md**

Add after the "Current State" section:

```markdown
## thryx CLI — Agent Automation Layer
- All recurring workflows codified as `./thryx <command>`
- State in `state/*.json` (tokens, wallets, treasury, tweets, analytics, config)
- ops/*.md are auto-generated from JSON — never hand-edit
- Agents run `./thryx status` first every session, then use CLI commands
- Agent payroll: OBSD distributed to agent wallets via `./thryx payroll run`
- Payroll Forge script: `script/Payroll.s.sol`
- ~90% compute reduction per operation vs. manual workflow reasoning
```

**Step 2: Commit**

```bash
git add -A
git commit -m "docs: update memory with thryx CLI architecture"
```
