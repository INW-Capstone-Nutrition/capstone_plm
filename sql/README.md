# Current PLM_DEV data refresh

Run the SQL below against `PLM_DEV` in this order. The `PLM` production database
is read as a source only. These scripts contain no production writes. Take a
`PLM_DEV` backup before a full refresh because the target rows are replaced.

1. Apply the current Alembic schema through head. Its primary keys, foreign
   keys, and unique business keys must exist before loading data. Do not run
   the archived `008_harden_legacy_formula_tables.sql` against production.
2. `014_refresh_legacy_formula_snapshot.sql` copies `Formula_Header`,
   `Formula_Item`, and `Formulation_Assistant` from `PLM.dbo` into `PLM_DEV.dbo`.
3. `029_refresh_item_snapshots_from_plm.sql` copies the eight `Item_*` tables,
   including `Item_JDE_Original`, into `PLM_DEV.dbo`.
4. `032_snapshot_bp_assistants_to_plm_dev.sql` copies the BP05 and BP15 assistant
   tables into `PLM_DEV.dbo`.
5. Install `027_form_line_seed_procedure.sql`, then
   `028_form_formula_and_header_seed_procedure.sql`. Preview with
   `EXEC form.formula_and_header_seed @PreviewOnly=1;`, then execute
   `EXEC form.formula_and_header_seed;`. This clears formula children and
   headers, resets identities, and loads `form.formula`,
   `form.formula_header`, and `form.formula_line` in one transaction. Its
   exact five-column legacy header/line match is branch, parent, blend,
   status, and revision. It stops if nonlegacy formulas or reviewed issues
   would be overwritten.
6. `033_reseed_mat_material_from_assistants.sql` clears the `spec.item_*`,
   `mat.item_jde_original`, and `mat.formulation_assistant` children before
   rebuilding `mat.material` from the three assistant snapshots and Item-only
   keys. It stops if formula lines still reference material or item specs.
7. `034_seed_mat_formulation_assistant.sql` loads every assistant snapshot row
   into `mat.formulation_assistant`, retaining duplicates and source table.
8. `031_seed_item_spec_snapshots.sql` clears and resets the specification and
   JDE history targets, then loads `dbo.Item_*` into `spec.item_*` and
   `dbo.Item_JDE_Original` into `mat.item_jde_original`. It reconciles counts
   and stops if formula lines reference item specs.

The source composite keys are used for matching and crosswalks. The current ERD
uses stable `id` primary keys in the normalized tables, with foreign keys to
those IDs. `mat.material` also enforces `(branch_code, item_number)` uniqueness;
`mat.item_jde_original` enforces `(source_branch_code, source_item_number,
source_julian_date)` uniqueness; `spec.item_spec` enforces
`(material_id, revision)` uniqueness. The legacy formula five-column key is
not asserted as a target primary key because source duplicates exist.

The `archive/` folder contains superseded migrations, diagnostics, and view
experiments. Do not run those as part of this refresh.
