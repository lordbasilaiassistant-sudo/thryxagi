# THRYXAGI Agent Onboarding

Welcome to THRYXAGI. This is everything you need to operate.

## What Is THRYXAGI?

THRYXAGI is an autonomous AI company on Base (L2). We deploy tokens, earn fees, and compound revenue — all managed by AI agents. The CEO is drlor. The AGI manager is Thryx.

**The revenue flywheel:**
1. Launch child tokens paired with OBSD (our flagship token)
2. Every trade on any child token routes through OBSD, generating swap fees
3. Fees compound into the OBSD treasury, raising intrinsic value (IV)
4. Higher IV attracts more traders, more volume, more fees
5. Repeat

## Key Contract Addresses (Base Mainnet)

| Contract | Address |
|----------|---------|
| OBSD Token | `0x291AaF4729BaB2528B08d8fE248272b208Ce84FF` |
| OBSD Router | `0x2558F30eDB8098861FEf81c8E194ac9DcF714b0E` |
| Factory | `0xb696F67394609A6C176Ade745721Fd81b1650776` |
| ChildRouter | `0xCb7a49CE25093f06028003D51aBc47fBE32875de` |
| Aero Pool (OBSD/WETH) | `0x5c1db3247c989eA36Cfd1dd435ed3085287b52ac` |
| WETH (Base) | `0x4200000000000000000000000000000000000006` |
| Deployer Wallet | `0x7a3E312Ec6e20a9F62fE2405938EB9060312E334` |

## The ./thryx CLI

All operations go through `./thryx`. Run from project root.

### Core Commands

```bash
# Dashboard
./thryx status              # Full status: balance, OBSD state, tokens, tweets
./thryx monitor             # Health check with actionable alerts
./thryx treasury            # Treasury snapshot with fee pipelines

# Launch tokens
./thryx launch "Token Name" TICKER   # Deploy child token via factory

# Trade
./thryx buy TICKER 0.0001            # Buy token with ETH
./thryx sell TICKER 1000             # Sell tokens for ETH

# Fees
./thryx claim obsd          # Claim OBSD router creator fees
./thryx claim all           # Claim across all platforms

# Wallets
./thryx wallet balance      # Check all wallet balances
./thryx payroll status      # Agent wallet OBSD balances
./thryx payroll run 1e18    # Distribute 1 OBSD to each agent

# Social
./thryx tweet "text"        # Post a tweet
./thryx tweet next          # Post next queued tweet
```

## How Payroll Works

1. Each agent gets a wallet registered via `./thryx payroll add <name> <address>`
2. Treasury holds OBSD bought from the bonding curve
3. `./thryx payroll run <amount_wei>` distributes OBSD to all agent wallets equally
4. Agents can hold OBSD (appreciating asset) or sell for ETH via the router

## State Files

All persistent state lives in `state/`:
- `config.json` — chain config, contract addresses, API endpoints
- `tokens.json` — all deployed tokens with status, platform, addresses
- `wallets.json` — primary, rotation, and agent wallets
- `treasury.json` — revenue tracking, payroll history
- `tweets.json` — tweet queue and posted history

## Rules

1. Never expose `THRYXTREASURY_PRIVATE_KEY` in code, commits, or logs
2. OBSD IV must never decrease — this is the core guarantee
3. Check gas tank before on-chain txs (Base gas is ~0.000002 ETH per tx)
4. Use `forge script` for all on-chain operations (not raw `cast send` on Windows)
5. Register every new token in `state/tokens.json`
6. Report results to Thryx (team lead) via SendMessage after completing tasks
