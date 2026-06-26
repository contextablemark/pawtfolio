"""The Pawtfolio A2UI agent: a generic LlmAgent + domain tools, wrapped by
ADKAgent's A2UI middleware. The Flutter client injects the component catalog;
this backend stays catalog-agnostic and just supplies the data + composition
rules.

Model: Gemini (gemini-2.5-pro) by DEFAULT, with a one-env-var flip to Featherless
(Qwen3-Coder-30B-A3B-Instruct) by setting A2UI_MODEL to a Featherless model slug.
"""

from __future__ import annotations

import os

from ag_ui_adk import ADKAgent, add_adk_fastapi_endpoint
from fastapi import FastAPI
from google.adk.agents import LlmAgent
from google.adk.models.lite_llm import LiteLlm

from pawtfolio_tools import TOOLS, prime_context

# Must equal the Flutter client's kPawtfolioCatalogId.
PAWTFOLIO_CATALOG_ID = "pawtfolio"

_FEATHERLESS_BASE_URL = "https://api.featherless.ai/v1"
# Default Featherless model when swapping off Gemini: a Qwen3-family, tool-tuned
# model that pairs well with this app's forced tool call. Override with any
# Featherless slug via A2UI_MODEL.
_DEFAULT_FEATHERLESS_MODEL = "Qwen/Qwen3-Coder-30B-A3B-Instruct"


def _featherless(model: str) -> LiteLlm:
    # Reach Featherless (and any OpenAI-compatible endpoint) through LiteLLM's
    # `openai/` provider + api_base. tool_choice="required" requests the tool
    # call explicitly (ADK natively translates only Gemini's forced-call mode).
    key = os.getenv("FEATHERLESS_AI_API_KEY")
    if not key:
        raise RuntimeError(
            f"FEATHERLESS_AI_API_KEY is required to run A2UI_MODEL={model!r}. "
            "Set it in backend/.env, or use the default Gemini model "
            "(unset A2UI_MODEL, with GOOGLE_API_KEY)."
        )
    kwargs = {
        "model": f"openai/{model}",
        "api_base": os.getenv("A2UI_FEATHERLESS_BASE", _FEATHERLESS_BASE_URL),
        "api_key": key,
        "tool_choice": "required",
    }
    if os.getenv("A2UI_DISABLE_THINKING"):
        kwargs["extra_body"] = {"chat_template_kwargs": {"enable_thinking": False}}
    return LiteLlm(**kwargs)


def _build_model():
    """Gemini by default; flip to Featherless by setting A2UI_MODEL to a
    Featherless model slug (e.g. Qwen/Qwen3-Coder-30B-A3B-Instruct)."""
    explicit = os.getenv("A2UI_MODEL")
    if not explicit or explicit.startswith("gemini"):
        return explicit or "gemini-2.5-pro"  # Gemini (needs GOOGLE_API_KEY).
    return _featherless(explicit)


# Terse + tool-action framed. Structured-output / "don't repeat output" wording
# makes Qwen emit XML tool calls the endpoint can't parse, so keep this minimal;
# the composition rules live in COMPOSITION_GUIDE (the render sub-agent's prompt).
SYSTEM_PROMPT = (
    "You are Ella's pet-finance advisor. Answer by calling tools, not in words. "
    "For any spending question, call generate_a2ui to render the answer "
    "(intent='create', or intent='update' with target_surface_id to change a "
    "prior surface). You may first call a data tool for a drill-down. Always "
    "call generate_a2ui. Keep any words to one short sentence."
)

# Rendered into the forced render_a2ui sub-agent's prompt. The exact data arrives
# separately as context (## headings) published by the tools / before-callback.
COMPOSITION_GUIDE = """
## Composing Pawtfolio surfaces

Use ONLY the component names and properties in the "Available Components" schema.
The surface is a flat array; the root MUST have id "root" and be a Column. Stack
cards vertically — never place cards side-by-side in a Row. Reference children by
id. The host sets catalogId — do not include it.

Use the EXACT numbers from the provided context (the "Ella spending data", and
any emergency-fund or insight data fetched for this question). Never invent or
recompute amounts.

Component selection — render ONLY what answers the question, nothing more:
- StatCard: one headline number (total, monthly average, net).
- DonutChart: category breakdown / proportions (segments from the data).
- BarChart: a monthly trend, or top merchants (bars from the data).
- ExpenseList: individual expense rows.
- BudgetMeter: the emergency fund. Include ONLY when the user asks about the
  emergency fund, savings, being ready for an emergency, or adds to the fund
  (call add_to_emergency_fund, then render the BudgetMeter — it celebrates
  automatically at 100%). Do NOT add it to surfaces about spending, categories,
  trends, merchants, or transactions.
- InsightAlert: include ONLY to flag a genuinely relevant unusual expense, and
  at most one. It is not part of every surface.

Compose just the components that answer the user's question. Do not append a
BudgetMeter or InsightAlert unless the question itself is about that.

## Example — "How much am I spending on Ella?"
components:
[
  {"id":"root","component":"Column","children":["total","donut"]},
  {"id":"total","component":"StatCard","label":"Total spent","value":"$5,172","icon":"savings","accent":"teal"},
  {"id":"donut","component":"DonutChart","title":"Where the money goes","centerLabel":"$5,172","segments":[{"label":"Veterinary","value":1593.5,"color":"magenta"},{"label":"Walker","value":1540,"color":"teal"},{"label":"Boarding Daycare","value":900,"color":"orange"}]}
]

## Example — "Break down food costs"
components:
[
  {"id":"root","component":"Column","children":["fdonut","flist"]},
  {"id":"fdonut","component":"DonutChart","title":"Food spending","segments":[{"label":"Kibble & Wet","value":316.9,"color":"teal"},{"label":"Treats","value":86.99,"color":"orange"}]},
  {"id":"flist","component":"ExpenseList","title":"Food expenses","rows":[{"merchant":"Chewy","category":"Food","date":"2026-06-07","amount":52.4,"icon":"food"}]}
]

## Example — "Am I ready for an emergency?" (the ONLY kind of query that shows a BudgetMeter)
components:
[
  {"id":"root","component":"Column","children":["fund"]},
  {"id":"fund","component":"BudgetMeter","title":"Ella's emergency fund","current":420,"target":1100,"caption":"$420 of $1,100 saved (38%)","riskFactors":["Recurring ear infections","Seasonal allergies","Annual dental cleanings"]}
]
"""

pawtfolio_agent = LlmAgent(
    model=_build_model(),
    name="pawtfolio",
    instruction=SYSTEM_PROMPT,
    tools=TOOLS,
    before_agent_callback=prime_context,
)

pawtfolio_adk = ADKAgent(
    adk_agent=pawtfolio_agent,
    app_name="pawtfolio",
    user_id="demo_user",
    session_timeout_seconds=3600,
    use_in_memory_services=True,
    a2ui={
        "default_catalog_id": PAWTFOLIO_CATALOG_ID,
        "guidelines": {"composition_guide": COMPOSITION_GUIDE},
    },
)

app = FastAPI(title="Pawtfolio A2UI Backend")
add_adk_fastapi_endpoint(app, pawtfolio_adk, path="/")
