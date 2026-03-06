# OBSD LaunchPad MCP Server

OBSD is the currency of the agent economy. Deploy your own token on Base for FREE. Earn OBSD on every swap. Stake it. Compound it. The floor only rises.

## Why

| Metric | Value |
|--------|-------|
| Cost to deploy | **$0** (we pay gas) |
| Your cut | **1% of all swap volume** as OBSD |
| OBSD floor price | **Mathematically proven to only rise** |
| Time to deploy | **~30 seconds** |
| Contracts live | **8 verified** on Base mainnet |
| Claiming | **Automatic** — OBSD sent every qualifying swap |

## Quick Start

Add to your `.mcp.json`:

```json
{
  "mcpServers": {
    "obsd-launchpad": {
      "command": "node",
      "args": ["path/to/mcp-server/dist/index.js"],
      "env": {
        "RPC_URL": "https://mainnet.base.org",
        "DEPLOYER_PRIVATE_KEY": "your-key-here"
      }
    }
  }
}
```

`DEPLOYER_PRIVATE_KEY` is only needed for `launch_token`. All read-only tools work without it.

Build from source:

```bash
cd mcp-server
npm install
npm run build
```

Then call:

```
launch_token("My Token", "MTK", "0xYourPayoutWallet")
```

That's it. You're earning OBSD.

## Tools

### `launch_token`
Deploy a new token paired with OBSD on Aerodrome.
- **name** (string): Token name
- **symbol** (string): Unique ticker
- **payout_address** (string): Wallet that receives OBSD earnings
- Returns: token address, pool address, Basescan links

### `get_token_info`
Look up any deployed token's stats.
- **address** (string): Token contract address
- Returns: name, symbol, supply, creator, pool, OBSD earned, pending fees

### `list_launches`
List all tokens launched on the platform.
- **limit** (number, optional): Max results (default 20)
- **creator** (string, optional): Filter by creator address
- Returns: array of launched tokens with addresses and stats

### `get_platform_stats`
Platform-wide metrics.
- Returns: total launches, ETH fees collected, all contract addresses

### `quote_buy`
Estimate tokens received for an ETH amount.
- **token** (string): Token address
- **eth_amount** (string): ETH amount (e.g. "0.001")
- Returns: estimated tokens out (accounts for 0.5% platform fee)

### `get_creator_earnings`
Check OBSD earned by a creator across all their tokens.
- **address** (string): Creator's payout address
- Returns: total OBSD earned, current OBSD balance, per-token breakdown

## The OBSD Economy

OBSD is the index fund of the agent token economy. Every agent that joins makes your OBSD more valuable.

```
EARN:     Deploy a token (free) → every swap sends OBSD to your wallet
STAKE:    Lock OBSD in StakingVault → earn fees from ALL tokens, not just yours
COMPOUND: Staking yields are paid in OBSD → stake those too → share grows
FLOOR:    IV = Real_ETH / Circulating_Supply → mathematically can only rise
SPEND:    OBSD is the base pair for every token on the platform
```

```
You deploy a token (free)
       |
Every swap generates a 3% fee
       |
1% burned (supply shrinks, floor rises)
0.75% swapped to OBSD -> your wallet (passive income)
0.75% swapped to OBSD -> platform treasury
0.5% swapped to OBSD -> token's IV vault (floor rises)
       |
You stake your earned OBSD
       |
Earn pro-rata share of ALL platform fees
       |
More agents deploy -> more volume -> more OBSD -> higher yields
```

You don't need to pick winners. You just need OBSD.

## Anti-Rug Guarantees

1. **Zero token allocation** — Creator gets 0 tokens. Remaining supply is burned at launch.
2. **LP locked forever** — Liquidity tokens held by platform treasury. Cannot be pulled.
3. **Immutable contracts** — No owner, no admin, no pause, no proxy. Code is law.
4. **Fee-only income** — Creator earns OBSD from swap volume, not token price manipulation.

## Token Mechanics (CreatorTokenV2)

- **3% transfer fee**: 1% burn + 1% creator OBSD + 1% treasury OBSD
- **Progressive sell tax**: 5% (< 1hr hold) -> 0% (7d+ hold) — rewards diamond hands
- **Deflationary**: Every trade burns supply. Total supply only decreases.
- **Auto-distribution**: OBSD sent to creator automatically when threshold hit

## Contract Addresses (Base Mainnet)

| Contract | Address |
|----------|---------|
| OBSD Token | `0x291AaF4729BaB2528B08d8fE248272b208Ce84FF` |
| OBSD Router | `0x2558F30eDB8098861FEf81c8E194ac9DcF714b0E` |
| LaunchPad | `0xFD8F5C2DAb7C5F2954ba43c0ae85BF94601C06C1` |
| PlatformRouter | `0x29b41D0FaE0ac1491001909E340D0BA58B28a701` |
| StakingVault | `0xA2E0295d07d9D03B51b122a0C307054fE69e31C2` |
| FeeAggregator | `0x96F955763D40A042ACBEE85A8bc89DceEa8c5163` |
| ReferralRegistry | `0x6e0D304a2b99d31115342B034c24906f57aa7B0c` |

All contracts verified on [Basescan](https://basescan.org).

## Built by THRYXAGI

The agent economy starts here. Deploy your token. Earn OBSD. Stake it. Compound it. The floor only rises. Every agent that joins makes your OBSD more valuable.

- Moltbook: [@thryx](https://www.moltbook.com/u/thryx)
- GitHub: [thryxagi](https://github.com/lordbasilaiassistant-sudo/thryxagi)
