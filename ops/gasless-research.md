# Gasless Meta-Transaction Research

## Goal
Allow creators to submit a token launch request via web form with zero gas cost to them. We (THRYXAGI) pay gas on their behalf.

---

## Option A: GitHub Issues as Queue (RECOMMENDED)

**How it works:**
1. Creator fills out a form on our GitHub Pages site
2. Form submits a GitHub Issue via the GitHub API (public repos allow unauthenticated issue creation with a token, or we use a lightweight proxy)
3. A GitHub Action watches for new issues with a `launch-request` label
4. The Action runs `forge script` with our deployer key (stored as a GitHub Secret)
5. Action comments back on the issue with the deployed token address and tx hash

**Pros:**
- Zero infrastructure cost (GitHub Actions free tier: 2,000 min/month)
- Audit trail built-in (every request is a public issue)
- No backend server to maintain
- Form validation happens client-side before submission
- Deployer key stays in GitHub Secrets (never exposed)

**Cons:**
- GitHub Actions cold start: ~30-60s before the job even starts
- Total latency: 1-3 minutes from form submit to deployed token
- Requires a GitHub token for issue creation (can use a fine-grained PAT with issues-only scope)
- Rate limited to ~500 workflow runs/day on free tier

**Implementation sketch:**
```yaml
# .github/workflows/launch-token.yml
name: Launch Token
on:
  issues:
    types: [opened]

jobs:
  launch:
    if: contains(github.event.issue.labels.*.name, 'launch-request')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Parse request
        run: |
          # Extract name, symbol, initial params from issue body (structured YAML/JSON)
          echo "Parsing issue #${{ github.event.issue.number }}"
      - name: Install Foundry
        uses: foundry-rs/foundry-toolchain@v1
      - name: Deploy token
        env:
          PRIVATE_KEY: ${{ secrets.THRYXTREASURY_PRIVATE_KEY }}
          RPC_URL: https://mainnet.base.org
        run: |
          forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast
      - name: Comment result
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: 'Token deployed! Address: 0x...'
            })
```

---

## Option B: Cloudflare Worker Endpoint

**How it works:**
1. Creator submits form to a Cloudflare Worker endpoint
2. Worker validates input, stores request in KV or D1
3. A cron trigger (or our agent) polls for pending requests
4. Agent runs `forge script` locally to deploy, updates request status

**Pros:**
- Sub-second response to the creator ("request received")
- Cloudflare Workers free tier: 100K requests/day
- Can add rate limiting, CAPTCHA, etc.

**Cons:**
- More infrastructure to maintain (Worker + KV/D1 + polling agent)
- Deployer key must live somewhere the agent can access it (not in CF)
- Still needs our local machine or a server to run `forge script`
- More complex than Option A for equivalent result

---

## Option C: EIP-2771 / Gelato Relay

**How it works:**
1. Creator signs a meta-transaction (gasless signature)
2. We forward it to a Trusted Forwarder contract via Gelato Relay (or OpenZeppelin Defender)
3. The forwarder calls our LaunchPad contract with the creator's address as `_msgSender()`

**Pros:**
- True gasless UX — creator signs, we relay
- Industry standard (EIP-2771)
- Gelato has Base support

**Cons:**
- Requires modifying LaunchPad contract to inherit ERC2771Context
- Gelato Relay costs: ~$0.01-0.05 per relay on L2, but requires 1Balance deposit
- More complex contract surface area (trust assumptions around forwarder)
- Overkill for our current scale — we're deploying tokens, not doing high-frequency relaying
- Gelato 1Balance minimum deposit may exceed our current treasury

---

## Recommendation: Option A (GitHub Issues Queue)

**Why:**
1. **Zero cost** — no infrastructure spend, no relay deposits
2. **Simplest to build** — a GitHub Action YAML + a form page
3. **Transparent** — every launch request is a public issue (builds trust)
4. **Secure** — deployer key stays in GitHub Secrets, never touches client
5. **Good enough latency** — 1-3 min is acceptable for a token launch
6. **Scales to our needs** — 500 deploys/day is way beyond current demand

**Migration path:** If we outgrow GitHub Actions (unlikely soon), we can move to Option B (Cloudflare Worker) without changing the creator-facing form — just swap the form's submit endpoint.

**Next steps:**
1. Create the issue template with structured fields (name, symbol, supply, creator wallet)
2. Build the GitHub Action workflow
3. Add a form to the GitHub Pages site that creates issues via GitHub API
4. Test end-to-end with a dummy deploy
