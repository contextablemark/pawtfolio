#!/usr/bin/env bash
# Run the Pawtfolio A2UI agent backend (ADK + ag-ui-adk) on :8002,
# serving the route /pawtfolio/.
#
#   ./run.sh            # uv sync + run on :8002
#   PORT=9000 ./run.sh  # override the port
#
# Model: Featherless (Qwen3-Coder) by default — set FEATHERLESS_AI_API_KEY in
# ./.env. Flip to Gemini with A2UI_MODEL=gemini-2.5-pro (+ GOOGLE_API_KEY).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
export PATH="$HOME/.local/bin:$PATH"

if [ -f .env ]; then
  set -a; . ./.env; set +a
fi

uv sync >/dev/null
export PORT="${PORT:-8002}"
exec uv run python main.py
