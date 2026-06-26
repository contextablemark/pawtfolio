# Pawtfolio 🐾

An AI **pet-finance advisor** with **generative UI**. Ask about a dog's spending
and the agent replies with live charts and cards — not text. Built on Google's
[`genui`](https://pub.dev/packages/genui) SDK (A2UI v0.9), the
[AG-UI](https://docs.ag-ui.com) protocol, and a Python ADK + `ag-ui-adk` agent,
with **Gemini by default and a one-env-var swap to Featherless (Qwen3-Coder) or
other models**.

> See **[ARCHITECTURE.md](ARCHITECTURE.md)** for how it all fits together
> (transports, data flow, model selection, the design decisions).

## Prerequisites

- **Flutter** 3.44+ (Dart ≥ 3.12) — `flutter doctor`
- **[uv](https://docs.astral.sh/uv/)** (Python package manager) for the backend
- A **Google/Gemini** API key (default model) — optionally a **Featherless** key to run an open model

## 1. Backend

```bash
cd backend
cp .env.example .env      # then fill in keys (see below)
./run.sh                  # uv sync + serve on :8002, route /pawtfolio/
```

`.env`:

```bash
# Default model is Gemini (gemini-2.5-pro):
GOOGLE_API_KEY=your_google_key
# Optional — only needed to run on Featherless:
FEATHERLESS_AI_API_KEY=your_featherless_key
```

**Swap to Featherless** (or any OpenAI-compatible model):

```bash
A2UI_MODEL=Qwen/Qwen3-Coder-30B-A3B-Instruct ./run.sh   # needs FEATHERLESS_AI_API_KEY
```

Other overrides: `A2UI_MODEL=gemini-2.5-flash`, `A2UI_DISABLE_THINKING=1`
(for Featherless hybrid Qwen models), `PORT=8002`.

Smoke-test the backend is up: `curl -i http://localhost:8002/pawtfolio/`
should return **405** (it's POST-only), not a connection error.

## 2. Frontend (Flutter web)

```bash
flutter pub get
flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0 \
  --dart-define=AG_UI_BASE_URL=http://localhost:8002
```

Open the served URL. **In a dev container**, point `AG_UI_BASE_URL` at the
**host-forwarded** port for the backend's container `:8002` (check the VS Code
**Ports** panel — it may map to a different host port, e.g. `localhost:8003`),
and open the host-forwarded address for the web port.

> The web build uses `fetch_client` for SSE automatically; the backend's CORS is
> permissive. The endpoint path keeps its **trailing slash** (`/pawtfolio/`) to
> avoid a 307 that breaks the browser preflight.

## Try it

- "How much am I spending on Ella?" → total + category donut
- "Break down food costs" → subcategory donut + expense list
- "Show my spending trend" → monthly bar chart
- "Where does the money go most?" → top-merchant bar chart
- "Am I ready for an emergency?" → emergency-fund meter

Every answer also proactively surfaces an **InsightAlert** (an unplanned vet
cost) and the **emergency-fund BudgetMeter** — push the fund to 100% for a
🐾 confetti burst.

## What you customize

| File | What |
|---|---|
| [`lib/catalog/`](lib/catalog/) | The 6 generative components (StatCard, DonutChart, BarChart, ExpenseList, BudgetMeter, InsightAlert) |
| [`lib/catalog.dart`](lib/catalog.dart) | Catalog assembly + the catalog-id / schema-description contract |
| [`lib/theme.dart`](lib/theme.dart) | Palette → `ThemeData` (the only theming channel) |
| [`backend/pawtfolio_tools.py`](backend/pawtfolio_tools.py) | The 8 domain tools + the data-priming callback |
| [`backend/pawtfolio_agent.py`](backend/pawtfolio_agent.py) | Model selection, system prompt, composition guide |
| [`backend/data/ella_expenses.json`](backend/data/ella_expenses.json) | The sample pet's expense data |

## Project layout

```
pawtfolio/
  lib/
    catalog.dart  theme.dart  conversation.dart  home_page.dart  app.dart  main.dart
    catalog/      # 6 custom genui CatalogItems
    transport/    # AG-UI ↔ genui transport (AgUiTransport, adapter, platform http)
    widgets/      # message input, confetti overlay
  backend/
    pawtfolio_agent.py  pawtfolio_tools.py  main.py  run.sh  pyproject.toml
    data/ella_expenses.json
  ARCHITECTURE.md
```

## Troubleshooting

- **`TransportError 404 / connection refused`** — `AG_UI_BASE_URL` must point at
  the backend's *host-forwarded* port; confirm `/pawtfolio/` (trailing slash).
- **Empty surface / `CatalogItemNotFoundException`** — the client catalog id and
  backend `default_catalog_id` must both be `"pawtfolio"`.
- **Latency** depends on the model/provider; Gemini (default) renders in a few
  seconds, and the surface appears as soon as it's ready regardless.
- **Missing key** — Gemini needs `GOOGLE_API_KEY`; running on Featherless needs
  `FEATHERLESS_AI_API_KEY`.
