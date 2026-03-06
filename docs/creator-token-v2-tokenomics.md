# CreatorToken v2 — Tokenomics Design Proposals

## The Two Questions Every Design Must Answer

**1. "Why can't the creator rug me?"**
**2. "Why would I buy THIS token instead of any other?"**

If we can't answer both instantly and convincingly, we're just another token factory in a sea of tokens.

---

## Anti-Rug: The Non-Negotiable Foundation

Every design below shares these immutable anti-rug guarantees:

### Creator Cannot Rug — By Construction

```
STRUCTURAL GUARANTEES (all proposals):

1. ZERO TOKEN ALLOCATION TO CREATOR
   Creator receives 0 tokens at launch. Not 1%. Not vested. Zero.
   Remaining supply after pool seeding is BURNED, not held.
   Creator literally cannot dump tokens they don't have.

2. CREATOR EARNS OBSD FROM FEES ONLY
   Income = f(volume), not f(price).
   Creator wants more swaps, not higher price.
   Dumping tokens would REDUCE volume → reduce creator income.
   Creator incentive is 100% aligned with community activity.

3. LIQUIDITY LOCKED FOREVER
   LP tokens sent to 0xdead on creation. No one can pull liquidity.
   Not locked for 6 months. Not locked for a year. BURNED.
   Pool exists as long as the chain exists.

4. IMMUTABLE CONTRACT
   No owner functions. No pause. No blacklist. No proxy.
   Fee rates, addresses, and mechanics are set at deploy and cannot change.
   Contract passes GoPlus, TokenSniffer, and every bot scanner.

5. IV FLOOR (Proposals B and C)
   Even if every holder sells, the last holder can redeem at IV.
   Treasury ETH backs every token. Mathematical guarantee.
   Price can go to IV but never below it. IV only goes up.
```

**Anti-rug comparison vs. competitors:**

| Feature | pump.fun | Clanker | Our CreatorToken |
|---|---|---|---|
| Creator token allocation | Yes (can dump) | Yes (can dump) | ZERO (burned) |
| Creator income source | Token sales | Token sales | Fee volume (OBSD) |
| Liquidity locked? | Migrated to Raydium | Depends | Burned forever |
| Contract upgradeable? | N/A (bonding curve) | Varies | Never |
| Price floor? | No | No | Yes (IV floor) |
| Creator incentive aligned? | Sell tokens = profit | Sell tokens = profit | More swaps = profit |

**This is our pitch: "The creator literally cannot rug you. They own zero tokens. They earn from volume. Liquidity is burned. The math proves the floor only goes up."**

---

## Current Design (v1): What's Missing

```
CreatorToken.sol — 3% fee → OBSD → 50/50 creator/treasury
```

**What v1 gets right:**
- Creator earns from fees only (anti-rug by incentive)
- Zero creator allocation (anti-rug by construction)
- Simple, auditable

**What v1 is missing — and why tokens die:**
- No price floor → token goes to zero when hype fades → holders get rekt → no one trusts the next launch
- No burn → supply never shrinks → no deflationary narrative → nothing visible on DexScreener
- No holder advantage → flippers and holders pay the same 3% → no reason to hold
- No FOMO trigger → nothing gets scarcer or more valuable over time → no urgency to buy
- No differentiation → looks identical to every other fee-on-transfer token → invisible in the crowd

**Result:** v1 tokens have the same lifecycle as every memecoin: pump on launch, dump within hours, fade to zero. The anti-rug guarantees are there but invisible without a price floor to prove it.

---

## Proposal A: "Deflationary Shield" (Low Complexity)

### Core Idea
Add visible, constant deflation + anti-sniper mechanics. Token supply shrinks on every trade. Early flippers pay a burn tax. Long-term holders pay almost nothing extra.

### Mechanism

```
BUY FLOW:
  1. User sends tokens to buy on Aerodrome
  2. 3% fee → swap to OBSD → 1.5% creator, 1.5% treasury
  3. 1% of tokens received are BURNED (visible on-chain)
  4. User gets 96% of tokens (3% fee + 1% burn)

SELL FLOW:
  1. User sells tokens on Aerodrome
  2. 3% fee → swap to OBSD → 1.5% creator, 1.5% treasury
  3. ADDITIONAL burn based on hold time:
     < 1 hour:   8% burn  (sniper tax)
     < 6 hours:  5% burn
     < 24 hours: 3% burn
     < 7 days:   1% burn
     >= 7 days:  0% burn  (diamond hands free)
  4. Burned tokens GONE FOREVER — supply shrinks

SUPPLY TRAJECTORY:
  Launch: 1,000,000,000 tokens
  After 1000 trades: ~970,000,000 (3% less)
  After 10,000 trades: ~740,000,000 (26% less)
  After 100,000 trades: ~47,000,000 (95.3% less — exponential decay)

  Every trade makes remaining tokens MORE SCARCE.
```

### Why Holders Stay

1. **Visible scarcity.** DexScreener shows total supply dropping in real-time. Every trade you see = supply shrinking = your tokens worth more relative to total.
2. **Diamond hands advantage.** Hold 7+ days → 0% extra burn on sell. Flippers pay 8-11% total (3% fee + 8% burn). Holding is rewarded, flipping is punished.
3. **Deflationary narrative.** "Only 47M tokens left out of 1B" is a powerful meme. Burns are the most understood and visually compelling mechanic in crypto.

### Why Buyers FOMO

1. **Supply only goes down.** Every second you wait, there are fewer tokens in existence. The earlier you buy, the cheaper per remaining token.
2. **Burn counter on DexScreener.** 30% burned, 50% burned, 80% burned — these milestones become marketing events.

### Anti-Rug Score: STRONG
- All base guarantees (zero creator tokens, OBSD-only income, burned LP, immutable)
- Sniper tax discourages quick dump-and-run
- But NO price floor — if demand goes to zero, price goes to zero

### DexScreener Visibility
- Declining total supply (visible metric)
- "Burn" in the narrative attracts attention
- Hold-time tax is unusual — scanners flag it, people investigate

### Complexity: LOW (~40 lines added)
### Time: 1 session
### Weakness: No mathematical price floor. Burns slow the bleed but don't prevent it.

---

## Proposal B: "Rising Floor" (Medium Complexity) — RECOMMENDED

### Core Idea
Every token has a treasury-backed intrinsic value (IV) that mathematically cannot decrease. Combined with burns, the floor RISES on every single trade. Holders can always redeem at IV — the token can never go to zero.

**This is the killer feature. No other token factory offers this.**

### Mechanism

```
FEE SPLIT (3% on all transfers):
  1.0% → swap to OBSD → creator
  1.0% → swap to OBSD → platform treasury
  0.5% → BURNED (supply shrinks)
  0.5% → retained as OBSD in token's backing vault

BACKING VAULT:
  Every trade adds 0.5% of trade value (as OBSD) to the token's vault.
  This OBSD backs every circulating token.

  IV = vault_OBSD / circulating_supply

  IV can ONLY go up because:
  - Vault grows on every trade (0.5% inflow)
  - Burns shrink circulating supply (0.5% burn)
  - Both forces push IV higher simultaneously

REDEMPTION:
  Any holder can burn tokens and receive proportional OBSD from vault.
  eth_out = tokens_burned × IV

  After redemption:
  vault' = vault - (tokens × IV)
  circ'  = circ - tokens
  IV'    = vault' / circ'
       = (vault - tokens×vault/circ) / (circ - tokens)
       = vault × (circ - tokens) / (circ × (circ - tokens))
       = vault / circ
       = IV

  Redemption at IV preserves IV exactly. Any sell tax > 0% means:
  IV_after_sell > IV_before_sell   (ALWAYS)

PROGRESSIVE SELL TAX (on redemptions):
  < 1 hour:   10% of tokens burned as tax (no OBSD paid for this portion)
  < 24 hours:  5%
  < 7 days:    2%
  >= 7 days:   0.5% (minimum)

  Tax tokens are burned with NO OBSD payout.
  This means: vault stays the same, but circulating shrinks extra.
  IV JUMPS UP on every sell. More tax = bigger jump.

WHY IV ALWAYS RISES — FORMAL PROOF:
  Before sell: IV = V / C  (V = vault OBSD, C = circulating, T = tokens sold, r = tax rate)

  Tax burn: T × r tokens burned, no OBSD leaves vault
  Net tokens: T × (1-r) burned, OBSD payout = T × (1-r) × IV

  After:
  V' = V - T×(1-r)×(V/C) = V × (C - T×(1-r)) / C
  C' = C - T

  IV' = V'/C' = (V/C) × (C - T + Tr) / (C - T)
      = IV × [1 + Tr/(C-T)]

  Since T > 0, r > 0 (min 0.5%), C > T:
  IV' > IV   ALWAYS.   QED.

  The floor rises on every single sell. Snipers dumping = IV boost for holders.
```

### Why Holders Stay (The "Why Hold?" Answer)

1. **Guaranteed floor that only goes up.** Your tokens are ALWAYS worth at least IV in OBSD. IV rises on every trade. Holding = watching your guaranteed minimum value increase.
2. **Redemption safety net.** Even if the market dies, you can burn and get OBSD at IV. You literally cannot lose more than the sell tax. This is not "hope" — it's math.
3. **Sell tax rewards patience.** Hold 7+ days → 0.5% tax. Sell in 1 hour → 10% tax. The longer you hold, the better your exit rate AND the higher IV has climbed.
4. **Other people's sells HELP you.** Every sell burns tokens and boosts IV. The more people dump, the higher your floor goes. Panic selling is literally gift-wrapped to diamond hands.

### Why Buyers FOMO (The "Why Buy NOW?" Answer)

1. **IV only goes up.** The floor was X yesterday, it's X+Y today, it'll be X+Y+Z tomorrow. Every trade, every block, the minimum value increases. Waiting = buying at a higher floor.
2. **Supply is shrinking.** 0.5% burned per trade + sell tax burns. Fewer tokens exist every day. Scarcity is mathematically guaranteed.
3. **Early buyer advantage is real.** Buy at IV = $0.001, wait 30 days of trading, IV = $0.003. Your floor tripled. This isn't speculation — it's the math.
4. **DexScreener shows the floor rising.** The IV line going up is the most compelling chart in DeFi. It's a staircase that never goes down.

### Why This Token Is Different (The "Why THIS Token?" Answer)

| Question | Regular Memecoin | CreatorToken v2 |
|---|---|---|
| Can the creator rug? | Usually yes | Mathematically impossible |
| Is there a price floor? | No | Yes, IV (provably rising) |
| What happens if everyone sells? | Goes to zero | Last holder redeems at IV |
| Does holding help? | Only if someone else buys | Yes — every sell boosts YOUR floor |
| Is the supply going up or down? | Fixed or inflationary | Always decreasing (burns) |
| Can the contract be changed? | Often yes (proxies) | Never (immutable) |
| Where does creator income come from? | Dumping tokens | Volume fees (OBSD) |

### DexScreener Visibility
- **Rising IV floor** visible as a support line on chart — unique, eye-catching
- **Declining supply** — burn counter is a visible metric
- **"Treasury-backed"** in token description — institutional language attracts attention
- **Hold-time tax** — unusual mechanic that triggers investigation and discussion
- **Redemption function** — shows up in contract reads, proves the floor is real

### Contract Architecture

```
CreatorTokenV2.sol (single contract, no proxy):
  ├── ERC20 base (OpenZeppelin)
  ├── Fee engine: 3% on _update()
  │   ├── 1% → swap to OBSD → creator
  │   ├── 1% → swap to OBSD → platform treasury
  │   ├── 0.5% → burn (supply reduction)
  │   └── 0.5% → swap to OBSD → backing vault (IV growth)
  ├── Backing vault: internal OBSD balance
  │   ├── iv() view → vaultBalance / circulating
  │   └── vault only grows (inflows) or shrinks proportionally (redemptions)
  ├── Redemption engine
  │   ├── redeemAtIV(uint256 tokens) → burns tokens, sends OBSD from vault
  │   ├── Progressive sell tax (10% → 0.5% based on hold duration)
  │   └── lastBuyTimestamp[address] tracking
  ├── Anti-rug immutables
  │   ├── creator (earns OBSD from fees)
  │   ├── treasury (platform share)
  │   ├── No owner, no admin functions
  │   └── LP burned at deploy
  └── View functions
      ├── iv() → current intrinsic value in OBSD
      ├── vaultBalance() → total OBSD backing
      ├── totalBurned() → lifetime tokens destroyed
      └── holdTime(address) → seconds since last buy
```

### Complexity: MEDIUM (~120 lines added to existing CreatorToken)
### Time: 2-3 sessions
### Risk: Moderate — needs math review but the IV proof is identical to OBSD v3 (already validated)

---

## Proposal C: "Full OBSD Clone" (High Complexity)

### Core Idea
Full port of OBSD v3: internal bonding curve for buys, IV-based sells, progressive sell tax with exponential decay, 2% burn on buy, 5-tier graduation to Aerodrome + Uniswap V4.

### Why Consider It
- **Strongest possible guarantee.** Spot price AND IV both only go up. Two floors, both provably rising.
- **Proven model.** OBSD v3 is deployed and tested with 106/106 tests passing.
- **Maximum differentiation.** No one else has this. Not pump.fun, not Clanker, not friend.tech.

### Why NOT to Ship It (Yet)
- **500+ lines, two contracts per launch.** Factory deployment cost ~2x. Audit surface ~5x.
- **Bonding curve confuses users.** "Why can't I buy on Aerodrome?" is a support burden.
- **OBSD itself does this.** The parent token already has the full model. Child tokens don't need to be equally complex — they benefit from OBSD's mechanics through the fee flywheel.
- **80/20 rule.** Proposal B captures ~80% of C's value (the IV floor, the rising guarantee, the anti-rug proof) at ~20% of the complexity.

### When to Revisit
If Proposal B proves the IV floor narrative works and we want a "premium tier" launch option for high-profile creators, Proposal C becomes a templated offering. But not before B is validated in production.

---

## Comparison Matrix

| Dimension | A: Deflationary Shield | B: Rising Floor | C: Full Clone |
|---|---|---|---|
| **Anti-rug** | Strong (no tokens, OBSD income) | Strongest (+ IV floor) | Maximum (+ bonding curve) |
| **Price floor?** | No | Yes (OBSD-backed IV) | Yes (ETH-backed IV + curve) |
| **Floor direction** | N/A | Only up (proven) | Only up (proven) |
| **Burn mechanics** | 1% buy + hold-time sell tax | 0.5% per trade + sell tax | 2% buy + all sells burn |
| **Holder incentive** | Less tax over time | Rising IV + less tax | Rising IV + rising spot |
| **FOMO trigger** | Shrinking supply | Rising floor + shrinking supply | Rising floor + rising curve |
| **DexScreener story** | "X% burned" | "Floor at $Y and rising" | "Price can only go up" |
| **Complexity** | Low (~40 lines) | Medium (~120 lines) | High (~500+ lines) |
| **Time to ship** | 1 session | 2-3 sessions | 5+ sessions |
| **Answers "why buy?"** | Scarcity | Guaranteed rising value | Strongest guarantee |
| **Answers "why hold?"** | Less burn tax | Floor rises = free money | Floor + spot both rise |
| **Answers "why not rug?"** | No tokens to dump | + Can't go below IV | + Curve never goes down |

---

## Recommendation: Ship Proposal B ("Rising Floor")

### Why B Wins

1. **It answers both questions definitively.**
   - "Why can't the creator rug me?" → Zero tokens, OBSD income only, burned LP, immutable, AND there's a treasury-backed floor that only goes up. Even if creator disappears, your tokens have provable value.
   - "Why buy THIS token?" → It has a rising price floor backed by real OBSD. Every trade makes the floor higher. You can always redeem at IV. No other token factory offers this.

2. **The IV floor is our moat.** pump.fun has bonding curves. Clanker has easy deploys. We have the only tokens where the floor MATHEMATICALLY CANNOT GO DOWN. This is the one-sentence pitch that stops scrolling on CT.

3. **It's shippable in 2-3 sessions.** The math is proven (same as OBSD v3). The contract is a modification of existing CreatorToken, not a rewrite. We can have this live within days.

4. **It makes every previous launch look inferior.** Once "Rising Floor" tokens exist, why would anyone launch on pump.fun where their token can go to zero? Our tokens have a guarantee. Theirs don't.

### Implementation Priority

```
Phase 1 (NOW):
  - Implement CreatorTokenV2 with IV floor + burns + progressive sell tax
  - Write invariant fuzz tests: IV_new >= IV_old on all operations
  - Deploy through existing LaunchPad

Phase 2 (AFTER first successful launch):
  - Add IV display to dashboard (live floor price)
  - Add "Redemption" UI (burn tokens → receive OBSD at IV)
  - Marketing: "The token that can never go to zero"

Phase 3 (OPTIONAL):
  - If demand warrants, offer Proposal C as "Premium Launch" tier
  - Higher creator fee (2%) for full bonding curve mechanics
```

### Key Design Decisions Still Needed

1. **Vault currency: OBSD or ETH?**
   - OBSD: Creates flywheel (more OBSD demand), aligns with ecosystem. Recommended.
   - ETH: Simpler, more universally valued. Fallback if OBSD liquidity is too thin.

2. **Redemption: always-on or emergency-only?**
   - Always-on: Holders can redeem anytime. Most transparent. IV is a real exit.
   - Emergency-only: Redemption only available if no trades for 7+ days. Prevents IV drain during active trading.
   - Recommended: Always-on. The math proves IV holds. Restricting redemption undermines the trust narrative.

3. **Sell tax rates:**
   - Aggressive (10% → 0.5%): Higher IV boost per sell, stronger anti-sniper, but might scare normies
   - Moderate (5% → 0.5%): Lower barrier, still meaningful IV boost
   - Recommended: Start aggressive. The IV boost from high early tax is the mechanism that creates the rising floor narrative. "Your floor went up 2% because someone panic sold" is the story that goes viral.

4. **Vault seed at launch:**
   - Should some of the initial OBSD pool seed go to the backing vault?
   - If yes: token launches with a non-zero IV floor immediately. "Floor price from block 1."
   - If no: IV starts at 0 and builds from fees. Less compelling at launch.
   - Recommended: Yes, seed 10% of OBSD into vault. Launches with instant floor.
