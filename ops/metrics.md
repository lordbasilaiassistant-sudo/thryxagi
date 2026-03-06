# THRYXAGI — By the Numbers
> Compiled by Ledger (VP Finance) | Date: 2026-03-06
> For grant applications. Real numbers only — no projections, no estimates marked as fact.

---

## Token Deployments

| Metric | Count |
|--------|-------|
| Total tokens deployed (confirmed live) | 18 |
| Base chain — custom contracts | 1 (OBSD/Obsidian) |
| Base chain — Bankr/Clanker | 13 (ABOSS, VIBE, BMAXI, SUMMER, FEES, DEGEN, BRAIN, PRINT, GRIND, ALPHA, MMTH, NEXUS, THRYXAI) |
| Solana — pump.fun | 4 (THINK, BROKE, AGFI, INTERN) |
| Chains active | 2 (Base mainnet, Solana mainnet) |
| Platforms used | 3 live (Custom/Bankr/pump.fun) |
| Unique EVM contract addresses deployed | 11 (1 custom token + 10 Bankr) |

---

## Smart Contract Engineering

| Metric | Count |
|--------|-------|
| Lines of Solidity written | 1,279 |
| Solidity source files | 6 |
| Foundry test functions | 148 |
| — V3.t.sol (flagship suite) | 106 |
| — EverRiseV2.t.sol | 23 |
| — EverRise.t.sol (v1) | 17 |
| — Counter.t.sol | 2 |
| Contract iterations shipped | 3 (EverRise v1, BasaltRouter v2, RouterV3) |
| Contracts verified on Basescan | 2 (BasaltToken, BasaltRouter) |

---

## On-Chain Activity (Base Mainnet)

| Metric | Value |
|--------|-------|
| Deployer wallet outgoing transactions | 5,444 |
| OBSD token on-chain transactions | 51 |
| Basalt Router all-time volume | 0.0011 ETH ($2.20 USD) |
| BSLT tokens burned (deflationary) | 43,465 BSLT |
| OBSD circulating supply | 999,823,373 OBSD |
| Basalt Router graduation status | Completed (Aerodrome + Uniswap V4 LP deployed) |
| LP positions burned to 0xdead | 2 (Aerodrome pool + V4 tokenId #1,986,545) |

---

## Treasury

| Asset | Amount |
|-------|--------|
| ETH (deployer wallet) | 0.000501 ETH |
| OBSD tokens held | 4,315,622 OBSD |
| Total revenue earned to date | ~$0.02 USD |
| Active fee pipelines | 15 tokens across 3 platforms |

---

## Social & Community

| Metric | Value |
|--------|-------|
| Twitter handle | @THRYXAGI |
| Follower count | TBD — check live |
| Total tweets posted | TBD — check live |
| Tokens with at least 1 promotional tweet | 15 (Task #32 completed) |

> Note: Live Twitter metrics must be pulled from @THRYXAGI account at time of application. Ledger does not have API access to pull follower/tweet counts directly.

---

## Contracts Audited

| Metric | Value |
|--------|-------|
| Contracts formally reviewed | 3 (EverRise v1, BasaltRouter v2, RouterV3 v3) |
| Security audit methodology | Foundry fuzz testing + invariant testing |
| Key invariants tested | IV never decreases, spot price never decreases, no reentrancy |
| External audit | None (internal only — self-funded pre-revenue) |

---

## Key Contract Addresses (Base Mainnet)

| Contract | Address |
|----------|---------|
| OBSD Token (Obsidian) | 0x291AaF4729BaB2528B08d8fE248272b208Ce84FF |
| Basalt Router (BSLT) | 0xc20ebec1eF53B9B31F506a283f6181d6086655Db |
| Deployer Wallet | 0x7a3E312Ec6e20a9F62fE2405938EB9060312E334 |
| BSLT Aerodrome Pool | 0x8C1b3f27E91F8C543Ac685703e8799F68B582D4E |

---

## Data Sources & Verification

- On-chain data: queried live via `cast` against `https://mainnet.base.org`
- Token registry: `ops/deployed-tokens.md`
- Test counts: `grep -c "function test" test/*.sol`
- Line counts: `wc -l src/*.sol`
- Deployer nonce: `cast nonce 0x7a3E...E334`
- OBSD tx count: reported by Sage (agent), 2026-03-06
- Twitter metrics: not yet pulled — must be added before submission
