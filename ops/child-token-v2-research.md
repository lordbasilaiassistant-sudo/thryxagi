# Child Token V2 — Enhanced Tokenomics Research

> Nexus R&D | THRYXAGI Platform
> Goal: Every child token trade should maximally benefit the OBSD ecosystem.

## Current State

`ChildToken.sol` is 17 lines of plain ERC20. No burns, no fees, no mechanics. Tokens sit in Aerodrome pools paired with OBSD, but the only OBSD benefit comes from Aero LP fees and the ChildRouter's multi-hop routing.

**Problem:** Plain tokens have zero stickiness. No reason to hold. No compounding value. No ecosystem feedback loop beyond initial pool creation.

---

## Design Candidates

### 1. BURN ON TRANSFER (Recommended: Tier 1)

**Concept:** Every transfer burns X% of tokens. Supply deflates over time. Scarcity increases.

**OBSD Impact:** As child supply shrinks, the OBSD/Child price ratio shifts. Each OBSD buys fewer child tokens over time, making OBSD more valuable relative to the child ecosystem.

**Complexity:** LOW. Minimal gas overhead. Compatible with all DEX routers.

**Risks:** Transfer tax can break some DeFi composability (approvals, exact-amount transfers). Aerodrome handles fee-on-transfer tokens if pool is created correctly (volatile pool, not stable).

```solidity
contract BurnChildToken is ERC20 {
    uint256 public constant BURN_BPS = 200; // 2% burn on transfer

    constructor(string memory name_, string memory symbol_, uint256 supply_, address recipient_)
        ERC20(name_, symbol_)
    {
        _mint(recipient_, supply_);
    }

    function _update(address from, address to, uint256 value) internal override {
        // No burn on mint or burn operations
        if (from == address(0) || to == address(0)) {
            super._update(from, to, value);
            return;
        }

        uint256 burnAmount = (value * BURN_BPS) / 10000;
        uint256 sendAmount = value - burnAmount;

        // Burn portion
        super._update(from, address(0), burnAmount);
        // Transfer remainder
        super._update(from, to, sendAmount);
    }
}
```

**Verdict:** Ship it. Lowest complexity, highest reliability. Deflationary pressure is proven to drive speculation and holding behavior.

---

### 2. OBSD BUYBACK ON TRANSFER (Recommended: Tier 2)

**Concept:** Instead of burning child tokens, a % of each transfer is sold for OBSD on Aerodrome, and that OBSD is burned (or sent to treasury). Every child token trade directly buys OBSD.

**OBSD Impact:** MASSIVE. Every single child token transfer creates real OBSD buy pressure. This is the strongest flywheel mechanism.

**Complexity:** MEDIUM. Requires the token to hold a reference to the Aerodrome router and the OBSD/Child pool. The swap happens inside `_update()` — must handle reentrancy carefully.

**Risks:** Gas cost per transfer increases (~80-120k gas for the embedded swap). Could fail if pool has no liquidity. Must handle the "swap inside transfer" reentrancy edge case.

```solidity
contract OBSDBuybackChild is ERC20, ReentrancyGuard {
    uint256 public constant FEE_BPS = 300; // 3% fee on transfer
    uint256 public constant MIN_SWAP = 1000e18; // batch swaps to save gas

    address public immutable obsd;
    address public immutable aeroRouter;
    address public immutable aeroFactory;
    uint256 public pendingFees; // accumulated until MIN_SWAP threshold

    constructor(
        string memory name_, string memory symbol_, uint256 supply_,
        address recipient_, address _obsd, address _aeroRouter
    ) ERC20(name_, symbol_) {
        obsd = _obsd;
        aeroRouter = _aeroRouter;
        aeroFactory = IAeroRouter(_aeroRouter).defaultFactory();
        _mint(recipient_, supply_);
    }

    function _update(address from, address to, uint256 value) internal override {
        if (from == address(0) || to == address(0)) {
            super._update(from, to, value);
            return;
        }

        uint256 fee = (value * FEE_BPS) / 10000;
        uint256 send = value - fee;

        // Accumulate fees in contract
        super._update(from, address(this), fee);
        super._update(from, to, send);

        pendingFees += fee;

        // Batch swap when threshold hit (saves gas on small transfers)
        if (pendingFees >= MIN_SWAP) {
            _swapForOBSD();
        }
    }

    function _swapForOBSD() internal nonReentrant {
        uint256 amount = pendingFees;
        pendingFees = 0;

        IERC20(address(this)).approve(aeroRouter, amount);

        IAeroRouter.Route[] memory routes = new IAeroRouter.Route[](1);
        routes[0] = IAeroRouter.Route({
            from: address(this),
            to: obsd,
            stable: false,
            factory: aeroFactory
        });

        try IAeroRouter(aeroRouter).swapExactTokensForTokens(
            amount, 0, routes, address(0xdead), block.timestamp + 300
        ) {} catch {
            // If swap fails (no liquidity), just hold the tokens
            pendingFees = amount;
        }
    }

    // Manual trigger for accumulated fees
    function triggerBuyback() external {
        require(pendingFees >= MIN_SWAP, "Below threshold");
        _swapForOBSD();
    }
}
```

**Verdict:** Extremely powerful flywheel but adds complexity. The batch swap pattern (accumulate + threshold) is critical for gas efficiency. Recommend as V2 upgrade after burn-on-transfer is proven.

---

### 3. OBSD REFLECTION / REVENUE SHARING

**Concept:** Trading fees accumulate in OBSD and are distributed pro-rata to child token holders. Holding child tokens = earning OBSD yield.

**OBSD Impact:** HIGH. Creates OBSD demand (fees converted to OBSD) AND gives holders a reason to accumulate child tokens (yield). Sticky liquidity.

**Complexity:** HIGH. Reflection math (dividend distribution with O(1) claim) is well-understood but error-prone. Uses the "magnified dividends" pattern from dividend-paying tokens.

**Risks:** High gas per transfer due to reflection tracking. Complex claim mechanics. Users must understand the yield mechanism.

```solidity
contract ReflectionChild is ERC20 {
    // Magnified dividend tracking (per-token OBSD earned)
    uint256 internal constant MAGNITUDE = 2**128;

    address public immutable obsd;
    uint256 internal magnifiedOBSDPerShare;
    mapping(address => int256) internal magnifiedOBSDCorrections;
    mapping(address => uint256) internal withdrawnOBSD;

    // When OBSD is deposited as dividends:
    function _distributeOBSD(uint256 amount) internal {
        if (totalSupply() > 0) {
            magnifiedOBSDPerShare += (amount * MAGNITUDE) / totalSupply();
        }
    }

    // Claimable OBSD for a holder:
    function claimableOBSD(address account) public view returns (uint256) {
        uint256 accumulated = uint256(
            int256(magnifiedOBSDPerShare * balanceOf(account)) +
            magnifiedOBSDCorrections[account]
        ) / MAGNITUDE;
        return accumulated - withdrawnOBSD[account];
    }

    function claimOBSD() external {
        uint256 amount = claimableOBSD(msg.sender);
        if (amount > 0) {
            withdrawnOBSD[msg.sender] += amount;
            IERC20(obsd).transfer(msg.sender, amount);
        }
    }

    // Must update corrections on every transfer
    function _update(address from, address to, uint256 value) internal override {
        // ... fee logic, swap child->OBSD, call _distributeOBSD ...
        super._update(from, to, value);

        // Correction tracking
        int256 correction = int256(magnifiedOBSDPerShare * value);
        if (from != address(0)) magnifiedOBSDCorrections[from] += correction;
        if (to != address(0)) magnifiedOBSDCorrections[to] -= correction;
    }
}
```

**Verdict:** Compelling for marketing ("hold CHILD, earn OBSD") but complex to implement safely. Save for V3 or premium child tokens. Gas cost per transfer is high.

---

### 4. AUTO-COMPOUNDING LP

**Concept:** A portion of transfer fees automatically buys OBSD and adds to the Aerodrome OBSD/Child pool, deepening liquidity over time.

**OBSD Impact:** HIGH. Deepens OBSD pools, reduces slippage for larger trades, creates permanent OBSD liquidity that never leaves.

**Complexity:** HIGH. Requires splitting accumulated fees 50/50 (half stay as child tokens, half swap to OBSD), then adding both as LP. The LP tokens could be burned (permanent liquidity) or sent to treasury.

```
Flow: Transfer fee (child tokens) ->
  50% stays as child tokens
  50% swapped to OBSD via Aerodrome
  Both sides added as LP to Aero pool
  LP tokens burned to 0xdead (permanent, unruggable liquidity)
```

**Verdict:** Powerful but very gas-heavy. Best implemented as a separate "compounder" contract that anyone can trigger (like a keeper), not inside `_update()`. Recommend for V3.

---

### 5. GRADUATED MECHANICS (Recommended: Tier 3)

**Concept:** Child tokens start as plain ERC20 (current behavior). As trading volume or supply milestones are hit, new features unlock: burn-on-transfer at 10K OBSD volume, buyback at 50K, reflection at 100K.

**OBSD Impact:** MEDIUM initially, HIGH at scale. Creates natural progression and narrative ("we just unlocked level 2!"). Traders watch for milestone triggers.

**Complexity:** MEDIUM. The contract has the code for all features from day 1, but they're gated behind threshold checks. Similar to OBSD's tier system.

```solidity
contract GraduatedChild is ERC20 {
    uint256 public totalVolume; // cumulative OBSD volume through this token
    uint256 public constant BURN_THRESHOLD = 10_000e18;     // 10K OBSD volume
    uint256 public constant BUYBACK_THRESHOLD = 50_000e18;  // 50K OBSD volume
    uint256 public constant BURN_BPS = 200;
    uint256 public constant BUYBACK_BPS = 100;

    function currentLevel() public view returns (uint8) {
        if (totalVolume >= BUYBACK_THRESHOLD) return 2;
        if (totalVolume >= BURN_THRESHOLD) return 1;
        return 0;
    }

    function _update(address from, address to, uint256 value) internal override {
        if (from == address(0) || to == address(0)) {
            super._update(from, to, value);
            return;
        }

        uint8 level = currentLevel();

        if (level >= 1) {
            // Level 1: burn on transfer
            uint256 burn = (value * BURN_BPS) / 10000;
            super._update(from, address(0), burn);
            value -= burn;
        }

        if (level >= 2) {
            // Level 2: buyback (accumulate for batch swap)
            uint256 buyback = (value * BUYBACK_BPS) / 10000;
            super._update(from, address(this), buyback);
            value -= buyback;
        }

        super._update(from, to, value);
    }

    // Called by ChildRouter after each swap to track volume
    function recordVolume(uint256 obsdAmount) external {
        // Only callable by authorized router
        totalVolume += obsdAmount;
    }
}
```

**Verdict:** Great narrative engine. Creates FOMO ("only 5K OBSD to unlock burns!"). But requires ChildRouter to call `recordVolume()` after each swap, which adds a cross-contract call. Medium complexity, high marketing value.

---

### 6. TIME-LOCKED LP

**Concept:** LP tokens from pool seeding are locked for X days (30-90 days). Prevents rug pulls, signals commitment.

**OBSD Impact:** LOW directly, but HIGH for trust. Trust attracts more traders. More traders = more volume = more OBSD demand.

**Complexity:** LOW. Can be done at the factory level (send LP tokens to a timelock contract) without changing the child token at all.

```solidity
contract LPTimelock {
    struct Lock {
        address lpToken;
        address owner;
        uint256 amount;
        uint256 unlockTime;
    }

    Lock[] public locks;

    function lock(address lpToken, uint256 amount, uint256 duration) external {
        IERC20(lpToken).transferFrom(msg.sender, address(this), amount);
        locks.push(Lock({
            lpToken: lpToken,
            owner: msg.sender,
            amount: amount,
            unlockTime: block.timestamp + duration
        }));
    }

    function unlock(uint256 lockId) external {
        Lock storage l = locks[lockId];
        require(msg.sender == l.owner, "Not owner");
        require(block.timestamp >= l.unlockTime, "Still locked");
        IERC20(l.lpToken).transfer(l.owner, l.amount);
        l.amount = 0;
    }
}
```

**Verdict:** Ship immediately as a separate contract. Doesn't touch child token code at all. Pure trust signal. Can be added to OBSDPairFactory with one extra line.

---

## Recommended Implementation Order

| Priority | Feature | OBSD Impact | Complexity | Gas Cost | Ship Timeline |
|----------|---------|-------------|------------|----------|---------------|
| 1 | Burn on Transfer | Medium | Low | +5K gas/tx | Immediate |
| 2 | LP Timelock | Low (trust) | Low | N/A | Immediate |
| 3 | OBSD Buyback | Very High | Medium | +80K gas/tx | After burn proven |
| 4 | Graduated Mechanics | High | Medium | Variable | After buyback |
| 5 | OBSD Reflection | High | High | +30K gas/tx | V3 |
| 6 | Auto-Compounding LP | High | High | +150K gas/tx | V3 |

## Recommended V2 Architecture

Deploy a new `ChildTokenV2.sol` with burn-on-transfer, and update `OBSDPairFactory` to use it. Separately deploy `LPTimelock.sol` and have the factory auto-lock LP tokens for 30 days.

```
OBSDPairFactoryV2
  |-> deploys ChildTokenV2 (2% burn on transfer)
  |-> creates Aero pool
  |-> seeds liquidity
  |-> locks LP tokens in LPTimelock for 30 days
  |-> emits event with lock ID for verification
```

This gives us:
- Deflationary child tokens (burn) -- scarcity narrative
- Unruggable LP (timelock) -- trust signal for traders
- Zero additional gas for users (burn is inside transfer, timelock is one-time at launch)
- Full compatibility with ChildRouter (no changes needed)
- Full compatibility with Aerodrome (volatile pools handle fee-on-transfer)

## Factory Upgrade Path

The existing `OBSDPairFactory` at `0xb696F67394609A6C176Ade745721Fd81b1650776` deploys plain `ChildToken`. We have two options:

1. **Deploy new factory** (`OBSDPairFactoryV2`) that deploys `ChildTokenV2` + timelocks LP. Old tokens stay as-is.
2. **Make factory configurable** — add a `tokenTemplate` field so we can hot-swap between plain and enhanced child tokens.

Option 1 is simpler and recommended. Old plain tokens still work. New tokens get enhanced mechanics. No migration needed.

## Key Constraint: Aerodrome Fee-on-Transfer Compatibility

Aerodrome volatile pools DO support fee-on-transfer tokens. The router handles the delta between expected and received amounts. BUT:
- The pool must be `volatile` (not `stable`)
- `amountOutMin` calculations must account for the burn
- ChildRouter already uses `minChildOut` parameter — users set slippage to account for burn

No changes needed to ChildRouter for burn-on-transfer child tokens.

## Open Questions

1. Should burn rate be configurable per token, or fixed at 2% for all?
   - Recommendation: Fixed 2% for simplicity. Different rates add confusion.
2. Should LP timelock duration be configurable?
   - Recommendation: Fixed 30 days. Long enough for trust, short enough for flexibility.
3. Should we burn LP tokens permanently instead of timelocking?
   - Recommendation: Timelock, not burn. We want to reclaim LP after 30 days to rebalance or add more.
4. Should buyback OBSD be burned or sent to treasury?
   - Recommendation: Burned. "Every trade burns OBSD" is a stronger narrative than treasury accumulation.
