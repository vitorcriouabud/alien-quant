#!/usr/bin/env python3
"""ALIEN GOAT5K virtual portfolio risk laboratory. NO MT5 API AND NO ORDERS.

Two INDEPENDENT model portfolios, one for STOP_M5 and one for STOP_M1_LOCAL.
Trades are only accepted from user-supplied candidate events with approved=true;
the program never creates a trade signal. All amounts are hypothetical.

Inputs (strict JSON Lines with offset-aware timestamps):
    quote:  {"type":"quote","ts":"2026-11-13T17:00:01-05:00",
             "symbol":"XAUUSD","bid":"4000.00","ask":"4000.10"}
    reset:  {"type":"reset","ts":"2026-11-13T17:00:01-05:00",
             "assumed":true}
    signal: {"type":"signal","ts":"2026-11-13T17:00:02-05:00",
             "model":"STOP_M5","id":"s1","symbol":"XAUUSD","side":"BUY",
             "volume":"0.01","contract_size":"100","stop":"3990",
             "approved":true}
    close:  {"type":"close","ts":"2026-11-13T17:04:00-05:00",
             "model":"STOP_M5","id":"s1"}

Run:
    python tools/goat_virtual_portfolio.py --events events.jsonl --out report.json
    python tools/goat_virtual_portfolio.py --audit-shadow ALIEN_GOAT5K_RISK_....zip

This is a deterministic scenario model; it is NOT broker execution, a live risk
guard, a compliance guarantee, or a replacement for Goat dashboard values.
"""
from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass, field
from datetime import datetime
from decimal import Decimal, InvalidOperation
import io
import json
from pathlib import Path
from typing import Any
from zipfile import ZipFile
from zoneinfo import ZoneInfo

D = lambda v: Decimal(str(v))
ZERO = D(0)
GOAT_TIMEZONE = ZoneInfo("America/New_York")
VALID_MODELS = ("STOP_M5", "STOP_M1_LOCAL")


def money(value: Decimal) -> str:
    return format(value.quantize(D("0.0001")), "f")


def ts(value: str) -> datetime:
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise ValueError("timestamp needs a UTC offset: " + value)
    return parsed


@dataclass(frozen=True)
class Settings:
    initial_usd: Decimal = D("5000")
    per_trade_pct: Decimal = D("0.25")
    floating_pct: Decimal = D("1")
    daily_pct: Decimal = D("4")
    total_pct: Decimal = D("10")
    floating_buffer_usd: Decimal = D("10")
    daily_buffer_usd: Decimal = D("15")
    static_buffer_usd: Decimal = D("15")
    fee_roundtrip_per_lot_usd: Decimal = D("5")
    point: Decimal = D("0.01")
    slippage_reserve_points_each_side: Decimal = D("10")
    maximum_quote_gap_seconds: int = 120

    @property
    def trade_cap(self) -> Decimal:
        return self.initial_usd * self.per_trade_pct / D(100)

    @property
    def floating_hard(self) -> Decimal:
        return self.initial_usd * self.floating_pct / D(100)

    @property
    def floating_guard(self) -> Decimal:
        return self.floating_hard - self.floating_buffer_usd

    @property
    def static_floor(self) -> Decimal:
        return self.initial_usd * (D(1) - self.total_pct / D(100))


@dataclass
class Position:
    position_id: str
    symbol: str
    side: str
    volume: Decimal
    contract_size: Decimal
    entry: Decimal
    stop: Decimal
    fee_paid: Decimal
    opened_at: datetime
    initial_risk_usd: Decimal
    target: Decimal | None = None

    def liquidation(self, quote: tuple[Decimal, Decimal]) -> Decimal:
        bid, ask = quote
        return bid if self.side == "BUY" else ask

    def floating(self, quote: tuple[Decimal, Decimal]) -> Decimal:
        exit_price = self.liquidation(quote)
        delta = exit_price - self.entry if self.side == "BUY" else self.entry - exit_price
        return delta * self.volume * self.contract_size


@dataclass
class VirtualPortfolio:
    name: str
    settings: Settings
    balance: Decimal = field(init=False)
    positions: dict[str, Position] = field(default_factory=dict)
    quotes: dict[str, tuple[Decimal, Decimal]] = field(default_factory=dict)
    quote_times: dict[str, datetime] = field(default_factory=dict)
    daily_reference: Decimal | None = None
    resets: int = 0
    assumed_resets: int = 0
    signals: int = 0
    opened: int = 0
    closed: int = 0
    max_positions: int = 0
    peak_negative_floating: Decimal = ZERO
    peak_reserved_worst_loss: Decimal = ZERO
    max_quote_gap: int = 0
    guard_hits: int = 0
    hard_breaches: set[str] = field(default_factory=set)
    permanently_locked: bool = False
    audit: list[dict[str, Any]] = field(default_factory=list)

    def __post_init__(self) -> None:
        self.balance = self.settings.initial_usd

    def quote_at(self, symbol: str) -> tuple[Decimal, Decimal]:
        if symbol not in self.quotes:
            raise ValueError("quote missing for symbol " + symbol)
        return self.quotes[symbol]

    def equity(self) -> Decimal:
        return self.balance + sum(
            (p.floating(self.quote_at(p.symbol)) for p in self.positions.values()),
            ZERO,
        )

    def negative_floating(self) -> Decimal:
        # Each losing open position counts; winning positions do not offset losers.
        return sum(
            (max(ZERO, -p.floating(self.quote_at(p.symbol))) for p in self.positions.values()),
            ZERO,
        )

    def worst_from_entry(self, p: Position) -> Decimal:
        # Conservative all-stop stress, not a prediction or a tradable fill.
        gross = abs(p.entry - p.stop) * p.volume * p.contract_size
        slip = (D(2) * self.settings.slippage_reserve_points_each_side
                * self.settings.point * p.volume * p.contract_size)
        return gross + slip + p.fee_paid

    def worst_combined(self) -> Decimal:
        return sum((self.worst_from_entry(p) for p in self.positions.values()), ZERO)

    def daily_floor(self) -> Decimal | None:
        if self.daily_reference is None:
            return None
        return self.daily_reference * (D(1) - self.settings.daily_pct / D(100))

    def _log(self, event: str, at: datetime, **fields: Any) -> None:
        self.audit.append({
            "timestamp": at.isoformat(), "model": self.name,
            "event": event, **{k: str(v) if isinstance(v, Decimal) else v
                               for k, v in fields.items()}
        })

    def reset(self, at: datetime, assumed: bool) -> None:
        ny = at.astimezone(GOAT_TIMEZONE)
        if ny.hour != 17 or ny.minute != 0:
            raise ValueError("reset event must be 17:00 New York civil time; "
                             "confirm Goat DST policy before live use")
        self.daily_reference = max(self.balance, self.equity())
        self.resets += 1
        self.assumed_resets += int(assumed)
        self._log("reset_assumed" if assumed else "reset_external",
                  at, reference=money(self.daily_reference),
                  floor=money(self.daily_floor()))

    def _check_equity_floors(self, at: datetime) -> None:
        eq = self.equity()
        daily = self.daily_floor()
        # Hard breach means a breached *simulated scenario*, not real Goat account.
        if eq <= self.settings.static_floor or self.balance <= self.settings.static_floor:
            if "static" not in self.hard_breaches:
                self._log("hard_static_breach", at, equity=money(eq))
            self.hard_breaches.add("static")
        if daily is not None and (eq <= daily or self.balance <= daily):
            if "daily" not in self.hard_breaches:
                self._log("hard_daily_breach", at, equity=money(eq))
            self.hard_breaches.add("daily")
        if self.hard_breaches:
            self.permanently_locked = True

    def quote(self, at: datetime, symbol: str, bid: Decimal, ask: Decimal) -> None:
        if bid <= ZERO or ask <= bid:
            raise ValueError("bid/ask invalid")
        prev = self.quote_times.get(symbol)
        if prev and at < prev:
            raise ValueError("quote timestamps must be nondecreasing")
        if prev:
            gap = int((at - prev).total_seconds())
            self.max_quote_gap = max(self.max_quote_gap, gap)
            if gap > self.settings.maximum_quote_gap_seconds and self.positions:
                self._log("quote_gap", at, symbol=symbol, seconds=gap)
        self.quotes[symbol] = (bid, ask)
        self.quote_times[symbol] = at

        floating = self.negative_floating()
        self.peak_negative_floating = max(self.peak_negative_floating, floating)
        if floating >= self.settings.floating_guard:
            self.guard_hits += 1
            self._log("floating_guard_hit", at, floating=money(floating))
        if floating >= self.settings.floating_hard:
            if "floating" not in self.hard_breaches:
                self._log("hard_floating_breach", at, floating=money(floating))
            self.hard_breaches.add("floating")
            self.permanently_locked = True
        self._check_equity_floors(at)

        # First observe possible breach at tick, THEN simulate stop/TP fill.
        # A gap can breach the rule before a virtual stop closes the position.
        for position_id, p in list(self.positions.items()):
            if p.symbol != symbol:
                continue
            liq = p.liquidation((bid, ask))
            stop_hit = (liq <= p.stop) if p.side == "BUY" else (liq >= p.stop)
            target_hit = p.target is not None and (
                (liq >= p.target) if p.side == "BUY" else (liq <= p.target))
            if stop_hit or target_hit:
                self.close(at, position_id, "stop" if stop_hit else "target")
        self._check_equity_floors(at)

    def signal(self, at: datetime, data: dict[str, Any]) -> None:
        self.signals += 1
        position_id = str(data["id"])
        symbol = str(data["symbol"])
        side = str(data["side"]).upper()
        if side not in ("BUY", "SELL"):
            raise ValueError("unsupported side " + side)
        if position_id in self.positions:
            raise ValueError("duplicate open position id " + position_id)
        if data.get("approved") is not True:
            self._log("reject_strategy", at, position_id=position_id)
            return
        if self.permanently_locked:
            self._log("reject_locked", at, position_id=position_id)
            return
        if self.daily_reference is None:
            self._log("reject_no_daily_reference", at, position_id=position_id)
            return
        q = self.quotes.get(symbol)
        if q is None:
            self._log("reject_no_quote", at, position_id=position_id)
            return
        quote_t = self.quote_times[symbol]
        if at < quote_t or (at - quote_t).total_seconds() > self.settings.maximum_quote_gap_seconds:
            self._log("reject_stale_quote", at, position_id=position_id)
            return

        volume = D(data["volume"])
        contract_size = D(data["contract_size"])
        stop = D(data["stop"])
        if volume <= ZERO or contract_size <= ZERO:
            raise ValueError("volume and contract size must be positive")
        entry = q[1] if side == "BUY" else q[0]
        valid_stop = stop < entry if side == "BUY" else stop > entry
        if not valid_stop:
            self._log("reject_stop_side", at, position_id=position_id)
            return
        fee = volume * self.settings.fee_roundtrip_per_lot_usd
        hypothetical = Position(
            position_id, symbol, side, volume, contract_size,
            entry, stop, fee, at, ZERO
        )
        risk = self.worst_from_entry(hypothetical)
        hypothetical.initial_risk_usd = risk
        existing_worst = self.worst_combined()
        projected_floating_worst = existing_worst + risk

        # Current equity includes all existing float. Stress from balance is
        # based on the entry-price to stop for every open position.
        projected_equity = self.balance - (
            sum((self.worst_from_entry(p) - p.fee_paid
                 for p in self.positions.values()), ZERO)
            + risk
        )
        daily_floor = self.daily_floor()
        reason = None
        if risk > self.settings.trade_cap:
            reason = "risk_per_trade"
        elif projected_floating_worst >= self.settings.floating_guard:
            reason = "combined_worst_stop_exposure"
        elif projected_equity <= self.settings.static_floor + self.settings.static_buffer_usd:
            reason = "static_floor"
        elif (daily_floor is not None and
              projected_equity <= daily_floor + self.settings.daily_buffer_usd):
            reason = "daily_floor"
        if reason:
            self._log("reject_risk_" + reason, at,
                      position_id=position_id, candidate_risk_usd=money(risk),
                      combined_risk_usd=money(projected_floating_worst),
                      projected_equity_usd=money(projected_equity))
            return

        self.balance -= fee  # Round-trip fee reserved up front (assumption).
        hypothetical.target = (
            entry + D(4) * abs(entry - stop) if side == "BUY"
            else entry - D(4) * abs(entry - stop)
        )
        self.positions[position_id] = hypothetical
        self.opened += 1
        self.max_positions = max(self.max_positions, len(self.positions))
        self.peak_reserved_worst_loss = max(
            self.peak_reserved_worst_loss, self.worst_combined())
        self._log("virtual_open", at, position_id=position_id,
                  entry=money(entry), stop=money(stop),
                  risk_usd=money(risk), current_open=len(self.positions))
        self._check_equity_floors(at)

    def close(self, at: datetime, position_id: str, reason: str) -> None:
        p = self.positions.get(position_id)
        if p is None:
            self._log("close_unknown_position", at, position_id=position_id)
            return
        quote = self.quote_at(p.symbol)
        pnl = p.floating(quote)
        self.balance += pnl
        del self.positions[position_id]
        self.closed += 1
        self._log("virtual_close_" + reason, at,
                  position_id=position_id, pnl_before_fee=money(pnl),
                  remaining=len(self.positions), balance=money(self.balance))

    def report(self) -> dict[str, Any]:
        return {
            "model": self.name,
            "initial_usd": money(self.settings.initial_usd),
            "end_balance_usd": money(self.balance),
            "end_equity_usd": money(self.equity()),
            "daily_reference_usd": (money(self.daily_reference)
                                    if self.daily_reference is not None else None),
            "daily_floor_usd": (money(self.daily_floor())
                                if self.daily_floor() is not None else None),
            "floating_hard_usd": money(self.settings.floating_hard),
            "floating_guard_usd": money(self.settings.floating_guard),
            "trade_cap_usd": money(self.settings.trade_cap),
            "signals_seen": self.signals,
            "virtual_opened": self.opened,
            "virtual_closed": self.closed,
            "still_open": len(self.positions),
            "max_simultaneous_positions": self.max_positions,
            "peak_negative_floating_usd": money(self.peak_negative_floating),
            "peak_reserved_stop_exposure_usd": money(self.peak_reserved_worst_loss),
            "floating_guard_tick_hits": self.guard_hits,
            "hard_breach_types": sorted(self.hard_breaches),
            "maximum_quote_gap_seconds": self.max_quote_gap,
            "daily_resets": self.resets,
            "daily_resets_with_assumed_snapshot": self.assumed_resets,
            "audit_events": self.audit,
        }


class TwinSimulation:
    def __init__(self, settings: Settings | None = None):
        self.settings = settings or Settings()
        self.portfolios = {
            model: VirtualPortfolio(model, self.settings)
            for model in VALID_MODELS
        }
        self.last_time: datetime | None = None

    def feed(self, event: dict[str, Any]) -> None:
        at = ts(event["ts"])
        if self.last_time is not None and at < self.last_time:
            raise ValueError("all events must be chronological")
        self.last_time = at
        kind = event["type"].lower()
        if kind == "quote":
            for p in self.portfolios.values():
                p.quote(at, event["symbol"], D(event["bid"]), D(event["ask"]))
        elif kind == "reset":
            for p in self.portfolios.values():
                p.reset(at, bool(event.get("assumed", True)))
        elif kind == "signal":
            model = str(event["model"])
            if model not in self.portfolios:
                raise ValueError("invalid model "+model)
            self.portfolios[model].signal(at, event)
        elif kind == "close":
            model = str(event["model"])
            if model not in self.portfolios:
                raise ValueError("invalid model "+model)
            self.portfolios[model].close(at, str(event["id"]), "manual_hypothetical")
        else:
            raise ValueError("unknown event type: "+kind)

    def report(self) -> dict[str, Any]:
        return {
            "schema": "ALIEN_GOAT5K_VIRTUAL_LEDGER_V1",
            "data_source": "USER_SUPPLIED_EVENT_TAPE",
            "simulated_broker_fills": False,
            "portfolio_ledgers_are_independent": True,
            "goat_1pct_floating_variant_assumed": True,
            "commission_roundtrip_per_lot_is_unverified": True,
            "daily_reset_5pm_new_york_is_an_assumption": True,
            "gating_is_not_a_guarantee_against_gaps_or_breaches": True,
            "models": {name: p.report() for name, p in self.portfolios.items()},
        }


def audit_shadow_zip(path: Path) -> dict[str, Any]:
    """Inspect previous OUTCOMES snapshots; explicitly DO NOT reconstruct PnL."""
    with ZipFile(path) as z:
        files = [name for name in z.namelist()
                 if name.upper().endswith("_OUTCOMES.CSV")]
        if len(files) != 1:
            raise ValueError("expected exactly one _OUTCOMES.csv")
        with z.open(files[0]) as f:
            reader = csv.DictReader(io.TextIOWrapper(f, encoding="cp1252"),
                                    delimiter=";")
            rows = list(reader)
    open_rows = [r for r in rows if r.get("state") == "OPEN"]
    def stat(model: str) -> dict[str, Any]:
        selected = [r for r in open_rows if r.get("stop_model") == model]
        return {
            "model": model,
            "candidate_count": len(selected),
            "strategy_filter_approved": sum(
                r.get("all_filters_ok") == "1" for r in selected),
            "goat_individual_gates_approved": sum(
                r.get("goat_all_gates_ok") == "1" for r in selected),
            "trades_opened_in_broker": 0,
            "portfolio_time_series_computable_from_this_csv": False,
        }
    return {
        "schema": "ALIEN_GOAT5K_SHADOW_AUDIT_V1",
        "source": path.name,
        "open_shadow_rows": len(open_rows),
        "no_pivot_rows": sum(r.get("state") == "SEM_PIVO_LOCAL" for r in rows),
        "independent_portfolio_simulation_executed": False,
        "reason": ("OPEN/outcome snapshots alone contain no complete bid/ask "
                   "tick tape. Cannot infer overlapping mark-to-market or "
                   "daily reference changes without inventing price paths."),
        "models": [stat(m) for m in VALID_MODELS],
        "next_required_data": "causal event tape with quotes, reset, approved signals",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--events", type=Path, help="strict chronological JSONL tape")
    group.add_argument("--audit-shadow", type=Path,
                       help="audit existing GOAT5K ZIP (does NOT reconstruct ticks)")
    parser.add_argument("--out", type=Path, help="save JSON")
    args = parser.parse_args()
    if args.audit_shadow:
        report = audit_shadow_zip(args.audit_shadow)
    else:
        simulation = TwinSimulation()
        with args.events.open(encoding="utf-8") as f:
            for line_no, line in enumerate(f, 1):
                if not line.strip() or line.lstrip().startswith("#"):
                    continue
                try:
                    simulation.feed(json.loads(line))
                except (KeyError, ValueError, InvalidOperation) as exc:
                    raise ValueError(f"invalid event at line {line_no}: {exc}") from exc
        report = simulation.report()
    result = json.dumps(report, indent=2, ensure_ascii=False)
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(result+"\n", encoding="utf-8")
    print(result)


if __name__ == "__main__":
    main()
