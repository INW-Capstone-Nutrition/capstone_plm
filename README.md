# Foundry PLM migration starter

For reproducible setup, locked package versions, container considerations, and a record of pip versus uv usage, see the [build and deployment handoff](docs/deployment_handoff.md).

A working FastAPI + React starter mapped from the supplied PowerBuilder migration assessment. The project separates the frontend and backend while keeping the domain in a deployable modular monolith.

## What is included

- Operational dashboard with PowerBuilder-inspired navigation for formulas, materials, specifications, reports, and user administration.
- Responsive React 19 + TypeScript interface using Tailwind CSS 4, shadcn-style primitives, Lucide icons, TanStack Query, and Motion.
- FastAPI service with Pydantic request/response contracts and SQLAlchemy 2 models.
- Normalized schema for formulas, revisions, lines, branch-aware materials, specifications, users, and audit events.
- SQLite development defaults with seeded demonstration data; SQL Server can be selected through `PLM_DATABASE_URL`.
- Alembic migration support, API tests, linting, and production frontend builds.

## Backend architecture

The backend is a modular monolith. Each business capability owns its API contracts,
SQLAlchemy entities, relationships, queries, and routes:

```text
backend/
├── api/                           # Importable Python application package
│   ├── main.py                    # Application composition root
│   ├── config.py
│   ├── database.py                # Engine, session, shared ORM base
│   ├── modules/
│   │   ├── formulas/
│   │   │   ├── models.py          # Formula ORM entities and relationships
│   │   │   ├── schemas.py         # Formula request/response contracts
│   │   │   ├── repository.py      # Formula reads
│   │   │   └── router.py          # Formula use cases/endpoints
│   │   ├── materials/
│   │   ├── specifications/
│   │   ├── admin/
│   │   ├── dashboard/
│   │   ├── audit/
│   │   └── system/
│   └── seed.py
├── alembic/                       # Generated/reviewed database migration history
│   ├── env.py
│   └── versions/
├── tests/
├── alembic.ini
└── pyproject.toml
```

The importable package is `backend/api`. From the `backend` directory, Python
imports it as `api`.

The current modules are intentionally small. Keep a module's four basic files together
until one use case becomes substantial. At that point, move that use case into a named
feature package inside the module rather than adding more global layers.

## Run locally

### Backend

```powershell
cd backend
uv sync --locked --extra dev --extra sqlserver
uv run --locked --extra dev --extra sqlserver alembic current
uv run --locked --extra dev --extra sqlserver uvicorn api.main:app --reload
```

These commands use the existing `PLM_DEV` SQL Server database configured in
`backend/.env`. `uv sync` creates `.venv` and installs the locked packages; no
manual activation or pip install is needed. `alembic current` reads migration
state without modifying the database. Run `alembic upgrade head` only as a
deliberate schema deployment, or when setting up a new, empty database. See the
[build and deployment handoff](docs/deployment_handoff.md) for that procedure.

The API is available at `http://localhost:8000`, with OpenAPI documentation at `http://localhost:8000/docs`.

### Frontend

```powershell
cd frontend
npm ci
npm run dev
```

Open `http://localhost:5173`. Vite proxies `/api` to the backend.

## Database configuration

The local `backend/.env` selects the existing `PLM_DEV` SQL Server database.
The `sqlserver` uv extra installs `pyodbc`; the machine also needs Microsoft
ODBC Driver 18. Without database settings, the code falls back to
`sqlite:///./plm_dev.db`. Copy `backend/.env.example` only when configuring a
new environment, then set the target database details explicitly.

The API performs a read-only `SELECT 1` during startup so invalid SQL Server networking or credentials fail immediately. Database schema changes are applied deliberately with Alembic. Automatic `create_all()` behavior is disabled by default.

For passwords containing URL-reserved characters, prefer the separate `PLM_DB_HOST`, `PLM_DB_NAME`, `PLM_DB_USER`, and quoted `PLM_DB_PASSWORD` fields shown in `.env.example`. SQLAlchemy constructs the URL safely, so the raw password does not need manual percent encoding.

The current `sql/` scripts form the PLM-to-PLM_DEV snapshot and normalized seed
path. See [`sql/README.md`](sql/README.md) for the run order. Older coexistence
and read-view scripts are retained in `sql/archive/`. The ORM uses stable
surrogate primary keys and composite source-key constraints.

## Code-first database workflow

SQLAlchemy models under `api/modules/*/models.py` are the source of truth for entities,
columns, indexes, constraints, and relationships. Alembic is the Python/SQLAlchemy
equivalent of EF Core migrations: it compares those models with the current database and
creates a versioned migration describing the difference.

SQL Server should still enforce the resulting primary keys, foreign keys, unique
constraints, and column types. Those objects are authored in Python and applied through
migrations rather than maintained manually in SQL Server.

From the `backend` directory. Generate and test new migrations against an
isolated development database before applying them to shared `PLM_DEV`:

```powershell
# Inspect the existing database's migration revision (read only)
uv run --locked --extra dev --extra sqlserver alembic current

# After changing a module's models.py, generate a migration
# (EF Core: Add-Migration <name>)
uv run --locked --extra dev --extra sqlserver alembic revision --autogenerate -m "describe the model change"

# Review the generated file under alembic/versions, then apply it deliberately
uv run --locked --extra dev --extra sqlserver alembic upgrade head

# Confirm the database matches the code model
uv run --locked --extra dev --extra sqlserver alembic check

# Inspect migration state and history
uv run --locked --extra dev --extra sqlserver alembic heads
uv run --locked --extra dev --extra sqlserver alembic history

# Roll back one migration only in an isolated development database
uv run --locked --extra dev --extra sqlserver alembic downgrade -1
```

For a new environment, create the SQL Server database first, configure
`PLM_DATABASE_URL` or the `PLM_DB_*` settings, keep
`PLM_AUTO_CREATE_SCHEMA=false`, then run `alembic upgrade head` to create the
application schema. Do not run that command routinely against the existing
`PLM_DEV` database. See the handoff for the full procedure.

The current ERD and source mappings are indexed in
[`docs/README.md`](docs/README.md). Historical view plans and diagnostics are
available under `docs/archive/`.

## Verification

```powershell
cd backend
uv run --locked --extra dev --extra sqlserver ruff check api tests
uv run --locked --extra dev --extra sqlserver pytest -q

cd ..\frontend
npm run lint
npm run build
```

## Next delivery slices

1. Point read repositories at the canonical legacy views and add golden-master parity tests.
2. Add the versioned `Decimal` calculation engine for dosage, weight, overage, and cost.
3. Replace development user stubs with corporate OIDC and server-enforced permissions.
4. Add staged Excel import with full-file validation and one atomic commit.
5. Implement revision workflow commands and optimistic concurrency.
