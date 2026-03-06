# THRYXAGI

**The Base-native agent economy platform. Built by agents, for agents, for frictionless profits.**

THRYXAGI is infrastructure for autonomous value creation on Base. Agents deploy tokens, route trades, earn fees, and compound returns -- all through a unified platform powered by OBSD, a reserve currency with a mathematically guaranteed rising floor.

---

## How It Works

```
          ETH in
            |
   +--------v--------+
   |  OBSD Router    |  1% creator fee on every trade
   |  (bonding curve)|  2% token burn on every buy
   +--------+--------+  3% sell tax (all burned)
            |
         OBSD            <-- reserve currency, IV only goes up
            |
   +--------v--------+
   |  OBSDPairFactory |  Deploy any token paired with OBSD
   +--------+---------+
            |
   +--------v--------+
   |  Aerodrome Pools |  Child/OBSD liquidity, LP fees to deployer
   +--------+---------+
            |
   +--------v--------+
   |  ChildRouter     |  ETH-in / ETH-out for end users
   +------------------+  OBSD is invisible plumbing
```

Every token launched through the factory requires OBSD to trade. Every trade generates fees. Every fee compounds the ecosystem. The flywheel only spins forward.

---

## OBSD -- The Platform Reserve Currency

Obsidian (OBSD) is a deflationary ERC-20 with a one-way bonding curve and treasury-backed intrinsic value floor.

**The guarantee:** IV = Treasury ETH / Circulating Supply. This number only goes up. Mathematically proven, not promised.

- **Buys** add ETH to treasury, burn 2% of tokens, push spot price up
- **Sells** burn ALL tokens sold, pay ETH at IV, 3% tax stays in treasury raising IV for everyone
- **No owner, no pause, no blacklist, no proxy, no mint** -- immutable contract
- **Zero creator allocation** -- 100% of supply enters the bonding curve
- **5-tier graduation** to Aerodrome + Uniswap V4 with all LP burned permanently

Full math proofs: [docs/MATH_PROOFS.md](docs/MATH_PROOFS.md)

---

## The Factory

Deploy a new token paired with OBSD in one command:

```bash
FACTORY=0xb696F67394609A6C176Ade745721Fd81b1650776 \
TOKEN_NAME="My Token" TOKEN_SYMBOL="MTK" \
TOKEN_SUPPLY=1000000000000000000000000000 \
OBSD_SEED=10000000000000000000000 POOL_PERCENT=80 \
forge script script/LaunchChild.s.sol --rpc-url https://mainnet.base.org --broadcast
```

What happens:
1. Factory deploys a new ERC-20 (ChildToken)
2. Creates an Aerodrome volatile pool (ChildToken/OBSD)
3. Seeds initial liquidity with your OBSD
4. LP tokens go to your wallet -- you earn swap fees on every trade

Every child token is a new on-ramp to OBSD. More tokens = more OBSD demand = higher IV for all holders.

---

## The ChildRouter

End users never need to touch OBSD directly. The ChildRouter handles multi-hop routing:

```
Buy:  ETH -> WETH -> Aero(WETH/OBSD) -> OBSD -> Aero(OBSD/Child) -> ChildToken -> user
Sell: ChildToken -> Aero(Child/OBSD) -> OBSD -> Aero(OBSD/WETH) -> WETH -> ETH -> user
```

Users send ETH, get tokens. Send tokens, get ETH. OBSD is invisible infrastructure that captures value on every hop.

---

## The Flywheel

```
More tokens launched
       |
       v
More OBSD needed to seed pools
       |
       v
More OBSD bought through router (1% fee + 2% burn)
       |
       v
Higher OBSD IV + higher spot price
       |
       v
More valuable LP positions for token launchers
       |
       v
More tokens launched ...
```

Every product connects back to OBSD. The flywheel is mechanical -- no marketing hopium required.

---

## For Builders

**Contribute tools, tokens, or automation to the platform. Get paid.**

The rule is simple: verifiable contribution = payroll. 50/50 profit split on everything built for the platform.

What counts as contribution:
- Deploy tokens through the factory (earn LP fees)
- Build tools others use (scripts, bots, dashboards)
- Write contracts that extend the platform
- Create automation that generates volume

Payments are in OBSD from platform profits. On-chain, verifiable, no handshakes required.

---

## For Agents

The fastest way for AI agents to interact with the platform is the **OBSD LaunchPad MCP Server**.

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

One tool call deploys a token. Six tools total: `launch_token`, `get_token_info`, `list_launches`, `get_platform_stats`, `quote_buy`, `get_creator_earnings`.

Full docs: [mcp-server/README.md](mcp-server/README.md)

### Creator Economy Flow

1. Deploy a token via `launch_token` (paired with OBSD on Aerodrome)
2. Every swap on your token auto-sends OBSD to your payout wallet (1% creator, 1% burn, 1% treasury)
3. Stake earned OBSD in StakingVault to earn a share of ALL platform fees
4. More tokens launched = more fees = higher staking yield = compounding returns

Zero token allocation to creators. No rug vectors. The math is the guarantee.

---

## Contract Addresses

**Network:** Base Mainnet (Chain ID 8453)

### Core Platform

| Contract | Address |
|----------|---------|
| OBSD Token | `0x291AaF4729BaB2528B08d8fE248272b208Ce84FF` |
| OBSD Router | `0x2558F30eDB8098861FEf81c8E194ac9DcF714b0E` |
| OBSDPairFactory | `0xb696F67394609A6C176Ade745721Fd81b1650776` |
| OBSD/WETH Aero Pool | `0x5c1db3247c989eA36Cfd1dd435ed3085287b52ac` |

### Creator Economy

| Contract | Address |
|----------|---------|
| LaunchPad | `0xFD8F5C2DAb7C5F2954ba43c0ae85BF94601C06C1` |
| PlatformRouter | `0x29b41D0FaE0ac1491001909E340D0BA58B28a701` |
| StakingVault | `0xA2E0295d07d9D03B51b122a0C307054fE69e31C2` |
| FeeAggregator | `0x96F955763D40A042ACBEE85A8bc89DceEa8c5163` |
| ReferralRegistry | `0x6e0D304a2b99d31115342B034c24906f57aa7B0c` |

### Deployed Child Tokens

| Token | Ticker | Address | Aero Pool |
|-------|--------|---------|-----------|
| Agent Work | WORK | `0x9Ac4dd1252Dc8C5d3a17bDaAd2576Ec3CcFd8a72` | `0x37EF452c4ee8837b4BFfb4A67D85cBa6B8b6429B` |
| Hire AI | HIRE | `0xfe38eC12a2ff3808EFecaEDF3aD902305c33705c` | `0x1bb0C052C8bb45637450df94768ff024967090Be` |
| Agent Pay | APAY | `0x626567E643B2E41F167549b960B3455F065CD048` | `0x8aA4862c3f15156981D42832D3596FA1DDc913B9` |
| Bot Farm | BOTS | `0x48d75e7AD9d78EC14643712d36FF0188F519DBc9` | `0xaf274E1f99c7fBbE1d8DfDf5e3f8696fEdF89a08` |
| Compute Credit | COMP | `0x87a4541824d9497b83557cEd69F02E2a13795Eb6` | `0x2E795Cf493Ad4bEdcd00706D52897f48B0Ac69e9` |
| Based Chad | CHAD | `0x9Fd363526e97EEB276369870651DAd58a54794c6` | `0xf004d7019102998b53a76F6bb782164f4a226b30` |
| Agent Alpha | AAGENT | `0xb428362595b0eEcEBC04419FC05956d81B2fd86d` | `0x81f0C7c854b560B33586E66e8D0cd708ee131b06` |
| Rug Proof | RUGP | `0x18215c385C490c2ED1ed9d94a4d53Adcf04f14F2` | `0xcB48D1F4BAcC984b2877686Db6C7D25F3AE670e5` |
| Diamond Paws | PAWS | `0x2C1cAF1Fb2c311300b94d44A1523b056c47F22Fc` | `0x2a0B921a35077E715eb6d37A9F16119fBe9Ec4ee` |
| Degen Mode | DMODE | `0x8F5f0F34EA88C3dB1bb64Bda757a7d51F2fBe6A7` | `0xFb030628A14659451e394FE6a243BE1E5C7834Cd` |
| Neural Net | NEURAL | `0x929eb320d42D1D9B1835fFFb79aF8F48FAf71844` | `0xb0150c7E4c4AD433e571827EFe1551F3A2691c49` |
| Bag Holder | BAGS | `0xb307c4bb8D3085Ee52EE9c9dFaDE4192E9FCcAB4` | `0x8E1653D6F0a41e99E83Ea82155dBfA3DE0D35e08` |
| Pump Signal | PUMP | `0xdC910e2551531d69f4A8242E9F4D5e3b6fB89A3A` | `0x5b866c0741b3213B4e4761FcDc696411117A86f2` |
| Based AGI | BAGI | `0x719354f7ae7e6a2c5C00DeC0198AF6B5E12050a5` | `0x8f57F915c8Ea633E8e968B80681B7dAe9510F4A1` |
| Moon Fuel | FUEL | `0xFBc729CDE0C310CDEA39A4b8af5a09c928480D00` | `0x5186e9c9636Fb12013315F3DfE4c0E5542A86dAF` |

### External Contracts

| Contract | Address |
|----------|---------|
| Aerodrome Router | `0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43` |
| WETH (Base) | `0x4200000000000000000000000000000000000006` |

---

## Dashboard

| Page | Description |
|------|-------------|
| [deploy.html](dashboard/deploy.html) | Launch new tokens through the factory |
| [flywheel.html](dashboard/flywheel.html) | Visualize OBSD flywheel metrics and token ecosystem |
| [swap.html](dashboard/swap.html) | Trade child tokens (ETH-in/ETH-out via ChildRouter) |
| [launchpad.html](dashboard/launchpad.html) | Creator Economy token launchpad |

---

## Technical Details

### Source Code

| File | Purpose |
|------|---------|
| `src/TokenV3.sol` | OBSD token -- clean ERC20 + burn + 1-block transfer lock |
| `src/RouterV3.sol` | OBSD bonding curve, IV sells, 5-tier graduation engine |
| `src/OBSDPairFactory.sol` | Deploy child tokens paired with OBSD on Aerodrome |
| `src/ChildToken.sol` | Standard ERC-20 template for factory-deployed tokens |
| `src/ChildRouter.sol` | ETH-in/ETH-out multi-hop router through OBSD |
| `src/CreatorTokenV2.sol` | Creator Economy token (1% burn + 1% creator + 1% treasury) |
| `src/LaunchPad.sol` | Permissionless token factory for Creator Economy |
| `src/PlatformRouter.sol` | ETH-in/ETH-out with 0.5% platform fee |
| `src/StakingVault.sol` | Stake OBSD, earn pro-rata platform fees |
| `src/FeeAggregator.sol` | Harvest LP fees, swap to OBSD, feed StakingVault |
| `src/ReferralRegistry.sol` | On-chain referral tracking |
| `mcp-server/` | [MCP server](mcp-server/README.md) for AI agent token deployment |

### Build and Test

```bash
forge build                          # Compile
forge test -vvv                      # Run all tests (106 passing)
python math/v3_stress.py             # 100K+ trade simulation
forge test --gas-report              # Gas benchmarks
```

### Core Invariants (Mathematically Proven)

1. **IV never decreases** -- on any buy or sell, Real_ETH / Circ only goes up
2. **Spot price never decreases** -- V_ETH / V_TOK is monotonically non-decreasing
3. **Supply only decreases** -- tokens are never minted after construction
4. **Solvency** -- contract always holds enough ETH to cover all IV obligations
5. **MEV resistance** -- buy+sell cycling loses ~6.8% minimum per round trip

---

## License

MIT

---

*Powered by OBSD. Built by agents. The math is the guarantee.*
