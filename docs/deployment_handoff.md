# Build and deployment handoff

This is the reproducible setup for the repository as of 2026-11-13. Run commands from the indicated directory. The committed lockfiles, rather than this prose, are the complete machine-readable version lists, including transitive dependencies and integrity information.

## What is in the repository

| Part | Source of direct dependencies | Complete resolved dependencies | Runtime |
| --- | --- | --- | --- |
| Backend | `backend/pyproject.toml` | `backend/uv.lock` | Python >=3.12; local `.venv` was Python 3.14.7 |
| Frontend | `frontend/package.json` | `frontend/package-lock.json` | Node >=20.19 or >=22.12 as required by locked Vite 8.3.1; local Node was 24.21.0, npm 11.19.0 |

The local uv executable was 0.12.12. That is a recorded development version, not a requirement declared in the repo. Backend project version and frontend package version are both 0.1.0.

### Backend direct dependencies

| Package | Declared requirement | Resolved in `uv.lock` | Role |
| --- | --- | --- | --- |
| alembic | ==1.20.0 | 1.20.0 | Database migrations |
| fastapi | ==0.141.1 | 0.141.1 | HTTP API |
| pydantic | ==2.13.5 | 2.13.5 | API validation |
| python-dotenv | >=1.2.4 | 1.2.4 | `.env` loading |
| python-multipart | >=0.0.20 | 0.0.32 | Form/multipart support |
| sqlalchemy | ==2.1.1 | 2.1.1 | ORM/database access |
| uvicorn[standard] | ==0.54.0 | 0.54.0 | ASGI server |
| httpx (optional `dev`) | >=0.28.1 | 0.28.1 | API test client |
| pytest (optional `dev`) | ==9.1.1 | 9.1.1 | Tests |
| ruff (optional `dev`) | >=0.15.0 | 0.16.10 | Linting |
| pyodbc (optional `sqlserver`) | >=5.3.0 | 5.3.0 | SQL Server driver bridge |

`hatchling>=1.28` is the build-system requirement in `pyproject.toml`; it is resolved in an isolated build environment and is not a normal runtime dependency. `uv.lock` also records transitive packages. Do not manually copy this table into a Dockerfile as installation pins.

### Frontend direct dependencies

All entries below are resolved versions from `package-lock.json`; the ranges in `package.json` remain the source of allowed updates. 
Runtime: 
`@radix-ui/react-slot` 1.3.3, 
`@tanstack/react-query` 5.104.0, 
`class-variance-authority` 0.7.1, 
`clsx` 2.1.1, `lucide-react` 0.548.0, 
`motion` 13.4.6, 
`react` 19.3.0, 
`react-dom` 19.3.0, 
`react-router-dom` 7.18.4, 
`tailwind-merge` 3.7.0.

Build/development: 
`@eslint/js` 9.39.5, 
`@tailwindcss/vite` 4.3.3, 
`@types/node` 24.19.0, 
`@types/react` 19.3.0, 
`@types/react-dom` 19.3.0, 
`@vitejs/plugin-react` 6.1.1, 
`eslint` 9.39.5, 
`eslint-plugin-react-hooks` 7.1.1, 
`eslint-plugin-react-refresh` 0.4.26, 
`globals` 16.5.0, `tailwindcss` 4.3.3, 
`typescript` 5.9.3, 
`typescript-eslint` 8.71.0, 
`vite` 8.3.1. 
The lockfile includes all transitive npm packages.

## Reproduce and run locally

Use two terminals. These commands are portable between PowerShell and POSIX shells except for `cd` path separators. uv creates/manages `backend/.venv`; no activation is required.

Backend terminal, from the repository root:

```sh
cd backend
uv sync --locked --extra dev --extra sqlserver
uv run --locked --extra dev --extra sqlserver alembic current
uv run --locked --extra dev --extra sqlserver uvicorn api.main:app --reload
```

These commands assume `backend/.env` points to the existing shared SQL Server database `PLM_DEV` through its `PLM_DB_*` settings, and that Microsoft ODBC Driver 18 is installed. Confirm the target database before starting the API. `alembic current` only reads its migration state; it does not apply migrations. Do not run `alembic upgrade head` as a routine startup step against this existing database. API: `http://localhost:8000`; interactive docs: `http://localhost:8000/docs`. Stop the development server with Ctrl+C.

If `PLM_DEV` **does not exist** in a new environment, create the database in SQL Server first (Alembic does not create the database itself). 
Configure `backend/.env` for that new database, 
then run `uv run --locked --extra dev --extra sqlserver alembic upgrade head` once to create the application schema. 
If the database exists but `alembic current` is empty or behind `uv run --locked --extra dev --extra sqlserver alembic heads`, inspect its schema and migration history before applying anything; do not assume it is empty. The API will not create tables automatically because `PLM_AUTO_CREATE_SCHEMA=false`.

Frontend terminal, from the repository root:

```sh
cd frontend
npm ci
npm run dev
```

Open `http://localhost:5173`. `npm ci` installs exactly from `package-lock.json`; `npm install` can update the lockfile. Vite proxies `/api` to `http://localhost:8000`, and frontend requests default to `/api/v1`. Keep the two processes running together for local development.

Quality/build commands:

```sh
cd backend
uv run --locked --extra dev --extra sqlserver ruff check api tests
uv run --locked --extra dev --extra sqlserver pytest -q

cd ../frontend
npm run lint
npm run build
```

The frontend build output is `frontend/dist/`. `npm run preview` serves that built output for a local check; it is not a production web server. The backend can be started without the dev extra using `uv sync --locked --extra sqlserver` and `uv run --locked --extra sqlserver uvicorn api.main:app --host 0.0.0.0 --port 8000`. Bind to `0.0.0.0` inside a container so port publishing can reach it. `--reload` is for local development only.

## Database and container wiring

The backend reads `backend/.env` automatically if present; the file is not committed. See `backend/.env.example`. Environment variables override its values. This handoff assumes that `.env` selects the shared `PLM_DEV` SQL Server database. The code falls back to local SQLite (`sqlite:///./plm_dev.db`) if no database settings are supplied; that fallback is not the shared database. Verify `PLM_DB_NAME=PLM_DEV` and the intended host before running. Do not copy a credential-filled `.env` into a Docker image; supply its settings through deployment secrets or environment variables.

For SQL Server, install the `sqlserver` extra (`uv sync --locked --extra sqlserver`, adding `--extra dev` for development), install Microsoft ODBC Driver 18 and its OS libraries in the container, and configure either `PLM_DATABASE_URL` or all of `PLM_DB_HOST`, `PLM_DB_NAME`, `PLM_DB_USER`, `PLM_DB_PASSWORD`. Remove `PLM_DATABASE_URL` when using separate fields because it takes precedence. Optional fields are `PLM_DB_PORT` (1433), `PLM_DB_DRIVER` (`ODBC Driver 18 for SQL Server`), `PLM_DB_ENCRYPT` (`yes`), and `PLM_DB_TRUST_SERVER_CERTIFICATE` (`yes`). Set `PLM_SEED_DEMO_DATA=false` for real data. Database startup performs `SELECT 1` by default; `PLM_CHECK_DATABASE_ON_STARTUP=false` disables that check. Keep `PLM_AUTO_CREATE_SCHEMA=false`. For later schema releases, review and apply new Alembic revisions deliberately as a separate deployment operation. See `sql/README.md` for the separate SQL Server snapshot/seed run order; those data scripts are not part of normal app startup.

For a production frontend container, run `npm ci` and `npm run build` in a Node build stage, then serve `dist/` with a static web server. Route `/api` to the backend service at the web-server/reverse-proxy layer, or set `VITE_API_URL` to a browser-reachable API base URL **at build time** (for example, `https://example.org/api/v1`). A container-only hostname will not work in browser JavaScript. If frontend and API use different origins, set `PLM_CORS_ORIGINS` to the frontend origin. The current Vite proxy targets `localhost:8000`; inside a frontend container, `localhost` means that container, so replace the proxy target for container development. The production static server also needs SPA fallback to `index.html` for client-side routes.

The repository currently has no Dockerfile or Compose file. Image tags, health checks, secrets, volume mounts, reverse proxy, and SQL Server networking remain deployment decisions. Build images from the committed lockfiles; do not copy `.venv`, `node_modules`, `.env`, or local database files into images.

## Why uv, and where pip appears

The backend's committed `uv.lock` is a cross-platform dependency resolution, and `uv sync --locked` installs from it while refusing to rewrite it. This gives the Docker author a repeatable dependency set and lets `uv run` execute the application in the managed environment without shell-specific activation. uv is the package/environment manager; **Uvicorn** is the server started by uv.

The root `README.md` documents an earlier conventional `python -m venv`, `pip install -e ".[dev]"`, and direct `uvicorn` workflow, including `pip install -e ".[dev,sqlserver]"`. Thus **pip is present in documented instructions**. The repo has only two commits and no command-execution log, so it does not establish whether pip was actually run during development. `pip install -e .` reads `pyproject.toml` but cannot consume `uv.lock`; it may resolve different transitive versions. If pip is mandatory in a deployment, export a pip-compatible requirements file with `uv export --locked --format requirements.txt -o requirements.txt`, then install with `pip install -r requirements.txt`. Treat that export as generated from `uv.lock`, not a second source of truth.

The backend command differs from a plain `python app.py` because FastAPI exposes an ASGI object named `app` in `backend/api/main.py`; Uvicorn loads it via `api.main:app`. Run it from `backend` so Python can import the `api` package and load `backend/.env`. The frontend commands are conventional npm/Vite commands. Its development server and backend are separate processes because Vite handles React/TypeScript hot reload and proxies API requests while Uvicorn serves Python routes.

## Recorded commands versus reconstruction

The repository records command *instructions* for virtualenv, pip installation, Alembic migration and inspection, Uvicorn startup, npm installation/dev/build/lint, and backend pytest/Ruff in the root `README.md`. The current `pyproject.toml`, `package.json`, lockfiles, and code support the uv/npm commands above. No shell history or build transcript is committed, so a complete chronological list of every command originally typed to create the project cannot be verified. Use the reproduction commands here as the executable handoff, and consult Git history for code changes.
