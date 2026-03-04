# EverRise Token — Custom Deflationary ERC-20 on Base

## Mission
Build a **self-appreciating ERC-20 token** on Base mainnet where the intrinsic value mathematically cannot decrease over its lifetime. Every swap (buy or sell) burns supply and routes minimal ETH to the creator. The token's IV rises on every trade — snipers profit, holders compound, creator earns passively. **Nobody loses.**

---

## Core Mechanism: One-Way Bonding Curve + Treasury-Backed IV

The contract IS the market. No external DEX liquidity needed at launch. A constant-product virtual AMM governs buy pricing only. Sells are handled directly against the treasury at intrinsic value (IV).

### The Math

```
BONDING CURVE (buys only):
  k       = V_ETH × V_TOK        (virtual constant product)
  P_spot  = V_ETH / V_TOK        (current spot price from curve — only goes up)

INTRINSIC VALUE (sells and reference):
  IV      = Real_ETH / Circ      (treasury ETH divided by circulating supply)

Where:
  V_ETH   = virtual ETH reserves (curve only, not real treasury)
  V_TOK   = virtual token reserves (curve only, decreases on buys, never increases)
  k       = V_ETH × V_TOK (recalculated after buys)
  Real_ETH = actual ETH held in treasury (received from buys, minus payouts and fees)
  Circ    = circulating supply = tokens actually held by users (NOT virtual reserves,
            NOT unissued tokens — only real user-held tokens)
```

### Buy Flow
```
1. User sends ETH
2. creator_fee = ETH × CREATOR_FEE_BPS / 10000        (e.g., 100 bps = 1%)
3. net_eth = ETH - creator_fee
4. tokens_out = V_TOK - k / (V_ETH + net_eth)         (curve pricing)
5. burn_on_buy = tokens_out × BURN_BPS_ON_BUY / 10000  (e.g., 200 bps = 2%)
6. user_receives = tokens_out - burn_on_buy
7. V_ETH += net_eth
8. V_TOK -= tokens_out
9. Circ  += user_receives                              (net tokens entering circulation)
10. Real_ETH += net_eth                                (treasury grows)
11. totalSupply -= burn_on_buy                         (burned forever)
12. Transfer creator_fee ETH to CREATOR_WALLET
```

### Sell Flow
```
Sells bypass the bonding curve entirely. ALL tokens are burned. ETH paid from treasury at IV.

1. User sends tokens
2. sell_tax = getSellTax(hold_duration)                (progressive, see below)
3. tax_tokens = tokens × sell_tax / 10000              (burned, no ETH paid for this portion)
4. net_tokens = tokens - tax_tokens                    (ETH paid out for this portion)
5. eth_payout = net_tokens × IV                        (= net_tokens × Real_ETH / Circ)
6. creator_fee = eth_payout × CREATOR_FEE_BPS / 10000
7. user_receives_eth = eth_payout - creator_fee
8. totalSupply -= tokens                               (ALL tokens burned: taxed + net)
9. Circ -= tokens
10. Real_ETH -= eth_payout
11. Transfer creator_fee ETH to CREATOR_WALLET

Note: V_ETH and V_TOK are NOT touched on sells. The curve is one-directional.
```

### Progressive Sell Tax (Anti-Dump + IV Boost Engine)
```
Hold Duration        Sell Tax    IV Boost Effect
< 5 minutes         25%         Massive IV boost for remaining holders
< 1 hour            20%         Significant boost
< 24 hours          15%         Moderate boost
< 7 days            8%          Modest boost
< 30 days           4%          Small boost
>= 30 days          1%          Minimal friction for diamond hands

Formula: tax(t) = max(TAX_MIN_BPS, TAX_MAX_BPS × e^(-LAMBDA × t))
Where LAMBDA = ln(TAX_MAX_BPS / TAX_MIN_BPS) / FULL_DECAY_SECONDS
```

### Why IV ALWAYS Rises (Mathematical Proof)

```
ON SELL — Proof that IV_new > IV_old:

  Before: IV = E / C  (E = Real_ETH, C = Circ, T = tokens sold, r = sell tax rate)
  Paid out: T*(1-r)*IV ETH
  After:  E' = E - T*(1-r)*(E/C)
              = E * (1 - T*(1-r)/C)
          C' = C - T

  IV_new = E'/C' = [E*(C - T*(1-r)/C*C)] / (C-T)
                 = (E/C) * (C - T*(1-r)) / (C - T)
                 = IV * (C - T + T*r) / (C - T)
                 = IV * [1 + T*r/(C-T)]

  Since T > 0, r > 0 (minimum 1%), C > T:
    IV_new = IV * (1 + T*r/(C-T)) > IV   QED

  Higher sell tax => larger IV jump. Early sellers subsidize diamond hands.

ON BUY — Proof that IV_new >= IV_old:

  Spot price P_spot = V_ETH/V_TOK >= IV (invariant: spot always >= IV, set at init)
  Effective cost per circulating token = net_eth / user_receives >= IV
  Real_ETH grows by at least as much as Circ * IV implies => IV_new >= IV_old   QED

SPOT PRICE NEVER DECREASES:

  V_ETH only increases (buys add net_eth, sells never touch curve)
  V_TOK only decreases (buys remove tokens_out, sells never return tokens)
  P_spot = V_ETH / V_TOK => monotonically increasing   QED
```

### Profit Model: Everyone Wins
```
SNIPERS (hold < 1hr):
  - Entry: cheap tokens via curve at early low spot price
  - Sell back at IV (always positive, always rising)
  - Their sell tax boosts IV for remaining holders — a feature, not a bug
  - Strategy: buy early, sell partial at IV, hold rest as IV compounds

HOLDERS (hold > 30d):
  - 1% sell tax (near-zero friction)
  - Every sell by others raises IV → their tokens worth more in ETH
  - Every buy pushes spot up and adds ETH to treasury
  - value(t) = tokens_held × IV(t), and IV(t) is monotonically non-decreasing

CREATOR:
  - 1% ETH on every buy (taken from ETH input)
  - 1% ETH on every sell (taken from ETH payout)
  - Zero token allocation (no dump risk, builds trust)
  - Revenue scales with volume, not price
  - Cumulative: E = Σ(ETH_flow_per_tx × 0.01)
```

---

## Technical Architecture

### Tech Stack
- **Language:** Solidity ^0.8.24
- **Framework:** Foundry (forge, cast, anvil)
- **Chain:** Base mainnet (chainId 8453)
- **RPC:** `https://mainnet.base.org`
- **Explorer:** `https://basescan.org`
- **Library:** ethers.js v6 (for deploy scripts and interaction)
- **Testing:** Foundry tests (forge test) + local anvil fork

### Project Structure
```
CustomTokenDeployer/
├── CLAUDE.md                    # This file — project brain
├── src/
│   └── EverRise.sol             # Main token contract (ERC-20 + bonding curve + burn)
├── test/
│   ├── EverRise.t.sol           # Core invariant tests
│   ├── BondingCurve.t.sol       # Mathematical precision tests
│   └── Simulation.t.sol         # Multi-agent trade simulations
├── script/
│   ├── Deploy.s.sol             # Foundry deployment script
│   └── Interact.s.sol           # Post-deploy interaction helpers
├── math/
│   └── model.py                 # Python simulation for tokenomics validation
├── foundry.toml                 # Foundry config
└── .env.example                 # Template (never commit real keys)
```

### Contract Design: Single File, No Proxies
```
EverRise.sol
├── ERC20 (OpenZeppelin)
├── Ownable (creator = deployer)
├── ReentrancyGuard
├── BondingCurveEngine (internal library — buy side only)
│   ├── buy(uint256 ethAmount) → (uint256 tokensOut)
│   ├── getSpotPrice() → (uint256 spotPrice)
│   └── getIV() → (uint256 intrinsicValue)     = Real_ETH / Circ
├── SellEngine (treasury-based sells)
│   └── sell(uint256 tokenAmount) → (uint256 ethOut)
├── BurnEngine
│   ├── _burnOnBuy(uint256 tokens) → (uint256 burned)
│   └── _burnOnSell(uint256 tokens) → burns all tokens_in
├── FeeRouter
│   ├── _routeCreatorFee(uint256 ethAmount) → sends ETH to creator
│   └── creatorWallet (immutable, set at deploy)
└── AntiDump
    ├── lastBuyTimestamp[address]
    └── getSellTax(address) → uint256 bps
```

---

## Configuration Constants (Tunable Before Deploy)

```solidity
// === SUPPLY ===
uint256 constant INITIAL_SUPPLY        = 1_000_000_000e18;  // 1 billion tokens
// NO MAX_BURN_PERCENT — burns are uncapped. Supply can approach 0.
// Rationale: capping burns would break the IV guarantee (ETH leaves but supply doesn't shrink)

// === VIRTUAL RESERVES (Bonding Curve Shape — Buy Side Only) ===
uint256 constant INITIAL_VIRTUAL_ETH    = 1 ether;          // Starting virtual ETH
uint256 constant INITIAL_VIRTUAL_TOK    = 1_000_000_000e18; // Starting virtual tokens

// === FEES (in basis points, 10000 = 100%) ===
uint256 constant CREATOR_FEE_BPS        = 100;   // 1% ETH to creator on buy+sell
uint256 constant BURN_BPS_ON_BUY        = 200;   // 2% token burn on buys

// === PROGRESSIVE SELL TAX ===
uint256 constant TAX_MAX_BPS            = 2500;  // 25% max (immediate sell)
uint256 constant TAX_MIN_BPS            = 100;   // 1% min (30+ day holder)
uint256 constant FULL_DECAY_SECONDS     = 30 days;

// === SAFETY ===
uint256 constant MAX_BUY_ETH            = 5 ether;   // Per-tx buy cap (anti-whale)
uint256 constant MAX_SELL_PERCENT_BPS   = 1000;       // Max 10% of balance per sell
uint256 constant SELL_COOLDOWN          = 5 minutes;  // Between sells
```

---

## Development Phases

### Phase 1: Mathematical Validation
- [ ] Build Python simulation (`math/model.py`) modeling 10,000+ trades
- [ ] Prove IV never decreases across all scenarios (buys, sells, mixed)
- [ ] Prove spot price never decreases
- [ ] Model sniper ROI at various entry points and hold durations
- [ ] Model holder IV compounding returns over 30/60/90 days
- [ ] Model creator cumulative ETH earnings vs. volume
- [ ] Stress test: 100% sell pressure scenario — prove IV holds
- [ ] Find optimal constants (virtual reserves, fee rates, burn rates)
- [ ] Generate charts: price curve, supply decay, IV growth, creator earnings

### Phase 2: Smart Contract Implementation
- [ ] Implement EverRise.sol with all mechanisms from Phase 1
- [ ] Write comprehensive Foundry tests (100% branch coverage)
- [ ] Fuzz testing: random buy/sell sequences, verify invariant `IV_new >= IV_old`
- [ ] Fuzz testing: verify `P_spot_new >= P_spot_old` on all buys
- [ ] Gas optimization pass (target: buy < 100k gas, sell < 120k gas)
- [ ] Security review: reentrancy, overflow, frontrun resistance

### Phase 3: Local Testing
- [ ] Deploy to local Anvil fork of Base
- [ ] Simulate full lifecycle: launch → sniper buys → organic growth → sells → verify
- [ ] Test edge cases: first buy, last token, near-zero supply, zero balance sell
- [ ] Verify creator ETH accumulation matches model

### Phase 4: Deployment
- [ ] Deploy to Base mainnet via Foundry script
- [ ] Use The Agent Cafe paymaster for gas (check tank first)
- [ ] Verify contract on Basescan
- [ ] Test with small real trades
- [ ] Document contract address and deployment tx

---

## Commands

```bash
# Build
forge build

# Test (all)
forge test -vvv

# Test specific
forge test --match-test testIVNeverDecreases -vvv

# Fork test against Base
forge test --fork-url https://mainnet.base.org -vvv

# Deploy (local)
anvil --fork-url https://mainnet.base.org
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

# Deploy (mainnet) — ONLY when ready
forge script script/Deploy.s.sol --rpc-url https://mainnet.base.org --broadcast --verify

# Python simulation
python math/model.py

# Gas report
forge test --gas-report
```

---

## Critical Rules

- **IMPORTANT:** Never expose `THRYXTREASURY_PRIVATE_KEY` in code, commits, or logs
- **IMPORTANT:** IV = Real_ETH / Circ must NEVER decrease — this is the core guarantee. Every test must assert this
- **IMPORTANT:** Spot price P_spot = V_ETH / V_TOK must NEVER decrease — every test must assert this
- **IMPORTANT:** Sells NEVER touch V_ETH or V_TOK — the curve is buy-only
- **IMPORTANT:** All ETH fees go to `0x7a3E312Ec6e20a9F62fE2405938EB9060312E334` (deployer wallet)
- **IMPORTANT:** Zero token allocation to creator — 100% of supply enters bonding curve
- **IMPORTANT:** Use The Agent Cafe paymaster for all on-chain transactions (check gas tank first)
- **IMPORTANT:** No burn cap — burns are uncapped by design. Do not add MAX_BURN_PERCENT
- Prefer `forge test` over manual testing — mathematical proofs via fuzzing
- No proxy patterns, no upgradability — immutable contract builds trust
- No external DEX liquidity at launch — the contract IS the liquidity
- Solidity `unchecked` blocks ONLY where overflow is mathematically impossible
- All math in `uint256` with 1e18 precision — no floating point anywhere
- Test with realistic Base gas prices and block times

## Terminology
- **V_ETH** — Virtual ETH reserves (bonding curve only, not real treasury)
- **V_TOK** — Virtual token reserves (bonding curve only, only decreases)
- **k** — Constant product invariant (V_ETH × V_TOK), used for buy pricing only
- **Real_ETH** — Actual ETH held in treasury, used to back IV
- **Circ** — Circulating supply: tokens held by actual users (NOT virtual reserves)
- **IV** — Intrinsic Value = Real_ETH / Circ. The true floor. Only goes up.
- **Spot price** — Current curve price = V_ETH / V_TOK. Only goes up.
- **Progressive tax** — Sell tax that decays from 25% to 1% based on hold duration
- **Creator fee** — 1% ETH extracted from each trade, sent to deployer wallet
- **One-way curve** — Buys move the curve; sells bypass it entirely

## Reference Documents
- For detailed v3 math proofs: see `memory/tokenomics-math.md`
- For model iteration history (why v1/v2 failed): see `memory/model-iterations.md`
- For simulation results: see `math/results/`
- For deployment checklist: see `docs/deploy-checklist.md`
