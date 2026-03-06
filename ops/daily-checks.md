# Daily & Weekly Checks

## Daily (every session start)

### 1. Deployer Gas Runway
```bash
cast balance 0x7a3E312Ec6e20a9F62fE2405938EB9060312E334 --rpc-url https://mainnet.base.org --ether
```
- [ ] Balance > 0.0005 ETH (OK) / < 0.0001 ETH (CRITICAL)
- Estimate: ~0.000002 ETH per tx, divide balance to get tx runway

### 2. OBSD Router Pending Fees
```bash
cast call 0x2558F30eDB8098861FEf81c8E194ac9DcF714b0E "pendingCreatorFees()(uint256)" --rpc-url https://mainnet.base.org
```
- [ ] If > 0 and profitable after gas (~0.000002), claim via `./thryx claim obsd`

### 3. OBSD Treasury (realETH)
```bash
cast call 0x2558F30eDB8098861FEf81c8E194ac9DcF714b0E "realETH()(uint256)" --rpc-url https://mainnet.base.org
```
- [ ] Confirm realETH >= previous session value (should never decrease)
- [ ] Track progress to next tier threshold (current: Tier 1, next at 0.005 ETH cumulative)

### 4. Child Pool Status (5 pools)
```bash
# Check claimable fees on all pools (view calls, free)
for pool in 0x37EF452c 0x1bb0C052 0x8aA4862c 0xaf274E1f 0x2E795Cf4; do
  cast call "${pool}..." "claimable0(address)(uint256)" 0x7a3E312Ec6e20a9F62fE2405938EB9060312E334 --rpc-url https://mainnet.base.org
done
```
- [ ] Any non-zero = claim if profitable after gas

### 5. DexScreener Indexing
- [ ] Check OBSD on DexScreener (should show pair)
- [ ] Check child tokens (WORK, HIRE, APAY, BOTS, COMP) -- need first trade to index
- Or run: `./thryx monitor` (does this automatically)

### 6. Cross-Check Ledger
- [ ] Compare `state/treasury.json` totals against on-chain values
- [ ] Compare against `state/ledger.json` if it exists (Vault maintains this)
- [ ] Flag any discrepancy > 0.0001 ETH

## Weekly

### 7. Full Token Audit
- [ ] Verify all 5 agent wallets still hold expected OBSD (100K each)
- [ ] Verify all child pool OBSD seed amounts match expectations
- [ ] Check Aero OBSD/WETH pool balance
- [ ] Check total supply hasn't changed unexpectedly

### 8. Revenue Trend
- [ ] Compare weekly total revenue vs previous week
- [ ] Compute revenue per tx average
- [ ] Log in state/analytics.json

### 9. Gas Efficiency
- [ ] Review tx count vs ETH spent ratio
- [ ] Confirm no wasted gas on failed txs (check basescan)
- [ ] Rebalance if deployer ETH < 0.0002

### 10. Strategy Check
- [ ] Are we closer to next tier? By how much?
- [ ] Any child pool with volume? If yes, prioritize marketing there
- [ ] Twitter credits remaining? Queue status?

## Quick One-Liner (run at session start)
```bash
./thryx monitor
```
This runs checks 1-5 automatically and flags required actions.
