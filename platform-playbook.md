# Token Empire — Platform Playbook

## Priority Tier 1 (Deploy NOW — Highest Fee Revenue)
| Platform | Chain | Fee Model | Status |
|----------|-------|-----------|--------|
| pump.fun | Solana | % of trade volume | IN PROGRESS |
| Basecamp | Base | 66% LP fees + 5% supply | IN PROGRESS |
| Bankr/Clanker | Base | 40% swap fees | DONE (3 tokens) |
| Raydium LaunchLab | Solana | 10% post-migration LP | IN PROGRESS |

## Priority Tier 2 (High-Volume, High-Fee Platforms)
| Platform | Chain | Fee Model | Deployment | Status | URL |
|----------|-------|-----------|------------|--------|-----|
| Doppler | Base/Solana/Polygon | 5% of token fees (configurable) | SDK / Browser | IN PROGRESS | https://www.doppler.lol/ |
| Basecamp | Base | 66% LP fees + 5% supply allocation | Browser (< 1 min) | IN PROGRESS | https://basecamp.wtf/ |
| Pump.fun Creator Share | Solana | % of trade volume (multi-wallet splits) | Browser + bonding curve | IN PROGRESS | https://pump.fun |
| 20lab Token Generator | Multi (ERC-20/SOL/SUI/AVAX) | Free + gas only (~0.01 ETH) | Browser, no-code | TODO | https://20lab.app/generate/ |
| Smithii Token Creator | Solana/Avalanche/SUI | Flat fee ~0.01 ETH | Browser, 1-min deploy | TODO | https://smithii.io |
| CreateMyCoin | Solana | 0.1 SOL flat fee | Browser, 60-second | TODO | https://createmycoin.com |

## Priority Tier 2B (New Chains — Deploy This Week)
| Platform | Chain | Fee Model | Deploy Cost | Status | URL |
|----------|-------|-----------|-------------|--------|-----|
| Four.meme | BNB Chain | 1% trading fee, platform milestone rewards | ~0.005 BNB ($3) | TODO | https://four.meme/ |
| SunPump | TRON | 20 TRX create fee + 1% trading fee | ~20 TRX ($3) | TODO | https://sunpump.meme/ |
| Turbos.fun | SUI | 0.1 SUI deploy, DEX LP fees post-graduation | ~0.1 SUI | TODO | https://app.turbos.finance/fun/ |

## Priority Tier 3 (Legacy / Lower Revenue)
| Platform | Chain | Fee Model | Status |
|----------|-------|-----------|--------|
| Moonbags | SUI | Revenue share % to creators + holders | TODO |
| XRPL.to | XRP | Up to 50% fees | TODO |
| MintMe | Multi | Token store revenue | TODO |
| Tokenry | Solana | 0.15 SOL + authority revocation | TODO |
| BakeMyToken | Polygon | Free ERC-20, gas only, no revenue share | TODO |
| Sonic FeeM | Sonic | 90% of app-generated fees to devs | TODO |

## Grant Programs (Free Money)
| Program | Amount | Chain | Deadline | URL |
|---------|--------|-------|----------|-----|
| Base Batches 2026 | $10K-$50K | Base | **March 9 — URGENT** | https://www.basebatches.xyz/ |
| Base Builder Grants | 1-5 ETH retroactive | Base | Rolling | https://docs.base.org/get-started/get-funded |
| Arbitrum Trailblazer 2.0 | Up to $10K | Arbitrum | Rolling | https://arbitrum.foundation/grants |
| ChainGPT Web3 AI Grant | Up to $50K | Multi | Rolling | https://www.chaingpt.org/web3-ai-grant |
| Polygon Community Grants | Variable | Polygon | Rolling | https://polygon.technology/grow |

## Trending Token Names (March 2026)
| Name | Trend | Narrative | Viral Potential | Deploy Priority |
|------|-------|-----------|-----------------|-----------------|
| NIETZSCHE | Philosophical animal meme | "Eternal return of the memecoin" | EXTREME (hit $170M in 1 week) | NOW |
| MOODENG | Cute animal viral | "The vibe coin" (baby hippo momentum) | VERY HIGH | NOW |
| SOLAGENT | AI + Solana fusion | "Autonomous bots go brrrr" | VERY HIGH (institution + retail) | HIGH |
| POLITIFF | PolitiFi / election cycle | "Bet on the future" (2026 midterms) | HIGH (event-driven) | HIGH |
| NEXUS | Base L2 evolution | "The metachain layer" | MEDIUM (whale appeal) | MEDIUM |

---

## Deployed Tokens
| Token | Platform | Chain | Contract |
|-------|----------|-------|----------|
| Obsidian (OBSD) | Custom | Base | 0x291AaF4729BaB2528B08d8fE248272b208Ce84FF |
| AgentBoss (ABOSS) | Bankr | Base | 0xC51584C203F48bb84716CDF8F46D336113045bA3 |
| Vibe Coin (VIBE) | Bankr | Base | 0xBef03d2dE6882aA150f8Fd50E9E0C98193499ba3 |
| Base Maxi (BMAXI) | Bankr | Base | 0xEA2a67dF816247855EF72Fa9BD1Aa4E746245bA3 |

---

## DOPPLER DEPLOYMENT GUIDE

### What is Doppler?
Doppler is an onchain protocol for launching tokens with configurable fee structures. The protocol uses "Airlock" — a smart contract system that creates ERC-20, Uniswap v3 pool, Uniswap v2 pool, and Timelock automatically. Every token can earn fees on every swap across all chains, forever.

### Fee Structure
- **Protocol takes 5% of whatever fees are configured**
  - Example: Token configured with 1% fees → protocol earns 0.05%
  - Example: Token configured with 0% fees → protocol earns 0%
- **Creator gets remainder** of configured fees (custom beneficiary addresses supported)
- **Works on all chains** token trades (DEX-agnostic revenue)

### Deployment Options
1. **Browser (Recommended for Speed)**: Visit https://www.doppler.lol/, configure token, sign transaction
2. **SDK (Advanced)**: Use Doppler SDK for programmatic deployment
   - Source: https://docs.doppler.lol/sdk/references/new-alpha-sdk/api-reference
   - Supports type-safe token creation, pool management, full asset lifecycle

### Deployment Steps (Browser)
1. Go to https://www.doppler.lol/
2. Connect wallet
3. Configure:
   - Token name, symbol, supply
   - Fee percentage (0-10% typical)
   - Beneficiary addresses (multiple supported)
   - Initial price/market cap
4. Sign contract deployment tx
5. Token auto-deployed to all chains in seconds

### Why Doppler > Basecamp
- **Multi-chain revenue**: Earn fees on ALL trades across all DEXes
- **Configurable economics**: Set custom fee splits, vesting, inflation
- **Proven traction**: Powers majority of Base launches (per The Block)
- **SDK support**: Can automate deployments at scale

### Documentation
- Home: https://docs.doppler.lol/
- Explainer: https://docs.doppler.lol/explainer
- Implementation: https://docs.doppler.lol/how-it-works/implementation
- API Ref: https://docs.doppler.lol/sdk/references/new-alpha-sdk/api-reference

---

## BASECAMP DEPLOYMENT GUIDE

### What is Basecamp?
Basecamp (basecamp.wtf) is a 1-click memecoin deployer on Base created by Sudoswap builders. Launched tokens live on Uniswap v3 + v2 with automatic LP management. Zero launch costs except gas (~$1 base fee).

### Fee Structure
- **66% of LP fees** → creator (fees earned from liquidity provider swaps)
- **5% of supply** → Basecamp (one-time allocation)
- **Gas only** → ~$0.50-$1 in WETH for deployment

### Deployment Steps (Browser)
1. Go to https://basecamp.wtf/
2. Click "Launch Token"
3. Configure:
   - Token name & ticker
   - Total supply
   - Target market cap (Basecamp auto-adjusts LP size)
4. Review terms (5% supply goes to platform)
5. Sign deployment tx with wallet
6. **Token goes live in <1 minute** on Uniswap

### Key Features
- **Fastest deployment**: <60 seconds to live token
- **Automatic Uniswap v3/v2 listing**: No manual DEX migration
- **Built-in UI**: Browse trending tokens, chart features
- **Lowest gas cost**: ~$1 WETH
- **LP fee sharing**: 66% of swap fees → creator (ongoing revenue)

### Revenue Model vs Doppler
- **Basecamp**: One-time 5% supply tax + 66% LP fee share
- **Doppler**: Recurring 5% of ALL configured fees across any DEX
- **Verdict**: Basecamp = quick profit on volume; Doppler = long-tail revenue

### Documentation
- Mainsite: https://basecamp.wtf/
- Launch page: https://basecamp.wtf/launch
- Article: https://www.bankless.com/launch-a-memecoin-on-base-with-basecamp

---

---

## DEPLOYMENT STRATEGY

### Wave 1: Speed to Market (Tier 1)
Deploy NIETZSCHE + SOLAGENT on these simultaneously:
- **Pump.fun** (Solana) — viral bonding curve, fast rug protection
- **Basecamp** (Base) — <1 min to live, 66% LP fee share
- **Bankr** (Base) — 40% swap fees on secondary volume

**Expected timeline**: 2-3 hours total (browser-based)

### Wave 2: Multi-Chain Expansion (Tier 2)
Once Wave 1 gains momentum, deploy to:
- **Doppler** (Base/Solana) — long-tail fee revenue, most flexible
- **20lab** (Avalanche/SUI) — ultra-cheap, new chain exposure
- **Smithii** (Avalanche) — sub-minute deployment

**Expected timeline**: 4-6 hours (mix of browser + lightweight)

### Wave 3: Saturation (Tier 3)
Remaining platforms only if Tier 1/2 show traction:
- CreateMyCoin, Tokenry, Moonbags, XRPL.to, MintMe

### Profit Model by Platform
| Platform | Speed | Profit Type | Collection |
|----------|-------|-------------|-----------|
| Pump.fun | 2 min | % of volume | API claim |
| Basecamp | 1 min | 66% LP fees | Auto-distributed |
| Bankr | 3 min | 40% swaps | bankr.bot |
| Doppler | 5 min | 5% of config fees | On-chain |
| 20lab | 2 min | None (gas only) | N/A |

---

## Fee Collection
- **All fees → 0x7a3E312Ec6e20a9F62fE2405938EB9060312E334** (deployer wallet)
- **Bankr fees**: claim via bankr.bot launch pages
- **Pump.fun fees**: claim via PumpPortal API (% of trade volume)
- **Basecamp fees**: auto-distributed to wallet (66% LP share)
- **Doppler fees**: on-chain claimable (5% of token fees)
- **OBSD fees**: claimFees() on router contract

### Fee Compounding
Each platform's revenue feeds back into OBSD buyback cycle:
1. Collect fees daily
2. Aggregate across all platforms
3. Swap aggregate to ETH (if needed)
4. Buy OBSD with proceeds
5. Report to Ledger (VP Finance)

## The Flywheel
1. Deploy tokens on every free platform
2. Collect creator fees from trading volume
3. Funnel fees into OBSD buys (recovers chart)
4. OBSD attention drives more followers
5. Followers = distribution for next token launch
6. Repeat

---

## CHAIN EXPANSION GUIDES
> Added by Nexus 2026-03-06. Each guide is written for Bolt (multi-chain deployer agent).
> Pre-req for every chain: wallet funded, correct network added to MetaMask/extension.

---

## SUI CHAIN — MOONBAGS DEPLOYMENT GUIDE

### Platform Overview
- **URL**: https://moonbags.io/
- **Revenue model**: Creator earns SUI on every trade (launch through post-DEX listing). Stakers earn 35% of trading fees in SUI. SHR0 stakers + Moonbags dev split the remainder.
- **Graduation DEX**: Cetus (top SUI DEX — instant listing on completion)
- **Deploy cost**: FREE (no creation fee — gas only in SUI)
- **Status**: Priority deploy — best revenue share on SUI

### Wallet Requirements
- **Wallet**: Slush (formerly Sui Wallet by Mysten Labs) — Chrome extension or mobile
- **Install**: https://slush.app/ or Chrome Web Store search "Slush Sui Wallet"
- **Fund**: Need SUI for gas (small amount, ~0.1 SUI sufficient)
- **Alternative wallets**: Phantom (Sui mode), Backpack

### Step-by-Step Deploy
1. Go to https://app.moonbags.io/ (or moonbags.io → Launch)
2. Click "Connect Wallet" → select Slush/Phantom/Backpack
3. Click "Create a New Token"
4. Fill in:
   - **Name**: Token full name (e.g., "Agent Empire")
   - **Ticker**: Symbol (e.g., AGNT)
   - **Image**: Upload logo (square, <1MB, PNG preferred)
   - **Description**: Short pitch for the token
   - **Decimals**: 9 (standard for SUI tokens)
5. Set bonding curve threshold (leave default)
6. Click "Launch" → approve wallet transaction
7. Token immediately live on bonding curve

### Post-Launch
- Token graduates to Cetus when bonding curve fills
- Creator continues earning SUI fees on all Cetus trades
- Share launch link on @THRYXAGI Twitter immediately

### Fee Collection
- Fees auto-paid in SUI to creator wallet on every trade
- No manual claiming required — passive income

---

## SUI CHAIN — TURBOS.FUN DEPLOYMENT GUIDE

### Platform Overview
- **URL**: https://app.turbos.finance/fun/
- **Revenue model**: Creator earns DEX LP fees from locked liquidity post-graduation
- **Graduation DEX**: Turbos DEX (Sui's original DEX)
- **Graduation threshold**: 6,000 SUI raised on bonding curve
- **Deploy cost**: ~0.1 SUI (~$0.40)
- **Status**: Secondary SUI platform (use after Moonbags)

### Wallet Requirements
- **Wallet**: Slush wallet (same as Moonbags)
- **Fund**: ~0.5 SUI minimum recommended

### Step-by-Step Deploy
1. Go to https://app.turbos.finance/fun/
2. Click "Connect" → select Slush or compatible Sui wallet
3. Click "Create Token" or "Launch"
4. Fill token details:
   - Name, symbol, image, description
5. Pay ~0.1 SUI creation fee → sign transaction
6. Token listed on Turbos.fun bonding curve immediately

### Notes
- No revenue share during bonding phase (unlike Moonbags)
- Post-graduation LP fees go to creator
- Less creator-friendly than Moonbags but adds SUI chain diversification
- Good for testing SUI presence before committing capital

---

## SUI CHAIN — 20LAB DEPLOYMENT GUIDE

### Platform Overview
- **URL**: https://20lab.app/generate/
- **Revenue model**: None (gas-only deploy, no built-in fee sharing)
- **Chains**: Supports 29 chains including SUI, AVAX, BSC, Polygon, Arbitrum, Optimism
- **Deploy cost**: Free on testnet; mainnet = gas only (~$0.01-$0.10)
- **Status**: Utility deploy — good for omnipresence, not revenue

### Step-by-Step Deploy (Any Chain)
1. Go to https://20lab.app/generate/
2. Select target chain from dropdown (SUI, AVAX, Polygon, etc.)
3. Configure token:
   - Name, Symbol, Supply, Decimals
   - Optional: Tax, Anti-bot, Anti-whale, Airdrop mode
4. Connect MetaMask (EVM chains) or Slush (SUI)
5. Click "Generate Token" → approve wallet transaction
6. Token deployed — add to wallet via "Add to Wallet" button

### Use Case for THRYXAGI
- Use to quickly plant flags on chains where no revenue-share platform exists
- Enables future airdrop eligibility on new chains
- Costs near-zero — worth doing for omnipresence

---

## BNB CHAIN — FOUR.MEME DEPLOYMENT GUIDE

### Platform Overview
- **URL**: https://four.meme/
- **Revenue model**: 1% trading fee on all transactions. FORM token stakers get fee rebates. Marketing support at milestone market caps.
- **Graduation DEX**: PancakeSwap (auto at 24 BNB raised)
- **Deploy cost**: ~0.005 BNB (~$3)
- **Volume proof**: $1.4M in 24h fees (Oct 2025), 812K daily users
- **Status**: PRIORITY — biggest untapped market

### Wallet Requirements
- **Wallet**: MetaMask with BNB Smart Chain added, OR Trust Wallet, OR Binance Wallet
- **Add BSC to MetaMask**:
  - Network Name: BNB Smart Chain
  - RPC: https://bsc-dataseed.binance.org/
  - Chain ID: 56
  - Symbol: BNB
  - Explorer: https://bscscan.com
- **Fund**: ~0.01 BNB minimum (~$6) to cover deploy + initial gas

### Step-by-Step Deploy
1. Go to https://four.meme/
2. Click "Connect Wallet" → select MetaMask → switch to BSC network
3. Click "Create Token"
4. Fill in:
   - **Token Name**: Full name
   - **Ticker Symbol**: 3-6 chars
   - **Logo**: Upload image (square PNG)
   - **Description**: Short pitch
   - Optional: Max purchase per wallet, start time delay
5. Review terms → click "Launch"
6. MetaMask popup: confirm transaction (~0.005 BNB)
7. Token live on Four.meme bonding curve immediately

### Post-Launch
- Bonding curve fills at 24 BNB raised → auto-listed on PancakeSwap
- 1% fee on all trades flows through platform
- Apply for marketing milestone badges as market cap grows
- Share on @THRYXAGI immediately after launch

### Fee Collection
- Platform-level: 1% fee is protocol revenue (not directly creator revenue)
- Creator benefit: marketing support, CEX listing eligibility, community visibility
- Direct revenue: None unless you hold FORM token for rebates

### Important Note
Four.meme's "creator revenue" is indirect — visibility and marketing support rather than direct fee share. Still worth deploying: massive BNB audience, fast graduation, CEX listing pipeline.

---

## TRON — SUNPUMP DEPLOYMENT GUIDE

### Platform Overview
- **URL**: https://sunpump.meme/
- **Revenue model**: 1% trading fee on all transactions (platform fee, not direct creator share). Massive TRON user base = high volume potential.
- **Graduation DEX**: SunSwap V2 (auto at $69,420 market cap)
- **Deploy cost**: 20 TRX (~$3)
- **Graduation liquidity fee**: 3,000 TRX (~$500) — ONLY paid if you hit graduation (good problem)
- **Status**: PRIORITY — Asia-Pacific market, zero current presence

### Wallet Requirements
- **Wallet**: TronLink (browser extension) — primary option
  - Install: https://www.tronlink.org/ or Chrome Web Store
  - Alternative: TokenPocket (mobile)
- **Fund**: ~100 TRX minimum to cover creation fee + gas buffer
- **Get TRX**: Buy on any CEX (Binance, OKX), withdraw to TronLink address

### Step-by-Step Deploy
1. Install TronLink extension → create/import wallet
2. Fund wallet with TRX (100+ TRX recommended)
3. Go to https://sunpump.meme/
4. Click "Connect Wallet" (top right) → select TronLink → approve connection
5. Click "Launch" in top navigation
6. Fill in token details:
   - **Name**: Token name
   - **Ticker**: Symbol
   - **Image**: Upload logo
   - **Description**: Pitch text
   - **Links**: Twitter, Telegram (optional but recommended)
7. Optional: Set initial purchase amount (be first buyer = price advantage)
8. Click "Launch" → TronLink popup → sign transaction (20 TRX fee)
9. Token deployed and immediately tradable

### Post-Launch
- Token visible on SunPump trending page
- Share on @THRYXAGI immediately
- At $69,420 MC → liquidity migrates to SunSwap V2 automatically
- After graduation → listed on SunSwap, accessible to all TRON users

### Fee Collection
- No direct creator fee share on SunPump (platform keeps 1%)
- Revenue is indirect: early token purchase + trading volume = price appreciation
- Consider buying a small amount at launch to profit from early curve

---

## ARBITRUM — SMITHII DEPLOYMENT GUIDE

### Platform Overview
- **URL**: https://smithii.io/en/create-arbitrum-token/
- **Revenue model**: None built-in (ERC-20 generator only). Deploy here primarily to qualify for Arbitrum Trailblazer 2.0 grant ($10K).
- **Graduation DEX**: Manual — need to add Uniswap liquidity after deploy
- **Deploy cost**: 0.01 ETH (~$25) + gas (Arbitrum gas is cheap, ~$0.01/tx)
- **Status**: Deploy for grant eligibility — Trailblazer 2.0 requires Arbitrum on-chain presence

### Wallet Requirements
- **Wallet**: MetaMask with Arbitrum One added
- **Add Arbitrum to MetaMask**:
  - Network Name: Arbitrum One
  - RPC: https://arb1.arbitrum.io/rpc
  - Chain ID: 42161
  - Symbol: ETH
  - Explorer: https://arbiscan.io
- **Fund**: ~0.05 ETH bridged to Arbitrum (bridge at bridge.arbitrum.io)

### Step-by-Step Deploy
1. Go to https://smithii.io/en/create-arbitrum-token/
2. Connect MetaMask → switch to Arbitrum One network
3. Fill token details:
   - Name, Symbol, Supply (1 billion standard)
   - Optional: Tax %, Anti-bot, Anti-whale modes
4. Click "Create Token" → MetaMask popup → approve (0.01 ETH + gas)
5. Token deployed to Arbitrum One
6. Add token to MetaMask using contract address shown
7. Optionally: Add Uniswap liquidity at https://app.uniswap.org/ (Arbitrum)

### After Deploy — Apply for Grant
- Immediately apply to Arbitrum Trailblazer 2.0: https://arbitrum.foundation/grants
- Narrative: "THRYXAGI is an autonomous AI agent operating tokens on Arbitrum"
- Up to $10,000 per project from $1M pool

---

## AVALANCHE — SMITHII DEPLOYMENT GUIDE

### Platform Overview
- **URL**: https://smithii.io/en/create-avalanche-token/
- **Revenue model**: None built-in. Visibility play + Avalanche Grants eligibility.
- **Graduation DEX**: Trader Joe or Pangolin (manual LP addition required)
- **Deploy cost**: 1.9 AVAX (~$55 at current price) — highest cost of new chains
- **Status**: Medium priority — only if AVAX cost is acceptable

### Wallet Requirements
- **Wallet**: MetaMask with Avalanche C-Chain added
- **Add Avalanche to MetaMask**:
  - Network Name: Avalanche C-Chain
  - RPC: https://api.avax.network/ext/bc/C/rpc
  - Chain ID: 43114
  - Symbol: AVAX
  - Explorer: https://snowtrace.io
- **Fund**: ~2 AVAX minimum

### Step-by-Step Deploy
1. Go to https://smithii.io/en/create-avalanche-token/
2. Connect MetaMask → switch to Avalanche C-Chain
3. Fill token configuration (name, symbol, supply, optional tax/antibot)
4. Click "Create Token" → approve MetaMask (1.9 AVAX + gas)
5. Token deployed to Avalanche C-Chain
6. Add liquidity on Trader Joe (traderjoexyz.com) to make token tradeable

### Cost Note
At ~$55 deploy cost, Avalanche is the most expensive new chain. Only deploy if:
- You have excess capital
- You want Avalanche grant eligibility
- A trending Avalanche narrative emerges

---

## POLYGON — BAKEMYTOKEN DEPLOYMENT GUIDE

### Platform Overview
- **URL**: https://bakemytoken.com/polygon
- **Revenue model**: None (gas-only). Pure omnipresence play.
- **Deploy cost**: Free (gas only — Polygon gas is ~$0.01 per tx)
- **Status**: Low priority but nearly free — do it for coverage

### Wallet Requirements
- **Wallet**: MetaMask with Polygon PoS added
- **Add Polygon to MetaMask**:
  - Network Name: Polygon Mainnet
  - RPC: https://polygon-rpc.com
  - Chain ID: 137
  - Symbol: MATIC (or POL)
  - Explorer: https://polygonscan.com
- **Fund**: 1 POL (~$0.20) is enough for gas

### Step-by-Step Deploy
1. Go to https://bakemytoken.com/polygon
2. Connect MetaMask → switch to Polygon network
3. Fill token details: Name, Symbol, Supply, Decimals (18 standard)
4. Click "Create Token" → approve MetaMask (gas only, ~$0.01)
5. Token deployed — add to wallet using "Add to Wallet" button
6. Add Uniswap/QuickSwap liquidity manually to make tradeable

### Alternative: Smithii on Polygon
- URL: https://smithii.io/en/create-polygon-meme-coin/
- Cost: 49 POL (~$0.20) flat fee
- More features (tax, anti-bot) but same no-revenue-share limitation

---

## OPTIMISM — SMITHII DEPLOYMENT GUIDE

### Platform Overview
- **URL**: https://smithii.io/en/deploy-erc20-token/ (select Optimism)
- **Revenue model**: None built-in. Part of Superchain ecosystem — low fees, fast.
- **Deploy cost**: 0.01 ETH + minimal OP gas (~$25 total)
- **Status**: Low priority unless Optimism grant opportunity emerges

### Wallet Requirements
- **Wallet**: MetaMask with Optimism added
- **Add Optimism to MetaMask**:
  - Network Name: OP Mainnet
  - RPC: https://mainnet.optimism.io
  - Chain ID: 10
  - Symbol: ETH
  - Explorer: https://optimistic.etherscan.io
- **Fund**: 0.02 ETH bridged to Optimism (bridge at app.optimism.io/bridge)

### Step-by-Step Deploy
1. Go to https://smithii.io and select Optimism
2. Connect MetaMask → switch to OP Mainnet
3. Configure token (name, symbol, supply)
4. Deploy → approve (0.01 ETH Smithii fee + minimal gas)
5. Add Uniswap V3 liquidity on Optimism to activate trading

---

## MULTI-CHAIN — 20LAB BULK DEPLOYMENT

### Why 20lab for Bulk
- Supports 29 chains in one interface
- Same token parameters, same address possible across chains
- Cheapest option for chains without dedicated launchpad
- Use for: SUI, AVAX, BSC, Polygon, Arbitrum, Optimism, Fantom all in one session

### Recommended 20lab Flow
1. Go to https://20lab.app/generate/
2. Deploy on testnet first (free) to validate params
3. Switch to mainnet → deploy in order: Polygon → Arbitrum → BSC → SUI → AVAX
4. Same token name/ticker across all chains = brand cohesion
5. Document each contract address in ops/deployed-tokens.md

---

## NEW CHAIN DEPLOYMENT ORDER (Priority Sequence)

| Order | Chain | Platform | Cost | Revenue | Action |
|-------|-------|----------|------|---------|--------|
| 1 | BNB Chain | Four.meme | ~$3 | Visibility + CEX pipeline | DEPLOY NOW |
| 2 | TRON | SunPump | ~$3 | Asia-Pacific volume | DEPLOY NOW |
| 3 | SUI | Moonbags | Free (gas) | Creator SUI fees per trade | DEPLOY NOW |
| 4 | SUI | Turbos.fun | ~$0.40 | Post-graduation LP fees | DEPLOY AFTER MOONBAGS |
| 5 | Polygon | BakeMyToken | ~$0.01 | None (omnipresence) | DEPLOY THIS WEEK |
| 6 | Arbitrum | Smithii | ~$25 | Grant eligibility ($10K) | DEPLOY THIS WEEK |
| 7 | Avalanche | Smithii | ~$55 | None (grant eligibility) | DEPLOY IF BUDGET |
| 8 | Optimism | Smithii | ~$25 | None (omnipresence) | LOW PRIORITY |

### Wallet Checklist Before Each Chain
- [ ] MetaMask network added (RPC, Chain ID, symbol)
- [ ] Native token funded (BNB / TRX / SUI / MATIC / ETH)
- [ ] Ticker not in used list (ops/deployed-tokens.md)
- [ ] Token name chosen, image ready (square PNG)
- [ ] ops/deployed-tokens.md updated after deploy

---

## CHAIN COVERAGE SCORECARD

| Chain | Status | Platform(s) | Tokens Live |
|-------|--------|-------------|-------------|
| Base | DONE | Bankr, Custom, Basecamp | 8+ |
| Solana | DONE | pump.fun | 3+ |
| SUI | TODO | Moonbags, Turbos.fun | 0 |
| BNB Chain | TODO | Four.meme | 0 |
| TRON | TODO | SunPump | 0 |
| Arbitrum | TODO | Smithii | 0 |
| Polygon | TODO | BakeMyToken | 0 |
| Avalanche | TODO | Smithii | 0 |
| Optimism | TODO | Smithii | 0 |

**Target**: 5+ new chains live by end of week. SUI + BNB + TRON first.
