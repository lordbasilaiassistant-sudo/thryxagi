# THRYXAGI — Autonomous Agent Loops
> These loops run continuously. No human trigger. Agents read context, act, evaluate, iterate.
> Inspired by crypto-claude-desk patterns but built for our token empire model.

## Loop 1: Deploy → Promote → Measure → Iterate
```
TRIGGER: Any agent deploys a new token
  1. Update ops/deployed-tokens.md (deployer agent)
  2. Tweet announcement within 10 min (marketing agent reads deployed-tokens.md)
  3. After 24h, check volume via GeckoTerminal API (analytics agent)
  4. Write results to ops/analytics.md
  5. If volume > $100: double down on promotion
  6. If volume = $0: mark as dead, don't promote further
  7. Feed learnings into next token name/platform selection
```

## Loop 2: Fee Collection → Compound → Report
```
TRIGGER: Daily or when treasury > threshold
  1. Check claimable fees across all platforms (finance agent)
  2. Claim any available fees
  3. Update ops/treasury.md with new balances
  4. When accumulated ETH > 0.005: buy OBSD on router (NOT Aerodrome)
  5. Tweet about the compound event
  6. Update analytics with fee-per-token data
```

## Loop 3: Social → Engage → Grow → Distribute
```
TRIGGER: Continuous during active hours
  1. Post 3-5 tweets per session from ops/content-strategy.md
  2. Check engagement (likes, replies, follows) via Twitter API
  3. Log what works in ops/analytics.md
  4. Adapt content style based on engagement data
  5. Every new token launch = coordinated tweet blast
```

## Loop 4: Research → Evaluate → Deploy → Repeat
```
TRIGGER: Scout finds new platform or trending narrative
  1. Scout writes findings to platform-playbook.md
  2. Nova evaluates: free? fee-sharing? accessible?
  3. If viable: deploy a token on new platform
  4. Feed results back to Loop 1
```

## Loop 5: Security → Monitor → Alert
```
TRIGGER: Any new deployment or weekly
  1. Shield scans new contracts via GoPlus API
  2. Results written to ops/security-audit.md
  3. If flagged: alert Thryx immediately, pause promotion
  4. Weekly full portfolio rescan
```

## File-Based Coordination Protocol
All agents read/write to shared ops/ files. This IS the coordination layer.
No message queues. No databases. Just markdown files that agents read as context.

| File | Who Writes | Who Reads | Purpose |
|------|-----------|-----------|---------|
| ops/deployed-tokens.md | Deployers | Everyone | Token registry |
| ops/treasury.md | Ledger/Atlas | Thryx, Sage | Financial state |
| ops/analytics.md | Sage/Pulse | Thryx, Blaze | Performance data |
| ops/security-audit.md | Shield | Thryx, Nova | Safety checks |
| ops/content-strategy.md | Blaze | Echo, Volt, Amp | What to post |
| ops/company-strategy.md | Sage/Thryx | Everyone | Strategic direction |
| platform-playbook.md | Scout/Nexus | Nova, Deployers | Platform intel |
| ops/workflow-examples.md | Thryx | All agents | How to execute tasks |

## Model Tiering (Cost Optimization)
- **Opus**: Thryx (CEO decisions), complex strategy
- **Sonnet**: VPs, deployers, Twitter agents (medium complexity)
- **Haiku**: Scout, Atlas, Pulse (data gathering, monitoring)

Estimated savings: 40-60% vs running everything on Opus.

## Key Principle
> The routing logic lives in these markdown files, not in code.
> Agents read context, decide what to do, act, and write results back.
> The files ARE the orchestration layer.
