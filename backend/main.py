"""Pawtfolio A2UI backend.

Minimal FastAPI app: permissive CORS for the web client on a forwarded port,
mounts the agent route at ``/pawtfolio``, runs uvicorn. Model defaults to
Featherless (Qwen3-Coder); flip to Gemini with ``A2UI_MODEL=gemini-2.5-pro``.
"""

from __future__ import annotations

import os
from pathlib import Path

import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from pawtfolio_agent import app as pawtfolio_app
from pawtfolio_tools import pet_info

app = FastAPI(title="Pawtfolio Backend")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(
    pawtfolio_app.router,
    prefix="/pawtfolio",
    tags=["Pawtfolio"],
)

# Serve static assets (Ella's photo) from the backend, so the app loads the
# image over HTTP instead of bundling it. e.g. GET /static/ella.jpg
app.mount(
    "/static",
    StaticFiles(directory=str(Path(__file__).parent / "assets")),
    name="static",
)


@app.get("/pet")
def pet() -> dict:
    """The pet identity token (name/species/breed/photo) for the frontend."""
    return pet_info()


def main() -> None:
    port = int(os.getenv("PORT", "8002"))
    model = os.getenv("A2UI_MODEL", "gemini-2.5-pro (default)")
    print(f"Pawtfolio backend on :{port}  (route: /pawtfolio/)  model={model}")
    uvicorn.run(app, host="0.0.0.0", port=port)


if __name__ == "__main__":
    main()
