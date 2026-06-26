# Pawtfolio A2UI backend — uv-managed FastAPI app.
# main.py binds 0.0.0.0:$PORT (Railway injects PORT), route at /pawtfolio/.
FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim

WORKDIR /app

# Install deps first for layer caching. uv.lock may be absent (gitignored), so
# don't require --frozen; resolve from pyproject.toml when the lock is missing.
COPY pyproject.toml ./
COPY uv.lock* ./
RUN uv sync --no-install-project --no-dev

# App code (package=false, so no project build step).
COPY . .

# Default for local `docker run`; Railway overrides PORT at runtime.
ENV PORT=8002
EXPOSE 8002

CMD ["uv", "run", "--no-dev", "python", "main.py"]
