"""
EverRise Token v5 — Optimized One-Way Bonding Curve
=====================================================
Back to v3's proven architecture with tuned parameters.

MODEL:
  - BUYS: constant product bonding curve (spot only rises)
  - SELLS: burn ALL tokens, pay from treasury at IV = real_eth / circulating
  - EVERYTHING happens inside buy()/sell() — no external functions needed
  - Creator ETH auto-sent on every swap. No claims, no pings. Just swap.

PARAMETERS TUNED FOR:
  - Smaller spot/IV gap (lower initial virtual ETH)
  - Faster IV growth (higher burn rate on buys)
  - Everyone profits with realistic volume (100+ trades/day)

Run: python math/model.py
"""

import math
import random
import json
from dataclasses import dataclass, field
from typing import List, Dict

# ============================================================
# CONFIGURATION — the TUNABLE CONSTANTS
# ============================================================

# These 3 configs will be tested. Best one wins.
CONFIGS = {
    "conservative": {
        "V_ETH": 1.0, "V_TOK": 1_000_000_000.0,
        "CREATOR_BPS": 100, "BURN_BPS": 300,
        "TAX_MAX": 2500, "TAX_MIN": 100,
        "DECAY_SEC": 30 * 86400,
    },
    "balanced": {
        "V_ETH": 0.5, "V_TOK": 1_000_000_000.0,
        "CREATOR_BPS": 100, "BURN_BPS": 500,
        "TAX_MAX": 3000, "TAX_MIN": 100,
        "DECAY_SEC": 14 * 86400,  # faster decay = friendlier to mid-term holders
    },
    "aggressive": {
        "V_ETH": 0.2, "V_TOK": 1_000_000_000.0,
        "CREATOR_BPS": 100, "BURN_BPS": 800,
        "TAX_MAX": 3500, "TAX_MIN": 100,
        "DECAY_SEC": 7 * 86400,  # 7 day decay
    },
}

MAX_BUY_ETH = 5.0
MAX_SELL_BPS = 2500  # 25% of balance per sell


# ============================================================
# STATE
# ============================================================

@dataclass
class Holder:
    address: str
    balance: float = 0.0
    last_buy_time: float = 0.0
    eth_spent: float = 0.0
    eth_received: float = 0.0


@dataclass
class State:
    v_eth: float = 0.0
    v_tok: float = 0.0
    real_eth: float = 0.0
    circulating: float = 0.0
    total_burned: float = 0.0
    creator_eth: float = 0.0
    buys: int = 0
    sells: int = 0
    volume: float = 0.0
    iv_hist: List[float] = field(default_factory=list)
    spot_hist: List[float] = field(default_factory=list)
    cfg: dict = field(default_factory=dict)

    @property
    def k(self): return self.v_eth * self.v_tok
    @property
    def spot(self): return self.v_eth / self.v_tok if self.v_tok > 0 else float('inf')
    @property
    def iv(self): return self.real_eth / self.circulating if self.circulating > 0 else 0.0

    def record(self):
        self.iv_hist.append(self.iv)
        self.spot_hist.append(self.spot)


def make_state(cfg_name: str) -> State:
    c = CONFIGS[cfg_name]
    s = State()
    s.v_eth = c["V_ETH"]
    s.v_tok = c["V_TOK"]
    s.cfg = c
    return s


def get_tax(hold_secs: float, cfg: dict) -> float:
    lam = math.log(cfg["TAX_MAX"] / cfg["TAX_MIN"]) / cfg["DECAY_SEC"]
    bps = cfg["TAX_MAX"] * math.exp(-lam * max(0, hold_secs))
    return max(bps, cfg["TAX_MIN"]) / 10000


# ============================================================
# BUY — through bonding curve. Everything in one atomic call.
# ============================================================

def buy(s: State, h: Holder, eth: float, t: float) -> dict:
    eth = min(max(eth, 0), MAX_BUY_ETH)
    if eth <= 0: return {"error": "No ETH"}

    iv_before = s.iv
    c = s.cfg

    # Creator fee — auto-sent in the swap, no separate claim
    fee = eth * c["CREATOR_BPS"] / 10000
    net = eth - fee

    # Tokens from curve
    new_v_eth = s.v_eth + net
    new_v_tok = s.k / new_v_eth
    tokens_out = s.v_tok - new_v_tok
    if tokens_out <= 0: return {"error": "No tokens"}

    # Burn on buy
    burn = tokens_out * c["BURN_BPS"] / 10000
    user_tokens = tokens_out - burn

    # Update state (all atomic — happens inside the swap)
    s.v_eth = new_v_eth
    s.v_tok = new_v_tok
    s.real_eth += net
    s.circulating += user_tokens
    s.total_burned += burn
    s.creator_eth += fee
    s.volume += eth
    s.buys += 1

    h.balance += user_tokens
    h.last_buy_time = t
    h.eth_spent += eth

    s.record()
    return {
        "type": "BUY", "eth": eth, "tokens": user_tokens, "burned": burn,
        "iv_before": iv_before, "iv_after": s.iv,
        "iv_ok": s.iv >= iv_before - 1e-18,
    }


# ============================================================
# SELL — burn tokens, pay from treasury at IV. All in one swap.
# ============================================================

def sell(s: State, h: Holder, tokens: float, t: float) -> dict:
    max_sell = h.balance * MAX_SELL_BPS / 10000
    tokens = min(tokens, max_sell, h.balance)
    if tokens <= 0 or s.circulating <= 0: return {"error": "Nothing"}

    iv_before = s.iv
    c = s.cfg

    # Tax
    tax = get_tax(t - h.last_buy_time, c)

    # Payout at IV minus tax — creator fee auto-deducted
    gross = tokens * s.iv
    after_tax = gross * (1 - tax)
    creator_fee = after_tax * c["CREATOR_BPS"] / 10000
    user_eth = after_tax - creator_fee

    if after_tax > s.real_eth:
        r = s.real_eth / after_tax if after_tax > 0 else 0
        after_tax *= r; creator_fee *= r; user_eth *= r

    # All happens atomically in the swap
    s.real_eth -= after_tax
    s.circulating -= tokens
    s.total_burned += tokens
    s.creator_eth += creator_fee
    s.volume += after_tax
    s.sells += 1

    h.balance -= tokens
    h.eth_received += user_eth

    s.record()
    return {
        "type": "SELL", "tokens": tokens, "tax": tax, "eth_out": user_eth,
        "iv_before": iv_before, "iv_after": s.iv,
        "iv_ok": s.iv >= iv_before - 1e-18,
    }


# ============================================================
# SIMULATIONS
# ============================================================

def run_config_test(cfg_name: str):
    """Run the full test suite for one config."""
    c = CONFIGS[cfg_name]
    print(f"\n{'='*70}")
    print(f"CONFIG: {cfg_name.upper()}")
    print(f"  V_ETH={c['V_ETH']}, BURN={c['BURN_BPS']}bps, TAX={c['TAX_MAX']}->{c['TAX_MIN']}bps, DECAY={c['DECAY_SEC']//86400}d")
    print(f"{'='*70}")

    results = {}

    # --- TEST 1: IV Invariant ---
    s = make_state(cfg_name)
    holders = [Holder(f"u{i}") for i in range(50)]
    bad = 0; t = 0.0
    for i in range(10_000):
        h = random.choice(holders)
        t += random.uniform(1, 21600)
        if h.balance > 0 and random.random() < 0.4:
            r = sell(s, h, h.balance * random.uniform(0.01, 0.10), t)
        else:
            r = buy(s, h, random.uniform(0.001, 2.0), t)
        if "error" not in r and not r["iv_ok"]:
            bad += 1
    results["iv_invariant"] = bad == 0
    print(f"\n  IV Invariant: {'PASS' if bad==0 else 'FAIL'} ({bad} violations)")
    print(f"    IV: {s.iv_hist[0]:.12f} -> {s.iv_hist[-1]:.12f} ({s.iv_hist[-1]/s.iv_hist[0]:.0f}x)")
    print(f"    Gap at end: {s.spot/s.iv:.1f}x")
    print(f"    Creator: {s.creator_eth:.2f} ETH from {s.volume:.0f} ETH vol")

    # --- TEST 2: Sniper profit ---
    all_sniper_ok = True
    for label, hold in [("5min",300),("1hr",3600),("1day",86400),("7day",604800),("30day",2592000)]:
        s2 = make_state(cfg_name)
        sniper = Holder("sniper")
        crowd = [Holder(f"c{i}") for i in range(20)]
        t2 = 0.0
        buy(s2, sniper, 0.1, t2)
        for cc in crowd:
            t2 += 30; buy(s2, cc, 0.5, t2)
        for cc in crowd[:8]:
            t2 += 120;
            if cc.balance > 0: sell(s2, cc, cc.balance * 0.05, t2)
        t2 = hold
        for _ in range(6):
            if sniper.balance > 0.01: sell(s2, sniper, sniper.balance, t2); t2 += 1
        profit = sniper.eth_received - sniper.eth_spent
        roi = (sniper.eth_received / sniper.eth_spent - 1) * 100
        tag = "+" if profit > 0 else ""
        if profit <= 0: all_sniper_ok = False
        print(f"  Sniper {label}: {tag}{roi:.0f}% ({tag}{profit:.4f} ETH)")
    results["sniper_profit"] = all_sniper_ok

    # --- TEST 3: Holder compounding ---
    s3 = make_state(cfg_name)
    diamond = Holder("diamond")
    traders = [Holder(f"t{i}") for i in range(30)]
    t3 = 0.0
    buy(s3, diamond, 1.0, t3)
    entry_iv = s3.iv
    for day in range(90):
        for _ in range(50):
            t3 += random.uniform(60, 1800)
            tr = random.choice(traders)
            if tr.balance > 0 and random.random() < 0.45:
                sell(s3, tr, tr.balance * random.uniform(0.02, 0.10), t3)
            else:
                buy(s3, tr, random.uniform(0.01, 0.5), t3)
    val = diamond.balance * s3.iv
    results["holder_90d"] = val > 1.0
    print(f"  Holder 90d: {val:.2f} ETH (1.0 in, {s3.iv/entry_iv:.0f}x IV) {'PASS' if val > 1.0 else 'FAIL'}")

    # --- TEST 4: Dump stress ---
    s4 = make_state(cfg_name)
    dumpers = [Holder(f"d{i}") for i in range(20)]
    t4 = 0.0
    for d in dumpers: t4 += 10; buy(s4, d, random.uniform(0.1, 1.0), t4)
    iv_peak = s4.iv; t4 += 300; dump_bad = 0
    for _ in range(50):
        for d in dumpers:
            if d.balance > 0.01:
                t4 += 30; r = sell(s4, d, d.balance, t4)
                if "error" not in r and not r["iv_ok"]: dump_bad += 1
    results["dump_stress"] = dump_bad == 0
    print(f"  Dump stress: {'PASS' if dump_bad==0 else 'FAIL'} (IV {s4.iv/iv_peak:.1f}x after full dump)")

    # --- TEST 5: Nobody loses (HIGH VOLUME) ---
    s5 = make_state(cfg_name)
    all_traders = [Holder(f"t{i}") for i in range(50)]
    t5 = 0.0

    # Staggered entry over 7 days
    for i, tr in enumerate(all_traders):
        t5 = i * 86400 * 7 / 50
        buy(s5, tr, random.uniform(0.05, 0.5), t5)

    # 90 days of HIGH volume (200 trades/day = realistic for a popular token)
    for day in range(90):
        for _ in range(200):
            t5 = (7 + day) * 86400 + random.uniform(0, 86400)
            tr = random.choice(all_traders)
            if tr.balance > 0 and random.random() < 0.35:
                sell(s5, tr, tr.balance * random.uniform(0.02, 0.08), t5)
            else:
                buy(s5, tr, random.uniform(0.01, 0.3), t5)

    winners = losers = 0
    worst = float('inf')
    for tr in all_traders:
        total_val = tr.eth_received + tr.balance * s5.iv
        pnl_pct = (total_val / tr.eth_spent - 1) * 100 if tr.eth_spent > 0 else 0
        worst = min(worst, pnl_pct)
        if total_val >= tr.eth_spent - 0.0001: winners += 1
        else: losers += 1

    results["nobody_loses"] = losers == 0
    gap = s5.spot / s5.iv if s5.iv > 0 else 0
    print(f"  Nobody loses: {winners}W/{losers}L (gap:{gap:.1f}x, vol:{s5.volume:.0f}E, worst:{worst:+.0f}%) {'PASS' if losers==0 else 'FAIL'}")

    # --- TEST 6: Creator earnings ---
    s6 = make_state(cfg_name)
    ct = [Holder(f"c{i}") for i in range(30)]
    t6 = 0.0
    for day in range(30):
        for _ in range(100):
            t6 += 864; tr = random.choice(ct)
            if tr.balance > 0 and random.random() < 0.4:
                sell(s6, tr, tr.balance * 0.05, t6)
            else:
                buy(s6, tr, 0.1, t6)
    daily_creator = s6.creator_eth / 30
    results["creator_earnings"] = s6.creator_eth > 0
    print(f"  Creator 30d @10E/day: {s6.creator_eth:.2f} ETH ({daily_creator:.3f}/day)")

    # Summary
    passed = sum(1 for v in results.values() if v)
    total = len(results)
    print(f"\n  SCORE: {passed}/{total}")
    return results, passed


def main():
    print("#" * 70)
    print("#  EverRise Token v5 — Parameter Optimization")
    print("#  Testing 3 configs to find the sweet spot")
    print("#" * 70)

    random.seed(42)

    all_results = {}
    scores = {}
    for name in CONFIGS:
        random.seed(42)  # same seed for fair comparison
        results, score = run_config_test(name)
        all_results[name] = results
        scores[name] = score

    # Final comparison
    print("\n" + "=" * 70)
    print("COMPARISON")
    print("=" * 70)
    header = f"  {'Test':<20}"
    for name in CONFIGS:
        header += f" {name:>14}"
    print(header)
    print("  " + "-" * 62)

    test_names = list(list(all_results.values())[0].keys())
    for test in test_names:
        row = f"  {test:<20}"
        for name in CONFIGS:
            v = all_results[name].get(test, False)
            row += f" {'PASS':>14}" if v else f" {'FAIL':>14}"
        print(row)

    print("  " + "-" * 62)
    row = f"  {'SCORE':<20}"
    for name in CONFIGS:
        row += f" {scores[name]:>12}/6"
    print(row)

    best = max(scores, key=scores.get)
    print(f"\n  WINNER: {best.upper()}")
    print("=" * 70)

    with open("math/results/simulation_results.json", "w") as f:
        json.dump({"model": "v5", "scores": scores, "winner": best,
                   "results": {k: {kk: vv for kk, vv in v.items()} for k, v in all_results.items()}},
                  f, indent=2)
    print("  Saved to math/results/simulation_results.json")


if __name__ == "__main__":
    main()
