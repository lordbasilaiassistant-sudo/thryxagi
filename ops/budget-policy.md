# THRYXAGI Budget Policy

## Gas Limits

| Operation | Max Gas (ETH) | Notes |
|-----------|---------------|-------|
| Token launch (child via factory) | 0.00005 | ~0.000017 avg observed |
| Contract deploy (new contract) | 0.00020 | Factory was 0.000016, Router 0.000004 |
| Trading tx (buy/sell) | 0.00001 | ~0.0000035 avg observed |
| Payroll tx (OBSD transfer) | 0.000005 | ~0.0000003 avg observed |

## OBSD Seed Limits

- Max 10K OBSD per child token launch (learned from 500K mistake in batch 1)
- Total pool seed cap: 50K OBSD across all new launches before any generate revenue
- Exception: promotional flagship tokens may use up to 50K with CEO approval

## Reserve Minimums

| Asset | Minimum Reserve | Purpose |
|-------|----------------|---------|
| ETH (deployer) | 0.0005 ETH | Emergency gas for claims and critical ops |
| OBSD (deployer) | 500,000 OBSD | Payroll buffer for 5 agents x 100K |
| ETH (OBSD treasury) | Do not withdraw | Backs IV floor — never touch |

## Profit Split: 50/50

All profits are split equally between treasury and builders.

**Definition:** Profit = claimable fees (creator fees + LP fees) - gas costs for the period.

| Recipient | Share | Form | Purpose |
|-----------|-------|------|---------|
| Treasury | 50% | ETH or OBSD compound | Grows IV, funds operations, reserves |
| Builders/Employees | 50% | OBSD payroll | Distributed proportional to verified contribution |

**Applies to ALL revenue sources:**
- OBSD RouterV3 creator fees
- Child token LP fees
- Doppler fees
- Any future platform revenue

**Distribution rules:**
- Profit is calculated at each fee claim event
- If profit is negative (gas > revenue), no builder payout — deficit carries forward
- Builder share is converted to OBSD at current IV and distributed via payroll
- Treasury share stays as ETH (compounds into OBSD buys or reserves)
- Contribution tracking: each agent/builder logs work in ops/ — Vault verifies before payout

**Current status (2026-03-06):**
- Cumulative profit: -0.000322 ETH (negative — gas exceeds revenue)
- Builder payout owed: 0 (deficit must be cleared first)
- Treasury payout owed: 0

## Fee Compounding Rules

- Claim creator fees when pending > 0.001 ETH
- Below 0.001 ETH: gas cost of claim (~0.000003 ETH) is >0.3% of fees — not worth it
- After claiming, reinvest treasury's 50% via bonding curve buy only if deployer ETH > reserve minimum

## Launch Gates

- STOP launching new tokens when:
  - Deployer OBSD < 500,000 (payroll reserve)
  - Deployer ETH < 0.0005 (gas reserve)
  - More than 5 tokens have zero volume (focus on marketing existing ones first)
- RESUME launching when:
  - At least 3 tokens show organic volume (not self-trades)
  - Revenue covers last 10 launches' gas costs

## Spending Approval

- Gas < 0.00005 ETH: auto-approved
- Gas 0.00005 - 0.0005 ETH: requires Vault review
- Gas > 0.0005 ETH: requires CEO (drlor) approval
- Any ETH leaving deployer wallet (not gas): requires CEO approval

## Current Status Assessment

As of 2026-03-06:
- Deployer ETH: 0.001543 (above 0.0005 reserve)
- Deployer OBSD: 2,187,170 (above 500K reserve)
- Net P&L: -0.000322 ETH (gas exceeds revenue by 6.7x)
- Revenue rate: 0.000048 ETH earned on $6.59 volume
- Break-even requires: ~$44 cumulative volume at 1% fee rate
- Key bottleneck: ZERO volume on 32/33 tokens. Marketing, not launching, is the path to revenue.
