# PLM view inventory and procedure/job traceability

The view layer is intentionally divided into write-facing base views and read-only
projections. It maps the current application without adding constraints, indexes, or
new persistence rules.

For the feature-by-feature ownership and application wiring map, see
[`vertical_slice_view_map.md`](vertical_slice_view_map.md).

For the newer `form` / `mat` / `quality` / `audit` / `dash` / `specs` schema
organization, see [`feature_schema_view_plan.md`](feature_schema_view_plan.md).

## CRUD base contracts

All `[app]` views select from exactly one table, expose every base column, and apply
aliases only. This keeps them eligible for ordinary SQL Server view DML while the API
layer supplies validation, authorization, lifecycle rules, auditing, and concurrency.

| View | Base table | Intended aggregate/key for application work |
|---|---|---|
| `app.vw_formula_header` | `Formula_Header` | Logical revision key: branch + parent + blend + revision + status; not enforced |
| `app.vw_formula_line` | `Formula_Item` | Logical revision key + line number; not enforced |
| `app.vw_formula_certification` | `Formula_Certification` | Logical revision key + certification code/date; not enforced |
| `app.vw_certification_type` | `Formula_Certification_Builder` | Certification code; not enforced |
| `app.vw_user_group` | `Formulation_Group` | Actual PK: user + group |
| `app.vw_item_extension` | `Item_Extension` | Actual PK: branch + item |
| `app.vw_item_allergen` | `Item_Allergen` | Identity PK; logical parent is branch + item |
| `app.vw_item_country` | `Item_Country` | Identity PK; logical parent is branch + item |
| `app.vw_item_property` | `Item_Property` | Identity PK; logical parent is branch + item |
| `app.vw_item_regulatory_requirement` | `Item_Regulatory_Requirement` | Actual PK: branch + item |
| `app.vw_item_solvent` | `Item_Solvent` | Identity PK; logical parent is branch + item |
| `app.vw_item_vendor_part` | `Item_Vendor_Part` | Identity PK; logical parent is branch + item |
| `app.vw_optimal_batch_size` | `Optimal_Batch_Size` | Identity PK |
| `app.vw_empty_capsule_weight` | `Empty_Capsule_Weight` | Candidate item/vendor key; not enforced |

Identity columns are returned by their views but should be omitted from inserts. Tables
without declared keys require duplicate profiling before any update/delete endpoint is
enabled.

## Shared read contracts

| View | Replaces repeated SQL shape |
|---|---|
| `reporting.vw_formula_revision_line` | Five-column header/line join repeated throughout calculation and reporting procedures |
| `reporting.vw_formula_revision_summary` | Stored line-total aggregation used by weight/cost reporting; it does not recalculate domain rules |
| `reporting.vw_formula_certification` | Formula + certification + certification-name projection |
| `reporting.vw_material_catalog_snapshot` | Read-only union of the three physical assistant snapshots, with branch retained as data |
| `integration.vw_jde_address_book_f0101` | Required F0101 vendor/address-book fields |
| `integration.vw_jde_bill_of_material_f3002` | Required F3002 parent/component BOM fields |
| `integration.vw_jde_work_order_parts_f3111` | Required F3111 material-usage fields |
| `integration.vw_jde_item_master_f4101` | Required F4101 item identity, description, category, and UOM fields |
| `integration.vw_jde_item_branch_f4102` | Required F4102 branch, stocking, category, tier, and vendor fields |
| `integration.vw_jde_item_location_f41021` | Required F41021 location quantity and hold-status fields |
| `integration.vw_jde_cost_ledger_f4105` | Required F4105 ledger method and raw/normalized cost fields |
| `integration.vw_jde_work_order_master_f4801` | Required F4801 item and planned-start fields |
| `integration.vw_jde_item_branch_cost` | Composed item/branch/master/vendor projection with separate ledger 01/05/07/21 costs |
| `integration.vw_jde_inventory_balance` | Composed permitted-location inventory aggregation and hold-status exclusion |

The integration cost view deliberately does not choose a winning cost. Existing
procedures disagree about cost precedence; that decision belongs to an approved
finance policy rather than a structural view.

## Stored procedure coverage

| Procedure(s) | Structural contract provided |
|---|---|
| `Proc_Formula_Cost` | Formula revision lines + JDE item/branch costs |
| `Proc_Formula_Item_Cost` | Formula lines; output remains job-owned `Formula_Item_Cost` history |
| `Proc_Formula_Wt_and_Cost` | Formula revision summary; output remains job-owned `Formula_Wt_and_Cost` history |
| `Proc_Formulation_Assistant`, `Proc_Formulation_Assistant_BP05`, `Proc_Formulation_Assistant_BP15`, `Proc_Formulation_Assistant_BP35` | JDE item/branch cost + inventory base views; existing snapshot tables unified for reads |
| `Proc_PLM_Cost_Update` | Formula line CRUD contract + read-only material catalog snapshot |
| `Proc_PLM_Individual_Dosage` | Formula revision lines + JDE item/branch costs; calculation logic intentionally not moved into a view |
| `Proc_Raw_Material_Cost` | JDE item/branch costs; output remains job-owned `Raw_Material_Cost` cache |
| `rpt_PLM_Allergens` | Formula revision lines + item-allergen base contract |
| `rpt_PLM_Blend_Dropdown`, `rpt_PLM_Branch_Dropdown`, `rpt_PLM_Customer_Dropdown`, `rpt_PLM_Formula_Dropdown`, `rpt_PLM_RevNum_Dropdown`, `rpt_PLM_Status_Dropdown` | Formula-header base contract; filtered `DISTINCT` remains an API query, not another view |
| `rpt_PLM_Coating_Blend_Dropdown`, `rpt_PLM_Coating_Branch_Dropdown`, `rpt_PLM_Coating_Customer_Dropdown`, `rpt_PLM_Coating_Formula_Dropdown`, `rpt_PLM_Coating_RevNum_Dropdown`, `rpt_PLM_Coating_Status_Dropdown` | Same formula-header base contract with `unit_type = 'Coating'` filter |
| `rpt_PLM_Certifications` | Shared formula-certification read projection |
| `rpt_PLM_Confidential_Coating_Weigh_Sheet`, `rpt_PLM_Confidential_Coating_WorkSheet` | Formula revision lines |
| `rpt_PLM_Confidential_Formulation_Sign_Off_Sheet_Original`, `rpt_PLM_Confidential_Formulation_Sign_Off_Sheet_v2`, `rpt_PLM_Confidential_Formulation_Sign_Off_Sheet_v2_Orig`, `rpt_PLM_Confidential_Formulation_Weigh_Sheet`, `rpt_PLM_Confidential_Formulation_WorkSheet` | Formula revision lines |
| `rpt_PLM_Quoting_Confidential_Coating_Weigh_Sheet`, `rpt_PLM_Quoting_Confidential_Coating_WorkSheet` | Formula revision lines, retaining quoted cost as a line field |
| `rpt_PLM_Quoting_Confidential_Formulation_Sign_Off_Sheet`, `rpt_PLM_Quoting_Confidential_Formulation_Sign_Off_Sheet_Original`, `rpt_PLM_Quoting_Confidential_Formulation_Weigh_Sheet`, `rpt_PLM_Quoting_Confidential_Formulation_WorkSheet` | Formula revision lines, retaining quoted cost as a line field |
| `rpt_PLM_CostCompare` | Formula header + `Formula_Wt_and_Cost` history; history is not exposed as CRUD |
| `rpt_PLM_Formula_Weight_And_Cost` | Formula revision summary + `Formula_Wt_and_Cost` history |
| `rpt_PLM_Formulas` | Formula-header base contract |
| `rpt_PLM_Formulas_With_Obsolete_Items` | Formula revision lines + JDE item/branch data |
| `rpt_PLM_MMR_Uncoated_Tablet_Encapsulation_Weight` | Formula header + item extension + external BOM/item master |
| `rpt_PLM_Regulatory_Requirements` | Formula revision lines + item-regulatory base contract + JDE descriptions |
| `rpt_PLM_SKU_List` | Formula revision lines |

All 44 stored procedures are represented in the rows above. The report procedures can
be collapsed onto shared query services without creating one view per report variant.

## SQL Agent job ownership

| SQL Agent job | Procedure | Owned mutation |
|---|---|---|
| `Proc_PLM_Cost_Update` | `Proc_PLM_Cost_Update` | Updates `Formula_Item.FMCOST` from the branch-10 assistant snapshot |
| `Proc_PLM_Formula_Item_Cost` | `Proc_Formula_Item_Cost` | Appends active line costs to `Formula_Item_Cost` |
| `Proc_PLM_Formula_Wt_and_Cost` | `Proc_Formula_Wt_and_Cost` | Appends active formula totals to `Formula_Wt_and_Cost` |
| `Proc_PLM_Formulation_ Assistant` | `Proc_Formulation_Assistant` | Rebuilds `Formulation_Assistant` |
| `Proc_PLM_Formulation_Assistant_BP05` | `Proc_Formulation_Assistant_BP05` | Rebuilds `Formulation_Assistant_BP05` |
| `Proc_PLM_Raw_Material_Cost` | `Proc_Raw_Material_Cost` | Rebuilds `Raw_Material_Cost` |

`Proc_Formulation_Assistant_BP15` and `Proc_Formulation_Assistant_BP35` exist but are
not scheduled by the supplied job script. BP35 also deletes/inserts the BP15 table;
that defect is documented rather than modeled as a nonexistent BP35 table.

## Deliberately excluded from CRUD

- `Formula_Header_Backup_*` and `Formula_Item_Backup_*`: dated archival copies.
- `Formula_Item_Cost`, `Formula_Wt_and_Cost`, and `Raw_Material_Cost`: job-owned
  history/cache tables.
- `Formulation_Assistant*`: job-owned material catalog snapshots.
- `Item_JDE_Original`: legacy ERP snapshot/history.
- `pbcatcol`, `pbcatedt`, `pbcatfmt`, `pbcattbl`, `pbcatvld`: PowerBuilder metadata.

This boundary can change after data profiling and domain review, but it prevents cache,
history, backup, and framework metadata tables from accidentally becoming public CRUD
resources during initial application mapping.
