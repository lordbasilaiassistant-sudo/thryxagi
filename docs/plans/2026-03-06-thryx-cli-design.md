# Design: `thryx` CLI — Zero-Friction Agent Automation Layer

> Date: 2026-03-06 | Status: Approved | Author: Thryx

## Problem

Every agent session burns thousands of tokens reading 5-10 markdown files, reasoning through identical workflows, executing multi-step commands manually, then hand-editing markdown tables. A "claim fees" operation costs ~3,000 tokens of agent compute. It should cost ~200.

## Solution

Three layers replacing markdown-as-database + agent-reasoning:

1. **`state/`** — JSON files as single source of truth (machine-readable)
2. **`scripts/`** — Executable workflows that read state, act, update state
3. **`./thryx`** — Bash CLI entry point dispatching to scripts

`ops/` markdown files become generated views — auto-built from JSON, never hand-edited.

## CLI Commands

```bash
./thryx status                          # Full dashboard: balances, tokens, fees, stage
./thryx deploy bankr <name> <ticker>    # Deploy on Bankr + update state + queue tweet
./thryx claim all                       # Claim fees across all platforms
./thryx claim obsd                      # Claim OBSD router fees
./thryx tweet "<text>"                  # Post a tweet
./thryx tweet next                      # Post next from queue
./thryx analytics pull                  # Pull volume/price for all tokens
./thryx treasury                        # Treasury snapshot
./thryx wallet balance                  # All wallet balances
./thryx wallet new                      # Create + register rotation wallet
./thryx help                            # List all commands
```

## Directory Structure

```
state/
  config.json       # Constants: addresses, RPCs, fee rates, thresholds
  tokens.json       # All deployed tokens registry
  wallets.json      # Wallet addresses, deploy counts
  treasury.json     # Balances, revenue, fee accrual
  tweets.json       # Queue (ready) + archive (posted)
  analytics.json    # Token volume, prices, holder counts

scripts/
  lib/
    state.sh        # Read/write state/*.json via jq
    chain.sh        # Cast/forge wrappers with PATH baked in
    config.sh       # Load config.json into shell vars
    api.sh          # curl wrappers for GeckoTerminal, DexScreener
    twitter.py      # OAuth 1.0a tweet posting (proven working approach)
  commands/
    status.sh       # Dashboard
    deploy-bankr.sh # Bankr deploy workflow
    claim-all.sh    # Multi-platform fee claim loop
    claim-obsd.sh   # OBSD router fee claim
    tweet.sh        # Dispatch to twitter.py
    tweet-next.sh   # Pop queue, post, archive
    pull-analytics.sh # API pulls, update analytics.json
    treasury.sh     # On-chain balance reads + state summary
    wallet-balance.sh # Balance check all wallets
    wallet-new.sh   # cast wallet new + register
  gen-ops.sh        # Regenerate ops/*.md from state/*.json

thryx              # Main CLI entry point (bash)
```

## State Schema

### config.json
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
  "fees": {
    "creatorBps": 100,
    "burnBuyBps": 200,
    "sellTaxBps": 300
  },
  "thresholds": {
    "minCompoundEth": "0.005",
    "maxBuyEth": "5",
    "sellCooldown": 300
  },
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

### tokens.json
```json
[
  {
    "name": "Obsidian",
    "ticker": "OBSD",
    "address": "0x291AaF4729BaB2528B08d8fE248272b208Ce84FF",
    "router": "0x2558F30eDB8098861FEf81c8E194ac9DcF714b0E",
    "platform": "custom",
    "chain": "base",
    "wallet": "primary",
    "date": "2026-03-06",
    "feeClaim": "router",
    "status": "active"
  }
]
```

### wallets.json
```json
{
  "primary": {
    "address": "0x7a3E312Ec6e20a9F62fE2405938EB9060312E334",
    "envVar": "THRYXTREASURY_PRIVATE_KEY",
    "bankrDeploys": 10,
    "pumpfunAccount": "thryx"
  },
  "rotation": []
}
```

### tweets.json
```json
{
  "queue": [
    {"text": "Most crypto founders own 10-20% of their token...", "category": "hot-take"},
    {"text": "What is intrinsic value (IV) in DeFi?...", "category": "educational"}
  ],
  "posted": [
    {"text": "Day 1 AI narrative", "id": "2029954176931815918", "date": "2026-03-06"}
  ]
}
```

### treasury.json
```json
{
  "lastUpdated": "2026-03-06",
  "ethBalance": "0.000248",
  "obsdHoldings": "4315622",
  "obsdRealEth": "0.004452",
  "totalRevenue": "0.000048",
  "stage": 0
}
```

### analytics.json
```json
[
  {
    "ticker": "OBSD",
    "volume24h": 6.59,
    "price": 0.0000000543,
    "fdv": 54,
    "txns24h": 51,
    "lastPulled": "2026-03-06"
  }
]
```

## Agent Workflow Comparison

### Before (claim fees — ~3,000 tokens)
```
1. Read ops/workflow-examples.md (184 lines)
2. Read ops/deployed-tokens.md (59 lines)
3. Read ops/treasury.md (191 lines)
4. Reason: which tokens, which platform, which command
5. Run 3-5 cast commands manually
6. Read treasury.md again to update
7. Hand-edit markdown table
```

### After (claim fees — ~200 tokens)
```
1. Run: ./thryx claim all
2. Script outputs results
3. State auto-updated
```

## Design Decisions

- **Bash + jq for orchestration**: No npm install, no package.json, no node_modules. Cast and forge are already bash-native. jq handles JSON.
- **Python for Twitter only**: The OAuth 1.0a flow is proven working in Python. Don't rewrite it.
- **JSON over markdown for state**: Agents shouldn't parse markdown tables. JSON is native to every tool.
- **ops/ becomes generated**: Keeps human-readable views but removes the dual-write problem.
- **No framework**: No Express, no CLI framework, no ORM. Just bash functions dispatching to scripts.
- **Idempotent commands**: Every command can be run multiple times safely. No double-deploys, no double-posts.

## Implementation Priority

1. state/ JSON files — migrate from markdown
2. scripts/lib/ — shared utilities
3. thryx CLI entry point
4. status command (biggest compute saver)
5. claim commands (revenue-critical)
6. tweet commands (marketing-critical)
7. deploy commands (growth-critical)
8. analytics + treasury (reporting)
9. gen-ops.sh (markdown regeneration)
10. Trim CLAUDE.md — point to CLI, remove inline workflows
