# PLM PowerBuilder-to-FastAPI/React Migration Assessment

## Executive conclusion

The proposed stack is a good fit, with two qualifications:

1. Keep SQL Server for the first migration. The difficult part is recovering business behavior, not changing database engines. Revisit the database platform after functional parity and cutover.
2. Do not translate each PowerBuilder window or stored procedure one-for-one. The current application mixes UI state, authorization, ERP integration, calculations, reporting, scheduled refreshes, and CRUD. Rebuild around business capabilities and use cases.

Recommended shape: a modular monolith with React/TypeScript in one deployable frontend, FastAPI in one deployable backend, and feature-oriented modules inside each. Keep calculations and lifecycle rules in Python, transactional integrity and constraints in SQL Server, and use a small number of database views only for stable read projections.

The best first production slice is formula inquiry: search formulas, open one revision, and display its ingredient lines and calculated totals. It exercises the core identity/join problem, the API boundary, the React application, authorization, and read-side performance without risking writes. In parallel, build golden-master tests for dosage, weight, and cost calculations because those are the highest-risk rules in the supplied SQL.

## Scope and limits of this review

Reviewed:

- `plum_main.srw`: the main PowerBuilder window, 66 event handlers, navigation, direct SQL, ERP searches, formula-material selection, Excel import, refresh commands, and user administration.
- `plm_tables.sql`: 32 table definitions.
- `plm_storedprocs.sql`: 44 stored procedures, 34 of which are report procedures.
- `plm_sql_jobs.sql`: 6 daily SQL Agent jobs.

This is enough to identify the main architecture and data risks, but not enough to claim full application parity. The main window references PowerBuilder objects that were not supplied, including `header`, `Edit_Formula`, `allergen`, `solvent`, `regreq`, `property`, `extension`, `country`, `vendor`, selection windows, numerous DataWindows, and global functions such as `f_authorize`. Export those objects and all DataWindow SQL before estimating the complete rewrite.

## What the current system does

The supplied files reveal these business capabilities:

- Formula header and revision management.
- Formula ingredient-line editing, replacement, ordering, potency/overage entry, and costing.
- Formula status-based workflows such as Review, Development, Quote, Copy, Active, Archive/Inactive/Delete variants.
- Raw-material search by item, description, vendor, manufacturer, and category.
- Branch-specific material lookup, currently focused on branches 05 and 10, with partial code for 15 and 35.
- Material specifications: allergens, countries, extensions, properties, regulatory requirements, solvents, and vendor parts.
- JDE item, branch, inventory, vendor, cost-ledger, work-order, bill-of-material, and usage lookups.
- Excel formula import.
- User/group administration and role-dependent UI behavior.
- SSRS-style worksheets, weigh sheets, sign-off sheets, certification/regulatory reports, obsolete-material reports, and cost-history reports.
- Daily cache/history refreshes for material catalog, raw-material cost, ingredient cost, and formula totals.

## Major findings

### 1. Core formula identity is not enforced

`Formula_Header` and `Formula_Item` have no primary keys, unique constraints, or foreign keys. The application behaves as if a formula revision is identified by some combination of branch, parent, blend, revision number, and status. Most joins use exactly those five fields, but some searches also use customer or name. Before ORM mapping or writes, profile the production data and prove the actual uniqueness rule.

The new model should use stable surrogate identifiers:

- `formula.id`
- `formula_revision.id`, with `formula_id`, an exact revision value/sequence, status, and version metadata
- `formula_line.id`, with `formula_revision_id`, line number, and material identity

Retain the legacy business key as a unique constraint after duplicates are resolved. Do not put mutable status in a primary key.

### 2. Numeric types are unsafe for revisions, costs, and formulation math

The schema contains extensive `real`/`float` usage, including revision numbers, cost, potency, quantity, overage, and weights. The procedures compensate by repeatedly rounding revision numbers before comparing them. Binary floating-point is the wrong persistence type for these values.

Use SQL `decimal`/`numeric` and Python `Decimal`, with precision and scale chosen with business owners. Prefer an integer revision sequence plus a display label if revisions are identifiers rather than measurements.

### 3. The database has very weak integrity

Of 32 tables, only 12 have a primary key; there are no foreign keys and no explicit unique constraints in the supplied DDL. Several one-to-many specification tables have only surrogate primary keys and no uniqueness rule for their natural material/branch/detail key. This permits duplicates and orphaned formula lines.

Data profiling and constraint remediation must precede write cutover. SQLAlchemy models alone do not provide integrity when another process can write to the database.

### 4. “Formulation Assistant” is a denormalized cache, not a domain table

The assistant procedures join JDE item/branch data, cost ledgers, inventory, 12-month usage, PLM extensions, regulatory preference, vendors, and allergens; then they delete and refill branch-specific tables. That is a read model/cache.

It should become either:

- A live query through an ERP integration repository when performance and JDE availability are acceptable; or
- One branch-neutral snapshot table, such as `material_catalog_snapshot`, refreshed atomically and stamped with `source_updated_at` and `refreshed_at`.

Do not preserve separate `Formulation_Assistant`, `_BP05`, `_BP15`, and future branch tables. Branch is data, not schema.

### 5. Several defects should be treated as behavioral questions, not copied

- `Proc_Formulation_Assistant_BP35` deletes and inserts `Formulation_Assistant_BP15`. This is a high-risk copy/paste defect.
- `Proc_PLM_Cost_Update` updates formula lines by child item number only; it ignores branch, revision, formula, and status.
- Cost fallback tests use expressions such as `FutureCost IS NOT NULL OR FutureCost <> 0`; this accepts zero and is probably intended to use `AND` or a different priority rule.
- Certification reporting builds executable SQL from a user-selected column name.
- PowerBuilder builds multiple queries by concatenating UI text, creating injection and quoting risk.
- The main window connects with hard-coded server/login metadata and contains a user-specific privilege check for `JSTARK`.
- `Formulation_Group` is defined in PLM but the PowerBuilder administration code writes to `DW.dbo.Formulation_Group`.
- Full-table cache refreshes use delete-then-insert, allowing empty/partial reads if refresh fails or overlaps with users.
- Excel import commits formula lines one at a time before inserting the header, so a failed import can leave partial formulas.
- Inserts without column lists tightly couple PowerBuilder to historical column order and appear inconsistent with the supplied current DDL.

Every one of these needs a recorded decision in a parity ledger: preserve, correct, or retire.

### 6. Calculation logic is duplicated and inconsistent

Dosage, mg/unit, manufacturing overage, formula percentage, formula cost, batch quantity, mixing hours, and weighing minutes are repeated across core procedures and many reports. Unit handling differs by procedure; one includes `SKB`, `HUT`, `SAPU`, `AGU`, `SU`, `LU`, `DP`, and `PC`, while several report procedures only special-case `MCG`, `IU`, `GDU`, and `FCC`.

Create one pure-Python calculation module using `Decimal` and explicit unit conversion tables. Make it deterministic, side-effect free, and heavily characterized against production examples. Reports should consume its persisted/versioned result or call the same calculation service; they should not reimplement formulas.

### 7. Reporting contains major duplication

The six confidential report procedures and their quoting counterparts have approximately 92–98% token overlap. Dropdown procedures are also repeated for coating and non-coating variants.

Replace these with:

- Shared query services/read models.
- A small set of report DTOs.
- Templates or report definitions that control presentation and disclosure options such as cost/vendor visibility.
- Ordinary filter endpoints for status/customer/branch/blend/revision options.

Do not create one API endpoint, SQL view, or Python function per legacy report procedure unless the output contract is genuinely distinct.

### 8. Authorization is UI-driven and must move server-side

Current behavior hides or enables controls based on group globals and individual flags. That is not an authorization boundary. Use corporate SSO (for example, the organization's existing OIDC/AD provider), map claims/groups to application roles, and enforce permissions in FastAPI use cases. The React UI may reflect permissions for usability, but never be the enforcement point.

Suggested permissions are capability-based: `formula.read`, `formula.draft.write`, `formula.activate`, `material_spec.write`, `cost.read`, `vendor.read`, `report.confidential`, and `admin.users`.

## Common-view assessment

Views are useful here, but only for stable, reusable read semantics. They are not a substitute for the service layer and they do not make an expensive cross-database query cheap.

| Candidate | Recommendation | Purpose and boundary |
|---|---|---|
| `integration.vw_jde_item_branch_cost` | Yes | One row per branch/item. Centralize trimmed branch codes, description composition, UOMs, stock type, GL/category/tier, vendor id, and separate cost-ledger columns for 01/05/07/21. Do not bury the business choice of which cost wins unless finance approves one universal rule. |
| `integration.vw_jde_inventory_balance` | Yes, if live JDE reads perform acceptably | One row per branch/item with inventory summed across permitted locations and the excluded hold-status rule in one place. Keep it separate from the basic item view because aggregation has a different performance profile. |
| `reporting.vw_formula_revision_line` | Yes during legacy coexistence | Canonical header-to-line join with readable aliases. It removes repeated five-column joins from reports and provides a stable parity surface. Build it only after the legacy key is proven unique. |
| `reporting.vw_formula_summary` | Maybe | Pure aggregates such as line count and stored totals can be exposed here. Do not recalculate domain dosage/cost rules differently from Python. A summary table may be better if historical “as calculated” values matter. |
| Rolling 12-month usage | No as a general live view | The date-relative work-order aggregation is expensive and changes every day. Use a snapshot/read-model table or a narrowly scoped query with caching. |
| Unified material catalog | Snapshot, not a plain view, if it includes usage and inventory | Replace all branch-specific assistant tables with one atomically refreshed table keyed by branch/item. If live joins are fast and reliable, the API can compose the smaller integration views instead. |
| Dropdown/status/customer/blend/revision views | No | These are simple `SELECT DISTINCT` queries with filters. Expose filter-option endpoints or derive facets from search results. Views cannot accept parameters. |
| One view per SSRS report | No | This would preserve the existing duplication. Use shared report read models and template options. |
| Updatable CRUD views | No | Write through ORM-backed domain tables/use cases so validation, lifecycle rules, auditing, and authorization are explicit. |

If JDE is on another server rather than the same SQL Server instance, move the `integration.*` semantics into the JDE adapter or replicated staging tables. Do not make the application depend on distributed cross-server joins for every user request.

## Recommended target architecture

Use a modular monolith. Microservices would add deployment and consistency problems before the domain has been recovered.

```text
apps/
  api/
    src/plm/
      app.py
      shared/                 # config, DB sessions, auth, errors, telemetry
      integrations/jde/       # read-only ERP adapter and mappings
      formulas/               # router, schemas, use cases, repository, calculations
      materials/              # catalog and branch data
      specifications/         # allergen/regulatory/vendor/etc.
      reporting/              # report queries, DTOs, render/export jobs
      administration/         # role mappings and controlled reference data
      jobs/                    # CLI entry points for scheduled refresh/snapshots
    tests/
  web/
    src/
      app/                     # routing, providers, layout
      features/
        formulas/
        materials/
        specifications/
        reports/
        administration/
      shared/                  # generated API client, design system, utilities
```

Backend guidance:

- Keep SQLAlchemy persistence models separate from Pydantic API contracts.
- Use Alembic for every schema change.
- Prefer explicit repositories/query objects per use case; do not expose generic repositories to routers.
- Start with synchronous SQLAlchemy/ODBC unless measured concurrency requires async. It is simpler for a SQL Server-heavy transactional application.
- Use dependency-injected transactions at the use-case boundary.
- Use structured errors, request IDs, audit events, and health/readiness endpoints from the beginning.
- Run scheduled jobs as separate commands/processes, not inside the FastAPI web process, because multiple API replicas can execute in-process schedulers more than once.

Frontend guidance:

- Use React with TypeScript.
- Generate the typed API client/types from FastAPI's OpenAPI document to avoid hand-maintained DTO duplication.
- Use a server-state library for queries/cache and a form library for complex formula editing.
- Keep feature code together; avoid a global folder split into all components, all hooks, and all services.
- Represent formula editing as a draft with explicit save/validation feedback, not as dozens of UI globals.

## Recommended domain model

The exact names need a domain workshop, but this is a safer starting point:

- `Formula`: stable product/formulation identity.
- `FormulaRevision`: revision, workflow status, customer, branch, parent/blend identifiers, product attributes, notes, created/changed/activated metadata, and optimistic concurrency token.
- `FormulaLine`: ordered material, potency, potency unit, active amount, overage, vendor/cost snapshot, print flags, notes, and calculated results.
- `Material`: global ERP item identity and description.
- `MaterialBranch`: branch-specific ERP status, UOM, category, tier, vendor, availability, and source timestamps.
- `MaterialSpecification`: capability-specific typed tables or explicit entities for allergen, regulatory, solvent, country, property, extension, and vendor data.
- `CostSnapshot`: branch/item/cost-type/value/effective time/source, when history and reproducibility are required.
- `FormulaCalculation`: revision calculation version, inputs/hash, totals, validation errors, and calculated time.
- `AuditEvent`: actor, action, aggregate, before/after or structured changes, timestamp, and correlation id.

Avoid a generic entity-attribute-value table for all specifications unless requirements prove that fields are truly user-defined. The existing attributes have different types and rules and deserve typed models.

## API shape

Avoid “CRUD for every table” as the public API. CRUD is fine inside straightforward administration, but formula lifecycle actions deserve use-case endpoints.

Initial read slice:

- `GET /api/v1/formulas` with status, customer, branch, blend, name, revision, page, and sort filters.
- `GET /api/v1/formulas/{formula_id}/revisions/{revision_id}`.
- `GET /api/v1/formulas/{formula_id}/revisions/{revision_id}/lines` or include lines in the detail response.
- `GET /api/v1/formula-facets` for permitted status/customer/branch options, or return facets with search.
- `GET /api/v1/materials` with branch and catalog filters.
- `GET /api/v1/materials/{branch}/{item_number}`.

First write slice:

- `POST /api/v1/formulas/{formula_id}/revisions` to create a draft revision.
- `PATCH /api/v1/formula-revisions/{revision_id}` for editable draft header fields.
- `POST /api/v1/formula-revisions/{revision_id}/lines`.
- `PATCH /api/v1/formula-revisions/{revision_id}/lines/{line_id}`.
- `DELETE /api/v1/formula-revisions/{revision_id}/lines/{line_id}`.
- `POST /api/v1/formula-revisions/{revision_id}/lines:reorder`.
- `POST /api/v1/formula-revisions/{revision_id}:recalculate` if recalculation is intentionally explicit; otherwise recalculate transactionally on edits.
- `POST /api/v1/formula-revisions/{revision_id}:submit-review` and `:activate` for authorized transitions.

Use an idempotency key for imports and commands that users may retry. Use an ETag/version value for optimistic concurrency so one editor cannot silently overwrite another.

## Migration plan

### Phase 0: discovery and behavioral baseline

1. Export the full PowerBuilder application: all windows, DataWindows and their SQL/update rules, menus, global functions/variables, nonvisual objects, PBL object lists, and external dependencies.
2. Inventory every screen, report, job, role, table, and external system. Classify each as keep, change, or retire with a business owner.
3. Profile production data for duplicate formula keys, orphan lines, invalid statuses/units, nulls, whitespace variants, branch variants, and actual numeric ranges.
4. Capture representative golden-master formulas for every unit type and exceptional potency unit. Record current procedure/report outputs before changing rules.
5. Create a data dictionary translating cryptic columns such as `FH*`, `FM*`, `RR*`, and `EX*` into business terms.
6. Record defects and ambiguous behavior in a parity ledger rather than silently reproducing them.

Exit criteria: the team can identify a formula revision unambiguously, explain status transitions, and reproduce calculation examples with approved expected results.

### Phase 1: foundation and read-only formula vertical slice

1. Scaffold the monorepo, FastAPI app, React/TypeScript app, CI, formatting/linting, unit tests, integration tests, configuration, and secrets handling.
2. Add read-only database users/connections for PLM and JDE. Never use the legacy shared PowerBuilder credential.
3. Implement authentication and a minimal `formula.read` authorization policy.
4. Map legacy formula data through a repository/anti-corruption layer. Do not leak `FHMCU`/`FMRWNO` names into API contracts.
5. Implement formula search and formula revision detail, then the matching React list/detail screens.
6. Add query timing, structured logs, and parity tests comparing API results to known legacy queries.
7. Add only the first common views needed for stable reads, starting with canonical formula revision lines and JDE item/branch/cost.

Exit criteria: users can find and inspect formulas in the new UI with authorized, paginated, parity-verified results.

### Phase 2: calculation engine and material catalog

1. Implement a pure calculation engine with `Decimal`, explicit units, validation errors, and a calculation version.
2. Turn the golden-master formulas into unit/characterization tests. Resolve disagreements between procedures with business owners.
3. Implement the JDE adapter and branch-neutral material search.
4. Benchmark live item/cost/inventory queries. Choose live composition or an atomic snapshot based on measured latency and JDE availability.
5. Replace cost-priority magic with a named, tested finance policy.

Exit criteria: the new service can calculate representative formulas and search materials with approved parity and performance.

### Phase 3: formula draft editing

1. Add clean formula/revision/line tables or validated constraints to the chosen transitional schema.
2. Implement create-draft, edit header, add/update/delete/reorder/replace line, and recalculate use cases.
3. Make each save atomic: header, lines, calculation results, and audit events commit or roll back together.
4. Add optimistic concurrency and audit history.
5. Build the React draft editor with server-side validation and unsaved-change protection.
6. Replace Excel COM import with an upload-to-staging workflow: parse, validate all rows, preview errors, then commit once.

Exit criteria: a controlled user group can build a draft formula without PowerBuilder, and no partial formula can be committed.

### Phase 4: lifecycle, specifications, and authorization

1. Define an explicit formula revision state machine. Do not permit arbitrary status string edits.
2. Implement submit/review/approve/activate/archive actions with permission checks and audit events.
3. Migrate material specification capabilities one vertical slice at a time.
4. Replace the custom group table/user-specific checks with managed identity claims and application role mappings.
5. Decide which active revisions become immutable; corrections should normally create a new revision.

Exit criteria: lifecycle and specification writes are server-authorized, audited, and parity-tested.

### Phase 5: reports, exports, and scheduled workloads

1. Group the 34 report procedures by actual output contract; collapse confidential/quoting variants into shared query and presentation options.
2. Move report calculations to the common calculation/read-model layer.
3. Implement asynchronous generation only for genuinely slow documents; simple CSV/XLSX downloads can stream from request-scoped queries.
4. Replace SQL Agent procedure calls with observable Python job commands, while retaining SQL Agent as a transitional scheduler if operations prefers it.
5. Make snapshots idempotent and atomic through staging plus swap/upsert, with run history, row counts, duration, and failure alerts.
6. Define retention for daily cost/history tables and make reruns safe for the same business date.

Exit criteria: required reports match approved examples, and jobs can be rerun without duplicates, empty caches, or silent partial success.

### Phase 6: cutover and retirement

1. Cut over by business capability, with one source of truth per capability. Avoid long-lived dual writes.
2. Run read/result comparisons and a short controlled parallel period.
3. Reconcile row counts, formula totals, statuses, and audit events before each cutover.
4. Make the corresponding PowerBuilder capability read-only, then retire it after the rollback window.
5. Remove branch-specific caches, obsolete report procedures, PowerBuilder catalog tables, and ad hoc backup tables from the application schema only after retention/archive approval.

## First 30 working days

### Days 1–5

- Export the missing PowerBuilder objects and DataWindows.
- Interview R&D, purchasing, QA/regulatory, finance, production/report consumers, and application support.
- Produce the screen/use-case inventory, role matrix, data dictionary, and parity ledger.
- Select 20–30 representative formulas and reports as golden masters.

### Days 6–10

- Profile keys and data quality in production copies.
- Decide the formula aggregate key and revision representation.
- Scaffold API/web/CI/test infrastructure and secure configuration.
- Establish read-only PLM and JDE connectivity.

### Days 11–20

- Implement the canonical formula read repository/view, Pydantic contracts, paginated API, and integration tests.
- Build the React formula search/detail flow.
- Begin the pure calculation module and tests from captured examples.

### Days 21–30

- Pilot the formula inquiry slice with real users.
- Benchmark JDE material/cost/inventory queries and select live versus snapshot strategy.
- Finalize the clean formula revision schema and first write-slice design.
- Produce the cutover plan and estimate based on the now-complete object inventory.

## Testing strategy

- Unit tests for calculations, state transitions, authorization decisions, and field mappings.
- SQL Server integration tests for repositories, transactions, constraints, collations, and views.
- Contract tests generated from OpenAPI for the frontend client.
- Golden-master tests comparing selected formulas and reports to approved legacy outputs.
- Migration tests: source counts, rejected rows, duplicate resolution, referential checks, and rerun safety.
- End-to-end tests for search, draft editing, activation, specification editing, import, and report download.
- Performance tests for formula search, material search, formula detail, and batch refresh.

Do not use SQLite as the only repository test database; SQL Server-specific collation, numeric, cross-database, and query behavior matters here.

## Decisions to settle early

1. What exactly identifies a formula independently of a revision?
2. Are parent and blend both required, and can the same blend exist for multiple customers or names?
3. Which statuses exist, which transitions are legal, and who may perform them?
4. Which potency/unit rules are authoritative when current procedures disagree?
5. Is cost a live value, a snapshot at calculation/activation time, or both?
6. Must historical reports reproduce the cost and formula exactly as of their original date?
7. How fresh must JDE inventory and rolling usage be?
8. Which reports remain legally/operationally required, and which are duplicate presentation variants?
9. What is the coexistence window with PowerBuilder, and can capabilities be frozen one at a time for cutover?
10. Does the organization already have an identity provider and group model that should drive roles?

## Opinionated “do not do” list

- Do not generate generic CRUD endpoints directly from every legacy table.
- Do not put business rules in React.
- Do not make SQLAlchemy models double as public Pydantic contracts.
- Do not duplicate every stored procedure as a repository method.
- Do not create branch-specific tables, views, routers, or React screens.
- Do not replace stored procedures with untested ORM expressions merely to remove T-SQL; complex read SQL is still appropriate.
- Do not run a scheduler inside every FastAPI instance.
- Do not use floats for cost, potency, percentage, weight, or revision identifiers.
- Do not dual-write PowerBuilder and the new schema for an extended period.
- Do not attempt a database-engine migration, application rewrite, workflow redesign, and report-platform replacement in one cutover.
