# R&D Experiments — Nexus Report
> Generated: 2026-03-06 | Budget: 0.000248 ETH (~$0.50)

---

## 1. NEW PLATFORMS RESEARCH

### Platforms Reviewed

| Platform | Chain | Deploy Cost | Creator Fees | Organic Traffic | Verdict |
|----------|-------|-------------|--------------|-----------------|---------|
| **Doppler** | Base, Solana | Free | 5% of token's configured fee | HIGH — powers 90%+ of Base launches | TOP PICK |
| **Raydium LaunchLab** | Solana | Free | 10% of LP fees post-graduation | HIGH — Raydium's built-in trader base | GOOD (need SOL) |
| **CreateMyToken** | EVM + Solana | Free | None (vanilla ERC20) | LOW — just a deployer, no marketplace | SKIP |
| **Bankr** | Base | Free | Auto fee collection | LOW — 13 dead tokens prove it | ALREADY TRIED |
| **pump.fun** | Solana | Free | Trading fees | MEDIUM — 4 dead tokens prove saturation | ALREADY TRIED |
| **Bags.fm** | Solana | Free | Creator monetization model | UNKNOWN — new, worth monitoring | WATCH |

### Key Finding: Doppler
Doppler is the dominant launch infrastructure on Base. It raised $9M from Pantera Capital and powers most new DEX pools on Base. Tokens launched via Doppler get integrated into the ecosystem where the traffic already is. Unlike Bankr (which deploys to its own isolated pool), Doppler tokens land directly on major DEXes.

**Problem**: Doppler launches its own token contracts. We can't use our custom RouterV3 bonding curve through Doppler — it's a different mechanism. Doppler would only work for generic meme token launches, not OBSD-style treasury-backed tokens.

### Recommendation
- Doppler is best for VOLUME plays (deploy memes that ride Doppler's traffic)
- LaunchLab is best for Solana exposure (need SOL though)
- Neither replaces our custom OBSD model — OBSD's value is the rising IV floor

---

## 2. DEX INDEXING — WHAT TRIGGERS DEXSCREENER / GECKOTERMINAL

### DexScreener (Primary)
Per official docs (docs.dexscreener.com/token-listing):
- **Trigger**: Token added to a liquidity pool + at least one transaction
- **Timing**: 10-30 minutes after first swap
- **Min Liquidity**: Third-party sources claim $10,000+, but official docs just say "liquidity pool + transaction"
- **No listing fee** — completely free and automatic
- **Supported DEXes**: Aerodrome, Uniswap (all versions), and 80+ others on 25+ chains

### GeckoTerminal (Secondary)
Per official CoinGecko support:
- **Trigger**: Token actively trading on a supported DEX
- **Search**: Findable by contract address once pool exists
- **No listing fee** — free automatic indexing
- **Enhancement**: Token info update form (free) or Fast Pass ($199) for priority

### Why Our 18 Tokens Have Zero Indexing
1. **Bankr tokens (13)**: Deployed to Bankr's internal pools — likely NOT standard Aerodrome/Uniswap pools that DexScreener monitors. Zero trades = zero indexing trigger.
2. **pump.fun tokens (4)**: Dead on arrival — 0 trades, 0 holders. Even if indexed, nothing to show.
3. **OBSD**: Has Aerodrome + V4 pools (Tier 0 seeded). BUT seed liquidity was only 0.0002 ETH Aero + 0.0001 ETH V4 = $0.60 total. This is FAR below the practical visibility threshold.

### Critical Insight
DexScreener says "liquidity pool + one transaction" but in practice:
- Tokens with <$100 liquidity are indexed but buried — nobody finds them organically
- The $10K liquidity figure is for meaningful visibility, not mere existence
- **Our OBSD Aero pool exists but is practically invisible at $0.40 liquidity**
- First external buy/sell on the Aero pool (not router buy) would trigger DexScreener indexing

### Action Required
OBSD needs MORE liquidity in Aero/V4 pools (Tier 1+) to become visible. Current 0.0003 ETH deployed is dust.

---

## 3. CROSS-CHAIN ANALYSIS

| Chain | Deploy Cost | Gas/Tx | Organic Traffic | Best For |
|-------|-------------|--------|-----------------|----------|
| **Base** | ~$0.01 | ~$0.004 | HIGH (Doppler, Aerodrome, Coinbase wallet) | Current home, stay |
| **Solana** | ~$0.02 | ~$0.001 | HIGH (pump.fun, Raydium, Jupiter) | Meme volume |
| **Polygon** | ~$0.005 | ~$0.001 | LOW for new tokens | Avoid |
| **Arbitrum** | ~$0.05 | ~$0.01 | MEDIUM | Not worth switching |
| **BNB Chain** | ~$0.50 | ~$0.05 | MEDIUM (PancakeSwap) | Too expensive for us |
| **Avalanche** | ~$0.10 | ~$0.02 | LOW | Avoid |

### Verdict
Base and Solana are the only chains worth deploying on. We're already on both.
- Base advantage: cheapest gas, Coinbase ecosystem, Doppler traffic
- Solana advantage: meme culture, Jupiter aggregator volume
- No reason to add a third chain at $0.50 budget

---

## 4. REVENUE EXPERIMENTS

### Experiment A: Self-Buy OBSD to Trigger Tier 1
- **Cost**: 0.000250 ETH (our full 0.000248 + dust)
- **Revenue**: 0.000002 ETH creator fee (claimable) + IV boost
- **Risk**: LOW — we're buying our own token, math is proven
- **Outcome**: Triggers Tier 1 graduation → 80% of realETH deploys to Aero/V4 → more visible pools
- **Problem**: We'd be spending ALL our ETH and getting 0.000002 back immediately

### Experiment B: Fee Compounding Loop (Theoretical)
- Buy OBSD → claim creator fee → buy again → claim fee
- Each cycle: 1% fee = 0.000002 ETH back per 0.000248 buy
- **Math**: After buy, realETH = 0.004698, creator gets 0.000002. Next buy = 0.000002 ETH → fee = 0.00000002 ETH
- **Verdict**: NONVIABLE at this scale. Fee compounding only works with >1 ETH volume

### Experiment C: Raydium LaunchLab Token
- Deploy a free meme token on LaunchLab
- Earn 10% of LP fees if it graduates
- **Cost**: Need SOL for gas (~0.02 SOL = $3). We don't have SOL.
- **Verdict**: BLOCKED by no SOL balance

### Experiment D: Doppler Meme Launch on Base
- Deploy a meme via Doppler's interface (free)
- Configure with fees → earn revenue from trading
- **Cost**: Gas only (~0.000002 ETH per tx on Base)
- **Potential**: If Doppler drives traffic, even a $100/day token earns creator fees
- **Risk**: MEDIUM — same problem as Bankr (deploy ≠ volume), but Doppler has better distribution
- **Verdict**: WORTH TESTING if Doppler integration is accessible programmatically

### Experiment E: External Traffic to OBSD
- Direct buy transactions from other wallets would trigger DexScreener
- A single Aero pool swap by an external wallet = indexing trigger
- **Cost**: 0 (need to attract organic buyers)
- **Risk**: None, but requires visibility we don't have

---

## 5. OBSD ROUTER BUY MATH (0.000248 ETH)

### Current On-Chain State (verified via cast)
```
vETH:              0.504752 ETH
vTOK:              990,585,475.64 tokens
realETH:           0.004452 ETH
circulating:       9,226,233.87 tokens
k:                 5e44
currentTier:       1 (Tier 0 complete)
totalETHDeployed:  0.000300 ETH
pendingCreatorFees: 0 ETH
```

### Buy Simulation: 0.000248 ETH
```
Input:           0.000248 ETH
Creator Fee:     0.000002 ETH (1%)
Net to treasury: 0.000246 ETH

Tokens out:      481,603.45 (from curve)
Burn (2%):       9,632.07 tokens destroyed
User receives:   471,971.38 tokens

New realETH:     0.004698 ETH
New circulating: 9,698,205.25 tokens

IV before:       0.000000000483 ETH/token
IV after:        0.000000000484 ETH/token
IV change:       +0.38%

Spot price:      0.000000000510 ETH/token (up slightly)
```

### Tier 1 Progress
```
Cumulative ETH = realETH + totalETHDeployed = 0.004998 ETH
Tier 1 threshold:                             0.005000 ETH
Shortfall:                                    0.000002 ETH
Progress:                                     99.96%
```

### Critical Finding
A 0.000248 ETH buy gets us to 99.96% of Tier 1 — just 0.000002 ETH short.

If we buy 0.000250 ETH instead (need 0.000002 more), Tier 1 triggers:
- 80% of realETH (0.003758 ETH) deploys to Aero (50%) + V4 (30%)
- Aero gets ~0.001879 ETH + tokens
- V4 gets ~0.001127 ETH + tokens
- This SIGNIFICANTLY increases pool liquidity (from $0.60 to ~$7)
- Still tiny for DexScreener visibility, but pool deepens

BUT: After Tier 1, realETH drops to ~0.000940 ETH (20% reserve). IV drops? NO — IV is realETH/circulating. realETH drops but circulating stays the same. So IV DOES drop after tier deployment.

Wait — re-reading the contract: Tier 1 deploys to DEXes, which removes ETH from realETH but tokens come from router balance (not circulating supply). circulating only tracks user-held tokens. So:
- realETH goes down (ETH sent to pools)
- circulating stays same (no user tokens change)
- IV = realETH/circulating → IV DROPS after tier execution

This is a KNOWN design feature — the IV temporarily dips when tiers execute because ETH moves to DEX pools. But the pools represent real backing. The trade-off is visibility (DEX listing) vs IV floor height.

---

## TOP 3 EXPERIMENTS (Ranked by Cost vs Potential)

### #1: Buy 0.000250 ETH of OBSD to Trigger Tier 1
- **Cost**: 0.000250 ETH (essentially all our ETH)
- **Expected outcome**: Tier 1 triggers, pools deepen 10x, closer to DexScreener visibility
- **Revenue**: 0.000002 ETH creator fee + IV appreciation
- **Risk**: LOW (math proven), but spends entire balance
- **Priority**: HIGH — but only if we want to deepen pools over keeping ETH

### #2: Deploy a Meme Token via Doppler on Base
- **Cost**: ~0.000005 ETH (gas only)
- **Expected outcome**: Token lands in Doppler ecosystem where 90% of Base launches happen
- **Revenue**: Unknown — depends on Doppler's fee model and whether anyone trades it
- **Risk**: MEDIUM — may be another dead token, but Doppler has best Base distribution
- **Priority**: HIGH — cheapest experiment with highest potential upside
- **Needs**: Research Doppler's deployment interface and whether it's programmatically accessible

### #3: Trigger an External Aero Pool Swap for DexScreener Indexing
- **Cost**: ~0.000002 ETH (gas for a tiny swap on Aero pool directly)
- **Expected outcome**: DexScreener indexes OBSD token
- **Revenue**: Visibility → potential organic buyers → creator fees
- **Risk**: LOW cost, but $0.60 pool won't attract traders
- **Priority**: MEDIUM — indexing without liquidity is visibility without substance

---

## APPENDIX: Sources
- [DexScreener Token Listing Docs](https://docs.dexscreener.com/token-listing)
- [DexScreener Listing Requirements](https://listing.help/dexscreener-listing-requirements/)
- [GeckoTerminal Token Listing](https://support.coingecko.com/hc/en-us/articles/22611965649305)
- [Doppler Platform](https://www.doppler.lol/)
- [Doppler Expansion to Solana](https://www.theblock.co/post/392440/doppler-token-platform-powering-majority-base-launches-expands-solana)
- [Raydium LaunchLab Docs](https://docs.raydium.io/raydium/launchlab/launchlab)
- [Raydium Creator Fees](https://docs.raydium.io/raydium/launchlab/how-creator-fees-work)
- [CreateMyToken](https://www.createmytoken.com/)
