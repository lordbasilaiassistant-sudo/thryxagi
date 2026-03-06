# Obsidian (OBSD) Deployment Checklist

## Pre-Deploy Verification

### Code Review
- [ ] TokenV3.sol: No Ownable, no pause, no blacklist, no mint after constructor
- [ ] TokenV3.sol: 1-block transfer lock works (lastReceiveBlock mapping)
- [ ] TokenV3.sol: setRouter can only be called once by deployer
- [ ] RouterV3.sol: sell() works in BondingCurve AND Hybrid phases (not just BondingCurve)
- [ ] RouterV3.sol: No MAX_BUY — curve handles whale protection via slippage
- [ ] RouterV3.sol: Pull-pattern fees (pendingCreatorFees + claimFees)
- [ ] RouterV3.sol: try/catch on all DEX calls with tierFailed[] recovery
- [ ] RouterV3.sol: sweepResidualETH only sweeps dust (protects realETH)
- [ ] RouterV3.sol: receive() only accepts ETH from self, Aero, or V4

### Test Suite
- [ ] 106/106 Foundry tests pass: `forge test --match-path test/V3.t.sol -vv`
- [ ] 5/5 fuzz tests pass (1000 runs): `forge test --match-test testFuzz --fuzz-runs 1000`
- [ ] 13/13 Python stress tests pass (100K+ trades): `python math/v3_stress.py`
- [ ] Gas report acceptable: `forge test --match-path test/V3.t.sol --gas-report`

### Assets
- [ ] Token logo SVG created: `assets/obsidian-logo.svg`
- [ ] Logo uploaded to IPFS via Pinata: `node scripts/upload-to-pinata.js`
- [ ] Metadata JSON uploaded to IPFS
- [ ] IPFS CIDs saved in `assets/ipfs-results.json`

### Environment
- [ ] THRYXTREASURY_PRIVATE_KEY set in environment
- [ ] PINATA_JWT set in environment
- [ ] Deployer wallet has sufficient ETH: `cast balance 0x7a3E312Ec6e20a9F62fE2405938EB9060312E334 --rpc-url https://mainnet.base.org`
- [ ] RPC endpoint responsive: `cast block-number --rpc-url https://mainnet.base.org`

---

## Deployment Steps

### Step 1: Upload Assets to IPFS
```bash
node scripts/upload-to-pinata.js
```
Save the logo CID and metadata CID from the output.

### Step 2: Deploy Contracts
```bash
# Set token name/symbol (optional — defaults to Obsidian/OBSD)
export TOKEN_NAME="Obsidian"
export TOKEN_SYMBOL="OBSD"

# Deploy to Base mainnet
forge script script/DeployV3.s.sol \
  --rpc-url https://mainnet.base.org \
  --broadcast \
  --verify \
  --etherscan-api-key $BASESCAN_API_KEY
```

Record the output addresses:
- TokenV3: `0x___`
- RouterV3: `0x___`

### Step 3: Verify Deployment State
```bash
# Verify token setup
cast call <TOKEN_ADDR> "router()(address)" --rpc-url https://mainnet.base.org
cast call <TOKEN_ADDR> "totalSupply()(uint256)" --rpc-url https://mainnet.base.org
cast call <TOKEN_ADDR> "balanceOf(address)(uint256)" <ROUTER_ADDR> --rpc-url https://mainnet.base.org

# Verify router setup
cast call <ROUTER_ADDR> "phase()(uint8)" --rpc-url https://mainnet.base.org
# Should return 0 (BondingCurve)
cast call <ROUTER_ADDR> "vETH()(uint256)" --rpc-url https://mainnet.base.org
# Should return 500000000000000000 (0.5 ETH)
cast call <ROUTER_ADDR> "spotPrice()(uint256)" --rpc-url https://mainnet.base.org
cast call <ROUTER_ADDR> "creator()(address)" --rpc-url https://mainnet.base.org
# Should return 0x7a3E312Ec6e20a9F62fE2405938EB9060312E334
```

### Step 4: Verify on Basescan
- [ ] TokenV3 contract verified: `https://basescan.org/address/<TOKEN_ADDR>#code`
- [ ] RouterV3 contract verified: `https://basescan.org/address/<ROUTER_ADDR>#code`
- [ ] Both show green checkmark for "Contract Source Code Verified"

### Step 5: Test Buy (Small Amount)
```bash
# First test buy — 0.001 ETH (should trigger Tier 0)
cast send <ROUTER_ADDR> "buy(uint256)" 0 \
  --value 0.001ether \
  --rpc-url https://mainnet.base.org \
  --private-key $THRYXTREASURY_PRIVATE_KEY
```

After first buy, verify:
```bash
# Phase should be 1 (Hybrid) — Tier 0 triggered
cast call <ROUTER_ADDR> "phase()(uint8)" --rpc-url https://mainnet.base.org
cast call <ROUTER_ADDR> "tierCompleted(uint8)(bool)" 0 --rpc-url https://mainnet.base.org
cast call <ROUTER_ADDR> "circulating()(uint256)" --rpc-url https://mainnet.base.org
cast call <ROUTER_ADDR> "iv()(uint256)" --rpc-url https://mainnet.base.org
cast call <ROUTER_ADDR> "aeroPool()(address)" --rpc-url https://mainnet.base.org
```

### Step 6: Test Sell (Verify IV Holds)
```bash
# Approve router to spend tokens
cast send <TOKEN_ADDR> "approve(address,uint256)" <ROUTER_ADDR> 1000000000000000000 \
  --rpc-url https://mainnet.base.org \
  --private-key $THRYXTREASURY_PRIVATE_KEY

# Wait 1 block, then sell 1 token
cast send <ROUTER_ADDR> "sell(uint256,uint256)" 1000000000000000000 0 \
  --rpc-url https://mainnet.base.org \
  --private-key $THRYXTREASURY_PRIVATE_KEY

# Verify IV increased
cast call <ROUTER_ADDR> "iv()(uint256)" --rpc-url https://mainnet.base.org
```

---

## Post-Deploy Verification

### Scanner Checks
- [ ] GoPlus Token Security API: `https://api.gopluslabs.io/api/v1/token_security/8453?contract_addresses=<TOKEN_ADDR>`
  - Expected: is_honeypot=0, transfer_pausable=0, owner_change_balance=0, can_take_back_ownership=0
- [ ] TokenSniffer: `https://tokensniffer.com/token/base/<TOKEN_ADDR>`

### DEX Indexing
- [ ] Check Aerodrome pool exists: `cast call <ROUTER_ADDR> "aeroPool()(address)"`
- [ ] DexScreener: `https://dexscreener.com/base/<TOKEN_ADDR>` — should show after Tier 0
- [ ] DEXTools: `https://www.dextools.io/app/en/base/pair-explorer/<AERO_POOL>`

### Functional Tests
- [ ] Buy works from different wallet
- [ ] Sell works in Hybrid phase (IV increases after sell)
- [ ] claimFees() works for creator
- [ ] Transfer lock blocks same-block transfers after buy
- [ ] Transfer works next block after buy

### Future Verification (When Revenue Allows)
- [ ] CoinGecko listing request (requires fees)
- [ ] CoinMarketCap listing request
- [ ] DexScreener paid features (logo, banner, social links)
- [ ] Additional DEX aggregator registrations

---

## Contract Constants (Final)

| Constant | Value | Purpose |
|----------|-------|---------|
| TOTAL_SUPPLY | 1,000,000,000 (1B) | Initial token supply |
| INITIAL_VIRTUAL_ETH | 0.5 ETH | Bonding curve shape |
| CREATOR_FEE_BPS | 100 (1%) | Fee on buys and sells |
| BURN_BPS_ON_BUY | 200 (2%) | Token burn on buys |
| SELL_TAX_BPS | 300 (3%) | Sell tax (burned, IV boost) |
| MIN_BUY_ETH | 0.0001 ETH | Dust prevention |
| MIN_CIRCULATING | 1e18 (1 token) | Floor for circulating supply |
| TIER_0_THRESHOLD | 0.0005 ETH | Seed DEX pools |
| TIER_1_THRESHOLD | 0.005 ETH | Add liquidity |
| TIER_2_THRESHOLD | 0.02 ETH | Add more liquidity |
| TIER_3_THRESHOLD | 0.1 ETH | Add more liquidity |
| TIER_4_THRESHOLD | 0.5 ETH | Final graduation |

## External Addresses (Base Mainnet)

| Address | Contract |
|---------|----------|
| 0x7a3E312Ec6e20a9F62fE2405938EB9060312E334 | Creator/Deployer |
| 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43 | Aerodrome Router |
| 0x7C5f5A4bBd8fD63184577525326123B519429bDc | V4 PositionManager |
| 0x000000000022D473030F116dDEE9F6B43aC78BA3 | Permit2 |
| 0x4200000000000000000000000000000000000006 | WETH (Base) |

## Emergency Procedures

### If Tier Fails
```bash
# Check which tier failed
cast call <ROUTER_ADDR> "tierFailed(uint8)(bool)" <TIER_NUM> --rpc-url https://mainnet.base.org

# Retry the failed tier
cast send <ROUTER_ADDR> "retryTier(uint8)" <TIER_NUM> \
  --rpc-url https://mainnet.base.org \
  --private-key $THRYXTREASURY_PRIVATE_KEY
```

### If Creator Needs Fees
```bash
cast call <ROUTER_ADDR> "pendingCreatorFees()(uint256)" --rpc-url https://mainnet.base.org
cast send <ROUTER_ADDR> "claimFees()" \
  --rpc-url https://mainnet.base.org \
  --private-key $THRYXTREASURY_PRIVATE_KEY
```
