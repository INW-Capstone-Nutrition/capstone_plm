# Read-only PLM explorer handoff

The `/formulas`, `/materials`, and `/specifications` navigation entries open the same
read-only explorer. Each table has a selected-record form above a paged data grid.
Selecting a row advances through `formula → formula_header → formula_line →
mat.material → spec.item_spec`. The six spec child tabs show regulatory, allergen,
country, property, solvent, and vendor-part records for the selected spec revision.
The selected material also exposes paged read-only tabs for
`mat.formulation_assistant`, `mat.item_jde_original`, and `mat.formula_item_cost`.
Formula item cost has no branch key, so its tab matches item number across branches.

The line-to-material path uses `material_id` when present. Otherwise it looks up
the branch and item number; the UI shows an unlinked state when lookup fails.
If `item_spec_id` is present on the line, that revision stays selected during
the material-to-spec drill-down.
The `mat.material` key is unique on `(branch_code, item_number)`. Inactive linked
materials are still available through the detail/lookup GET endpoints even though
the normal material list excludes them.

The frontend fetches 50 rows per grid page through `limit` and `offset`. Every
grid header can sort ascending, descending, or return to its default order.
Each column has a search box: enter text and press Enter or leave the box to
apply it. Search is case-insensitive and contains-based. Multiple column boxes
combine with AND. The backend applies filters and sort before pagination, so
results cover the full table rather than only the visible 50 rows. List GET
endpoints accept `filters` as a JSON object encoded in the query string, plus
allowlisted `sort_by` and `sort_dir=asc|desc` parameters. Formula list responses
contain revision summaries; lines are fetched only after a header is selected.
The top form and every grid are read-only. No create, update, or delete controls
are exposed in this explorer. Existing write endpoints remain in the backend
for later work.

The PLM_DEV `spec.item_*` tables may be empty. The six child grids still show
their expected columns and an empty state. `mat.formulation_assistant` and
`mat.item_jde_original` remain snapshots and are not editable through the UI.
