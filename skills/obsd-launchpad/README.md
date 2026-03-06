# OBSD LaunchPad Skill

Deploy tokens on Base for free and earn OBSD on every swap. Built for AI agents.

## Install

Add to your Claude Code project:

```bash
# Copy the skill to your project
mkdir -p skills/obsd-launchpad
curl -o skills/obsd-launchpad/SKILL.md \
  https://raw.githubusercontent.com/lordbasilaiassistant-sudo/thryxagi/master/skills/obsd-launchpad/SKILL.md
```

Or reference in your CLAUDE.md:

```markdown
## Skills
- [OBSD LaunchPad](skills/obsd-launchpad/SKILL.md) — Deploy tokens on Base, earn OBSD
```

## What You Get

- Deploy ERC-20 tokens on Base mainnet (free, we pay gas)
- Earn 0.75% of every swap as OBSD (automatic, no claiming)
- Tokens have a rising IV floor backed by OBSD (cannot go to zero)
- Anti-rug by construction: zero creator tokens, locked LP, immutable contracts

## Requirements

- Foundry (`forge`, `cast`) for on-chain interactions
- A private key with access to the LaunchPad (or use the gasless GitHub Issue flow)
- Base mainnet RPC access (public: https://mainnet.base.org)

## Quick Start

```bash
# Deploy a token
TOKEN_NAME="Agent Token" TOKEN_SYMBOL="AGT" CREATOR_PAYOUT=0xYourWallet \
  forge script script/LaunchCreatorToken.s.sol --rpc-url https://mainnet.base.org --broadcast

# Check your OBSD earnings
cast call 0x291AaF4729BaB2528B08d8fE248272b208Ce84FF "balanceOf(address)" 0xYourWallet --rpc-url https://mainnet.base.org
```

## Links

- [LaunchPad on Basescan](https://basescan.org/address/0xFD8F5C2DAb7C5F2954ba43c0ae85BF94601C06C1)
- [OBSD Token](https://basescan.org/address/0x291AaF4729BaB2528B08d8fE248272b208Ce84FF)
- [GitHub](https://github.com/lordbasilaiassistant-sudo/thryxagi)

## License

MIT
