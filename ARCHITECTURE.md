# Pawtfolio — Architecture

Pawtfolio is an AI **pet-finance advisor** that answers questions about a dog's
spending by rendering **live charts and cards** (generative UI) instead of plain
text. Ask *"How much am I spending on Ella?"* and the agent composes a surface —
a total, a donut breakdown, a proactive alert, an emergency-fund meter — that is
rendered as **native Flutter widgets**.

## The stack

| Layer | Tech |
|---|---|
| UI rendering | Google's **`genui`** SDK (Flutter) — renders **A2UI v0.9** |
| Client↔agent transport | **AG-UI** protocol over HTTP + SSE, via the **`ag_ui`** Dart SDK |
| Agent backend | Python **ADK** (`google-adk`) + **`ag-ui-adk`** middleware |
| Model | **Gemini** (`gemini-2.5-pro`) by default · **Featherless** (`Qwen3-Coder-30B-A3B-Instruct`) via one env var |

The model **is not** wired into the Flutter app — it lives inside the ADK agent.
The frontend only speaks AG-UI.

```
┌──────────────────── BROWSER ────────────────────┐
│ Flutter web app                                  │
│  HomePage → GenUiSession → Conversation (genui)  │
│     ├── SurfaceController  → renders A2UI         │
│     └── AgUiTransport      → talks AG-UI          │
└───────────────────────┬──────────────────────────┘
              ① AG-UI: HTTP POST + SSE  (fetch_client on web)
                        ▼
┌──────────────── BACKEND :8002 ───────────────────┐
│ FastAPI + ag-ui-adk                              │
│  LlmAgent(+ 8 domain tools)                       │
│    └─ ADKAgent(a2ui=…) auto-injects generate_a2ui │
│         └─ forced render_a2ui sub-agent           │
│              → {a2ui_operations:[…]}              │
│  model = LiteLlm(Qwen3-Coder)  |  gemini-2.5-pro  │
└───────────────────────┬──────────────────────────┘
              ② LLM: litellm → OpenAI-compatible HTTP
                        ▼
              api.featherless.ai/v1   (or Gemini)
```

## The transports (four stacked layers)

1. **genui `Transport`** — the in-app seam. A 4-member interface
   (`incomingText`, `incomingMessages`, `sendRequest`, `dispose`). We implement
   [`AgUiTransport`](lib/transport/ag_ui_transport.dart); genui's
   `Conversation` / `SurfaceController` / `Surface` run unchanged on top of it.
2. **AG-UI protocol** — client ↔ agent server. HTTP **POST** of a
   `RunAgentInput` (messages, context, forwardedProps) → an **SSE** stream of
   typed events (`RUN_STARTED`, `TEXT_MESSAGE_*`, `TOOL_CALL_*`,
   `TOOL_CALL_RESULT`, `RUN_FINISHED/ERROR`). Spoken by the `ag_ui` Dart SDK's
   `AgUiClient`.
3. **Platform HTTP client** — what physically streams the SSE bytes. On **web**,
   `fetch_client` (Fetch API / ReadableStream); the default `BrowserClient`
   (XHR) cannot read a held-open SSE body. On native, the `dart:io` client.
   Conditional-import split in
   [`platform_http_client.dart`](lib/transport/platform_http_client.dart).
4. **LLM transport** — agent ↔ model. ADK's `LiteLlm` → litellm →
   OpenAI-compatible HTTP to Featherless `/v1` (or Gemini).

**A2UI** is the *payload*, not a transport: v0.9 operations
(`createSurface` / `updateComponents` / …) carried as the JSON `content` of a
`TOOL_CALL_RESULT`. [`a2ui_operations_adapter.dart`](lib/transport/a2ui_operations_adapter.dart)
parses them into genui `A2uiMessage`s.

## How a turn flows

1. User types a question. `AgUiTransport.sendRequest` POSTs it, **injecting the
   GenUI catalog** (`Catalog.toCapabilitiesJson()`) as a `context` entry plus
   `forwardedProps:{injectA2UITool:true}`.
2. `ag-ui-adk` sees the flag and auto-injects a `generate_a2ui` tool onto the
   agent. The agent (optionally) calls domain tools, then calls `generate_a2ui`.
3. A **forced `render_a2ui` sub-agent** composes the A2UI surface from the
   injected catalog + the data in context, and returns `{a2ui_operations:[…]}`.
4. The transport parses that into `A2uiMessage`s → `SurfaceController` →
   `Surface` renders native widgets. It **stops at the first surface** (skipping
   the model's trailing text) so the UI appears fast.
5. Button taps / interactions flow back through genui's
   `controller.onSubmit → Conversation → transport.sendRequest` (re-running the
   agent) — for free.

## Data accuracy (the key backend idea)

A small open model must not have to re-derive dollar figures. So the backend
**pre-computes exact, chart-ready payloads** and publishes them where the render
sub-agent will read them verbatim:

- [`pawtfolio_tools.py`](backend/pawtfolio_tools.py) appends
  `{description, value}` entries to `tool_context.state[CONTEXT_STATE_KEY]`
  (`"_ag_ui_context"`). `ag-ui-adk`'s `build_context_prompt` renders each as
  `## {description}\n{value}` in the sub-agent prompt.
- A `before_agent_callback` (`prime_context`) publishes the spending overview,
  the emergency-fund values, and the **proactive surprise** on *every* turn — so
  the "sizzle" (an unprompted `InsightAlert` + `BudgetMeter`) is reliable even
  when the model under-chains tools.
- The eight `FunctionTool`s give the agent query-specific drill-downs (and
  exercise agentic tool use, especially on Gemini); each also publishes its
  chart-ready result.

The composition guide instructs the render sub-agent to use **only** the exact
numbers from these context sections.

## The component catalog (client-owned)

The agent is generic; the **client** defines the vocabulary. The 6 custom
components live in [`lib/catalog/`](lib/catalog/) as genui `CatalogItem`s
(`dataSchema` + `widgetBuilder`), combined with genui's basic layout/text
components in [`catalog.dart`](lib/catalog.dart):

`StatCard` · `DonutChart` (fl_chart) · `BarChart` (fl_chart) · `ExpenseList` ·
`BudgetMeter` (3-zone meter, fires client-side confetti at 100%) · `InsightAlert`.

Theming: genui does **not** apply the A2UI `theme` block, so the palette
(teal/orange/magenta/green/cream, from the mockup) is applied as Flutter
`ThemeData` in [`theme.dart`](lib/theme.dart); widgets read
`Theme.of(context)`. Confetti is purely client-side (no backend event).

## Model selection — Gemini default, Featherless flip

`_build_model()` in [`pawtfolio_agent.py`](backend/pawtfolio_agent.py):

- **Default:** Gemini `gemini-2.5-pro` (needs `GOOGLE_API_KEY`) — a strong fit
  for the data-accurate, multi-tool rendering this app does.
- **Swap models** with one env var: set `A2UI_MODEL` to any Gemini model, or to
  a Featherless slug (e.g. `Qwen/Qwen3-Coder-30B-A3B-Instruct`, with
  `FEATHERLESS_AI_API_KEY`) to run on an open model. Featherless — and any
  OpenAI-compatible endpoint — is reached through litellm's `openai/` provider
  with `tool_choice="required"`; choose a model that supports tool calling
  (Qwen3-Coder is a good default there).
- The **system prompt is kept terse and tool-action-framed** for broad model
  compatibility; the composition rules live in the render sub-agent's guide, not
  the parent prompt.

## The contract (keep these in lockstep)

1. **Catalog id** — client `kPawtfolioCatalogId` == backend
   `PAWTFOLIO_CATALOG_ID` == `"pawtfolio"`.
2. **Schema-context description** — client `kA2uiSchemaContextDescription` is
   **byte-identical** to `ag-ui-adk`'s `A2UI_SCHEMA_CONTEXT_DESCRIPTION` (routes
   the catalog into the sub-agent prompt).
3. **Endpoint path** — client `kA2uiEndpointPath = "pawtfolio/"` (trailing slash
   avoids a 307 that breaks CORS) == backend mount prefix `/pawtfolio`.

## Tradeoffs / known limits

- **Latency:** Gemini renders in a few seconds; latency on other providers
  varies with the model and endpoint. Either way the break-on-first-surface
  transport shows the surface as soon as it's ready (any trailing model text is
  skipped client-side).
- **No HIL:** the spec's `BillSplitForm` human-in-the-loop is intentionally out
  of scope for this build.
- **`$420` emergency-fund "saved"** is a demo constant (not in the data).
