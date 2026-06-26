"""Domain tools + context priming for the Pawtfolio agent.

Two jobs:

1. ``prime_context`` (a ``before_agent_callback``) loads Ella's expense data and,
   on EVERY turn, publishes pre-computed, chart-ready payloads into the AG-UI
   context list (``CONTEXT_STATE_KEY``). The A2UI render sub-agent reads that list
   via ``build_context_prompt`` (renders each as ``## {description}\\n{value}``), so
   the model places EXACT numbers rather than re-deriving them. This is what makes
   data accurate on a small open model (Qwen) — and makes the proactive "sizzle"
   reliable without depending on multi-tool chaining.

2. Eight ``FunctionTool``s give the agent query-specific drill-downs (and exercise
   agentic tool use, especially on Gemini). Each returns a chart-ready dict and
   also publishes it to the context list so the render sub-agent sees it verbatim.
"""

from __future__ import annotations

import json
from collections import defaultdict
from pathlib import Path
from typing import Any

from ag_ui_adk import CONTEXT_STATE_KEY
from google.adk.tools import ToolContext

# --- data ------------------------------------------------------------------

_DATA_PATH = Path(__file__).parent / "data" / "ella_expenses.json"
_DATA: dict[str, Any] | None = None

# Emergency-fund "saved so far" is a DEMO CONSTANT (not in the expense data).
_EMERGENCY_FUND_SAVED = 420.0
_BREED_RISK_MULTIPLIER = 1.4  # Malshi: dental + ears + seasonal allergies.

# Stable color + icon per category (keys understood by the Flutter catalog).
_CATEGORY_COLOR = {
    "veterinary": "magenta",
    "walker": "teal",
    "boarding_daycare": "orange",
    "grooming": "green",
    "food": "teal",
    "training": "orange",
    "supplies": "muted",
    "insurance": "muted",
}
_CATEGORY_ICON = {
    "veterinary": "health",
    "walker": "walker",
    "boarding_daycare": "paw",
    "grooming": "grooming",
    "food": "food",
    "training": "paw",
    "supplies": "toys",
    "insurance": "savings",
}
_PALETTE = ["teal", "orange", "magenta", "green", "muted"]
_MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep",
           "Oct", "Nov", "Dec"]


def _load() -> dict[str, Any]:
    global _DATA
    if _DATA is None:
        _DATA = json.loads(_DATA_PATH.read_text())
    return _DATA


def _expenses() -> list[dict[str, Any]]:
    return _load()["expenses"]


def _spend(category: str | None = None) -> list[dict[str, Any]]:
    """Positive-amount expenses (drops reimbursements), optionally filtered."""
    return [
        e
        for e in _expenses()
        if e["amount"] > 0 and (category is None or e["category"] == category)
    ]


def pet_info() -> dict[str, Any]:
    """The pet identity token served to the frontend (name owned by the backend,
    not hardcoded in the app)."""
    p = _load()["pet"]
    return {
        "name": p["name"],
        "species": p["species"],
        "breed": p["breed"],
        "photoUrl": "/static/pet.jpg",
    }


def _title(s: str) -> str:
    return s.replace("_", " ").title()


def _money(x: float) -> str:
    return f"${x:,.0f}" if x == int(x) else f"${x:,.2f}"


# --- analytics (all return chart-ready, exact-number payloads) --------------


def _by_category_segments(limit: int = 6) -> list[dict[str, Any]]:
    totals: dict[str, float] = defaultdict(float)
    for e in _spend():
        totals[e["category"]] += e["amount"]
    ranked = sorted(totals.items(), key=lambda kv: kv[1], reverse=True)
    segs: list[dict[str, Any]] = []
    for i, (cat, total) in enumerate(ranked[:limit]):
        segs.append({
            "label": _title(cat),
            "value": round(total, 2),
            "color": _CATEGORY_COLOR.get(cat, _PALETTE[i % len(_PALETTE)]),
        })
    tail = ranked[limit:]
    if tail:
        segs.append({
            "label": "Other",
            "value": round(sum(v for _, v in tail), 2),
            "color": "muted",
        })
    return segs


def _monthly_trend(category: str | None = None) -> list[dict[str, Any]]:
    totals: dict[str, float] = defaultdict(float)
    for e in _spend(category):
        month = int(e["date"][5:7])
        totals[month] += e["amount"]
    return [
        {"label": _MONTHS[m - 1], "value": round(totals[m], 2)}
        for m in sorted(totals)
    ]


def _top_merchants(limit: int = 5) -> list[dict[str, Any]]:
    totals: dict[str, float] = defaultdict(float)
    for e in _spend():
        totals[e["merchant"]] += e["amount"]
    ranked = sorted(totals.items(), key=lambda kv: kv[1], reverse=True)[:limit]
    return [{"label": m, "value": round(v, 2)} for m, v in ranked]


def _totals() -> dict[str, Any]:
    summary = _load()["summary"]
    gross = round(sum(e["amount"] for e in _spend()), 2)
    months = len({e["date"][:7] for e in _expenses()}) or 1
    return {
        "gross": gross,
        "net": summary.get("net_out_of_pocket", gross),
        "reimbursed": summary.get("insurance_reimbursements", 0),
        "monthly_avg": round(gross / months, 2),
        "count": len(_expenses()),
    }


def _emergency_fund() -> dict[str, Any]:
    vet_total = sum(e["amount"] for e in _spend("veterinary"))
    months = len({e["date"][:7] for e in _spend("veterinary")}) or 1
    vet_monthly = vet_total / months
    target = round(vet_monthly * _BREED_RISK_MULTIPLIER * 3 / 100) * 100
    target = max(target, 600)
    risks: list[str] = []
    notes = " ".join(e["notes"].lower() for e in _spend("veterinary"))
    if "ear" in notes:
        risks.append("Recurring ear infections")
    if "allerg" in notes or "cytopoint" in notes:
        risks.append("Seasonal allergies")
    if "dental" in notes:
        risks.append("Annual dental cleanings")
    return {
        "title": "Ella's emergency fund",
        "current": _EMERGENCY_FUND_SAVED,
        "target": float(target),
        "caption": (
            f"{_money(_EMERGENCY_FUND_SAVED)} of {_money(target)} saved "
            f"({round(_EMERGENCY_FUND_SAVED / target * 100)}%) — a 3-month "
            "vet buffer for a Malshi"
        ),
        "riskFactors": risks[:3],
    }


def _surprise() -> dict[str, Any] | None:
    """Largest unplanned vet expense (not routine/preventative/wellness)."""
    unplanned = [
        e
        for e in _spend("veterinary")
        if e["subcategory"]
        not in {"preventatives", "wellness_exam", "vaccination", "routine"}
    ]
    if not unplanned:
        return None
    top = max(unplanned, key=lambda e: e["amount"])
    if top["amount"] < 50:
        return None
    month = _MONTHS[int(top["date"][5:7]) - 1]
    return {
        "severity": "warning",
        "title": f"Unplanned vet cost: {_money(top['amount'])} in {month}",
        "message": (
            f"{top['notes']} This is exactly what an emergency fund is for — "
            "Ella's is below target."
        ),
    }


# --- context publishing -----------------------------------------------------


def _publish(state: Any, description: str, payload: Any) -> None:
    """Append a {description, value} entry to the AG-UI context list so the A2UI
    render sub-agent sees it verbatim under `## {description}`."""
    existing = list(state.get(CONTEXT_STATE_KEY) or [])
    existing.append({"description": description, "value": json.dumps(payload)})
    state[CONTEXT_STATE_KEY] = existing


def prime_context(callback_context: Any) -> None:
    """before_agent_callback: publish Ella's chart-ready data + the proactive
    sizzle on every turn, so the render is accurate and the alert is reliable
    regardless of which tools the model chooses to call."""
    state = callback_context.state
    overview = {
        "totals": _totals(),
        "by_category_segments": _by_category_segments(),
        "monthly_trend": _monthly_trend(),
        "top_merchants": _top_merchants(),
    }
    _publish(
        state,
        "Ella spending data (use these EXACT numbers; do not invent amounts)",
        overview,
    )
    _publish(
        state,
        "Emergency fund (render as a BudgetMeter; use these EXACT values)",
        _emergency_fund(),
    )
    surprise = _surprise()
    if surprise is not None:
        _publish(
            state,
            "Proactive insight (ALWAYS add this as an InsightAlert, severity "
            f"'{surprise['severity']}')",
            surprise,
        )


# --- tools (query-specific drill-downs; each publishes + returns) -----------


def get_spending_summary(tool_context: ToolContext) -> dict[str, Any]:
    """Ella's overall spending: totals plus a category breakdown. Use for "how
    much am I spending", "overview", or "where does the money go"."""
    payload = {
        "totals": _totals(),
        "by_category_segments": _by_category_segments(),
    }
    _publish(tool_context.state, "DonutChart segments for the breakdown", payload)
    return payload


def get_category_breakdown(category: str, tool_context: ToolContext) -> dict[str, Any]:
    """Drill into ONE category (e.g. 'food', 'veterinary', 'grooming',
    'walker', 'boarding_daycare', 'training', 'supplies'). Returns subcategory
    segments and the matching expense rows."""
    cat = category.strip().lower().replace(" ", "_")
    rows = _spend(cat)
    subtotals: dict[str, float] = defaultdict(float)
    for e in rows:
        subtotals[e["subcategory"]] += e["amount"]
    segments = [
        {"label": _title(s), "value": round(v, 2),
         "color": _PALETTE[i % len(_PALETTE)]}
        for i, (s, v) in enumerate(
            sorted(subtotals.items(), key=lambda kv: kv[1], reverse=True)
        )
    ]
    payload = {
        "category": _title(cat),
        "total": round(sum(subtotals.values()), 2),
        "segments": segments,
        "rows": _rows(rows),
    }
    _publish(tool_context.state, f"Breakdown for {_title(cat)}", payload)
    return payload


def get_spending_trend(tool_context: ToolContext, category: str = "") -> dict[str, Any]:
    """Monthly spending trend (Jan–Jun). Optionally for one category. Use for
    "trend", "over time", "month by month"."""
    cat = category.strip().lower().replace(" ", "_") or None
    bars = _monthly_trend(cat)
    payload = {"unit": "$", "bars": bars, "accent": "teal"}
    _publish(tool_context.state, "BarChart bars for the spending trend", payload)
    return payload


def get_top_merchants(tool_context: ToolContext, limit: int = 5) -> dict[str, Any]:
    """The merchants Ella's owner spends the most at. Use for "where", "top
    merchants", "biggest vendors"."""
    payload = {"bars": _top_merchants(limit), "accent": "orange"}
    _publish(tool_context.state, "BarChart bars for top merchants", payload)
    return payload


def list_expenses(
    tool_context: ToolContext,
    category: str = "",
    reimbursable_only: bool = False,
    limit: int = 10,
) -> dict[str, Any]:
    """Individual expense line items, most recent first. Use for "show me the
    transactions / bills / expenses"."""
    cat = category.strip().lower().replace(" ", "_") or None
    rows = _spend(cat)
    if reimbursable_only:
        rows = [e for e in rows if e.get("insurance_reimbursable")]
    rows = sorted(rows, key=lambda e: e["date"], reverse=True)[:limit]
    payload = {"title": "Recent expenses", "rows": _rows(rows)}
    _publish(tool_context.state, "ExpenseList rows", payload)
    return payload


def get_stat(tool_context: ToolContext, metric: str = "total") -> dict[str, Any]:
    """One headline KPI. metric: 'total', 'monthly_avg', 'net', 'reimbursed'."""
    t = _totals()
    label, value, accent = {
        "total": ("Total spent", _money(t["gross"]), "teal"),
        "monthly_avg": ("Avg / month", _money(t["monthly_avg"]), "orange"),
        "net": ("Net of insurance", _money(t["net"]), "green"),
        "reimbursed": ("Insurance reimbursed", _money(t["reimbursed"]), "green"),
    }.get(metric, ("Total spent", _money(t["gross"]), "teal"))
    payload = {"label": label, "value": value, "icon": "savings", "accent": accent}
    _publish(tool_context.state, f"StatCard: {label}", payload)
    return payload


def get_emergency_fund(tool_context: ToolContext) -> dict[str, Any]:
    """Ella's emergency-fund status (for a BudgetMeter). Breed-aware target."""
    payload = _emergency_fund()
    _publish(tool_context.state, "Emergency fund (BudgetMeter values)", payload)
    return payload


def detect_surprise_expense(tool_context: ToolContext) -> dict[str, Any]:
    """Scan for an unusual / unplanned expense to warn about (for an
    InsightAlert). Returns {"surprise": false} when nothing notable."""
    surprise = _surprise()
    if surprise is None:
        return {"surprise": False}
    _publish(tool_context.state, "Proactive insight (InsightAlert)", surprise)
    return {"surprise": True, **surprise}


def _rows(expenses: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [
        {
            "merchant": e["merchant"],
            "category": _title(e["category"]),
            "date": e["date"],
            "amount": round(e["amount"], 2),
            "icon": _CATEGORY_ICON.get(e["category"], "paw"),
            "reimbursable": bool(e.get("insurance_reimbursable")),
        }
        for e in expenses
    ]


# Exported for the agent's tool list.
TOOLS = [
    get_spending_summary,
    get_category_breakdown,
    get_spending_trend,
    get_top_merchants,
    list_expenses,
    get_stat,
    get_emergency_fund,
    detect_surprise_expense,
]
