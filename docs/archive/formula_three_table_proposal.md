# Proposed three-table formula model

> Design proposal only. Do not deploy this document. The SQLAlchemy models and
> Alembic migration remain unchanged until this proposal is approved.
>
> **Reassessment:** the original system creator confirmed that parent/blend values
> begin as provisional identifiers and later become JDE/BOM items. The currently
> recommended three-table core is therefore `formula + formula_header + formula_line`,
> with `formula_item_map` deferred unless multiple assignments per revision are
> confirmed. See `docs/formula_identity_decision.md`.
>
> **Superseded on 2026-10-14:** implementation was approved as
> `form.formula + form.formula_header + form.formula_line`, without a generated
> `formula_code` and without `formula_item_map`. The remaining SQL in this document
> is retained only as design history; use `formula_identity_decision.md` and the ORM
> models as the current contract.

The exact 107-column legacy formula/certification schema is preserved separately in
`docs/legacy_formula_source_contract.md` for construction of the later migration
inserts.

## Design boundary

The proposed core contains exactly three tables:

1. `form.formula_header`: one row per formula revision.
2. `form.formula_line`: the authored ingredient lines for that revision.
3. `form.formula_item_map`: zero-to-many JDE item assignments for that revision.

An R&D formula receives an internal `formula_code` when it is created. It does not
need a JDE item, branch, BOM, parent item, or blend item. A later revision reuses the
same `formula_code` and receives a new `formula_header_id` and `revision_number`.

`Formula_Item_Cost` and `Formula_Wt_and_Cost` are time-series tables. Their complete
history cannot be moved into three current-state tables without either duplicating
formula rows or losing history. The proposal therefore stores only the cost and
calculation snapshots selected for a formula revision. Full historical rows remain
outside the three-table CRUD model pending a separate history decision.

`Formulation_Assistant` is a rebuilt lookup/cache. Only values actually selected for
a formula line are snapshotted. Volatile inventory, usage, status, and vendor-list
columns remain in material/reporting views.

## Proposed SQL shape

```sql
-- One row represents one revision of an internally identified formula.
CREATE TABLE [form].[formula_header]
(
    [formula_header_id] int IDENTITY(1,1) NOT NULL,
    [formula_code] nvarchar(30) NOT NULL,
    [revision_number] decimal(10,4) NOT NULL,
    [workflow_status] nvarchar(32) NOT NULL,
    [approval_dt] datetime2(3) NULL,
    [approved_by_user_name] nvarchar(80) NULL,

    [formula_name] nvarchar(60) NOT NULL,
    [owning_branch_code] nvarchar(12) NULL,
    [parent_item_number] nvarchar(64) NULL,
    [blend_item_number] nvarchar(64) NULL,
    [customer_number] nvarchar(30) NULL,
    [customer_part_number] nvarchar(60) NULL,
    [revision_author_user_name] nvarchar(80) NULL,
    [unit_type] nvarchar(30) NULL,
    [size_description] nvarchar(30) NULL,
    [formula_material_type] nvarchar(30) NULL,
    [formula_category] nvarchar(30) NULL,
    [color_description] nvarchar(30) NULL,
    [units_per_daily_dose] int NULL,
    [servings] int NULL,
    [daily_doses] int NULL,
    [hob_number] nvarchar(30) NULL,

    [raw_material_markup_percent] decimal(10,4) NULL,
    [manufacturing_overage_percent] decimal(10,4) NULL,
    [coating_solids_percent] decimal(10,4) NULL,
    [coating_weight_gain_percent] decimal(10,4) NULL,
    [coating_wax_percent] decimal(10,4) NULL,

    [change_code] nvarchar(8) NULL,
    [change_reference] nvarchar(32) NULL,
    [legacy_transaction_julian_date] bigint NULL,
    [notes] nvarchar(max) NULL,
    [additional_information] nvarchar(1024) NULL,

    -- Latest calculation snapshot selected for this revision. These are not the
    -- complete Formula_Wt_and_Cost time series.
    [calculation_run_julian_date] int NULL,
    [total_daily_dose_mg] decimal(12,4) NULL,
    [total_mg_per_unit] decimal(12,4) NULL,
    [total_mg_per_unit_with_overage] decimal(12,4) NULL,
    [total_formula_amount] decimal(10,4) NULL,
    [raw_material_count] int NULL,
    [formula_cost] decimal(10,4) NULL,
    [last_active_julian_date] int NULL,
    [calculation_version] int NOT NULL CONSTRAINT [DF_formula_header_calc_version] DEFAULT (1),

    [created_at_utc] datetime2(3) NOT NULL
        CONSTRAINT [DF_formula_header_created] DEFAULT SYSUTCDATETIME(),
    [updated_at_utc] datetime2(3) NOT NULL
        CONSTRAINT [DF_formula_header_updated] DEFAULT SYSUTCDATETIME(),
    [row_version] rowversion NOT NULL,

    CONSTRAINT [PK_formula_header]
        PRIMARY KEY ([formula_header_id]),
    CONSTRAINT [UQ_formula_header_code_revision]
        UNIQUE ([formula_code], [revision_number])

    -- parent_item_number and blend_item_number remain nullable so a new R&D
    -- formulation can exist before either legacy item number is assigned.
    -- They are retained deliberately for legacy import/report compatibility.
    -- FHMTCP may become a formula_item_map CAPSULE_COMPONENT assignment, but only
    -- after confirming that it is an item relationship rather than a formulation
    -- parameter. Until then it remains deliberately unmapped.
);

-- One row represents one authored ingredient line in one formula revision.
CREATE TABLE [form].[formula_line]
(
    [formula_line_id] int IDENTITY(1,1) NOT NULL,
    [formula_header_id] int NOT NULL,
    [line_number] int NOT NULL,

    [material_item_number] nvarchar(25) NOT NULL,
    [material_branch_code] nvarchar(12) NULL,
    [material_description_snapshot] nvarchar(60) NULL,
    [material_category_snapshot] nvarchar(30) NULL,
    [trademark_snapshot] nvarchar(64) NULL,
    [selected_vendor_name_snapshot] nvarchar(128) NULL,
    [primary_uom_snapshot] nvarchar(8) NULL,
    [cost_uom_snapshot] nvarchar(8) NULL,

    [quoted_cost] decimal(10,4) NULL,
    [selected_unit_cost] decimal(10,4) NULL,
    [cost_snapshot_run_julian_date] int NULL,
    [cost_source_code] nvarchar(20) NULL,

    [potency] decimal(10,4) NULL,
    [potency_uom] nvarchar(8) NULL,
    [active_amount] decimal(10,4) NULL,
    [line_overage_percent] decimal(10,4) NULL,
    [calculated_daily_dose_mg] decimal(10,4) NULL,
    [calculated_mg_per_unit] decimal(10,4) NULL,
    [calculated_mg_per_unit_with_overage] decimal(10,4) NULL,
    [calculated_formula_percent] decimal(10,4) NULL,
    [calculated_cost_percent] decimal(10,4) NULL,

    [print_cost_flag] bit NOT NULL
        CONSTRAINT [DF_formula_line_print_cost] DEFAULT (0),
    [print_vendor_flag] bit NOT NULL
        CONSTRAINT [DF_formula_line_print_vendor] DEFAULT (0),
    [entered_by_user_name] nvarchar(80) NULL,
    [notes] nvarchar(256) NULL,
    [created_at_utc] datetime2(3) NOT NULL
        CONSTRAINT [DF_formula_line_created] DEFAULT SYSUTCDATETIME(),
    [updated_at_utc] datetime2(3) NOT NULL
        CONSTRAINT [DF_formula_line_updated] DEFAULT SYSUTCDATETIME(),
    [row_version] rowversion NOT NULL,

    CONSTRAINT [PK_formula_line]
        PRIMARY KEY ([formula_line_id]),
    CONSTRAINT [FK_formula_line_header]
        FOREIGN KEY ([formula_header_id])
        REFERENCES [form].[formula_header] ([formula_header_id]),
    CONSTRAINT [UQ_formula_line_header_number]
        UNIQUE ([formula_header_id], [line_number])

    -- FMMCU, FMPRNT, FMBLND, FMRVNO, FMSTUS and FMNAME are not repeated here.
    -- They are replaced by formula_header_id and the header/item-map relationships.
);

-- A revision can exist with no assignments and may later be assigned to several
-- JDE items. The role preserves the different meanings of FHPRNT and FHBLND.
CREATE TABLE [form].[formula_item_map]
(
    [formula_item_map_id] int IDENTITY(1,1) NOT NULL,
    [formula_header_id] int NOT NULL,
    [item_role_code] nvarchar(24) NOT NULL,
    [branch_code] nvarchar(12) NOT NULL,
    [item_number] nvarchar(25) NOT NULL,
    [jde_short_item_id] int NULL,
    [effective_from] date NULL,
    [effective_to] date NULL,
    [assigned_at_utc] datetime2(3) NOT NULL
        CONSTRAINT [DF_formula_item_map_assigned] DEFAULT SYSUTCDATETIME(),
    [assigned_by_user_name] nvarchar(80) NULL,

    CONSTRAINT [PK_formula_item_map]
        PRIMARY KEY ([formula_item_map_id]),
    CONSTRAINT [FK_formula_item_map_header]
        FOREIGN KEY ([formula_header_id])
        REFERENCES [form].[formula_header] ([formula_header_id]),
    CONSTRAINT [UQ_formula_item_map_assignment]
        UNIQUE ([formula_header_id], [item_role_code], [branch_code], [item_number])
);
```

Initial `item_role_code` migration values would be:

- `PARENT`: `Formula_Header.FHPRNT`, also retained on the header.
- `BLEND`: `Formula_Header.FHBLND`, also retained on the header.
- `CAPSULE_COMPONENT`: potentially `Formula_Header.FHMTCP`, pending confirmation.

The duplicated parent/blend representation is deliberate for legacy compatibility.
The application service must keep the header's primary `PARENT`/`BLEND` values and
their corresponding map rows consistent. Additional mapped items remain possible.

All application-owned primary keys use SQL Server `int`, not `bigint`. The remaining
`bigint` in the proposal is `legacy_transaction_julian_date`, because it preserves the
source column's type and is not a key.

## Revision behavior and comparison

No separate `formula` or `formula_revision` table is required under this design.
`formula_header` is the revision record, and `formula_code` groups all revisions of
the same formulation.

Creating a revision should be one transactional service operation:

1. Insert a new header with the same `formula_code`, a new `revision_number`,
   `Development` status, and no approval date.
2. Copy the prior revision's lines to the new `formula_header_id`.
3. Copy the prior revision's item-map rows to the new `formula_header_id`.
4. Apply the requested edits only to the new revision.
5. Treat an approved revision as immutable; corrections create another revision.

This makes revision comparison straightforward:

- compare header scalar columns between two header IDs;
- compare lines by `line_number` (and material item as a secondary check); and
- compare item mappings by `item_role_code + branch_code + item_number`.

A future `form.vw_formula_revision_diff` view or repository query can expose added,
removed, and changed values. The three-table structure is sufficient for differences
between saved revisions.

The only history it does not preserve is every intermediate save or recalculation
inside one still-editable draft. That is audit/calculation-run history, not revision
history. The initial recommendation is to keep the legacy history tables as a
read-only archive and store the selected cost/calculation snapshot on each revision.
Add a separate calculation-history table only if the business later requires every
draft recalculation to remain queryable.

## Complete source-column disposition

### `dbo.Formula_Header`

| Source column | Proposed destination | Treatment |
|---|---|---|
| `FHMCU` | `formula_header.owning_branch_code`; item-map branch during import | Keep, but formula creation does not require it |
| `FHPRNT` | `formula_header.parent_item_number` and primary `PARENT` map row | Retain for legacy compatibility; nullable for new R&D formulas |
| `FHBLND` | `formula_header.blend_item_number` and primary `BLEND` map row | Retain for legacy compatibility; nullable for new R&D formulas |
| `FHNAME` | `formula_header.formula_name` | Keep |
| `FHRVNO` | `formula_header.revision_number` | Convert to `decimal(10,4)` |
| `FHSTUS` | `formula_header.workflow_status` | Keep; status is not identity |
| `FHCUSN` | `formula_header.customer_number` | Keep pending future customer normalization |
| `FHCUSP` | `formula_header.customer_part_number` | Keep |
| `FHUSER` | `formula_header.revision_author_user_name` | Keep as legacy user name |
| `FHUNTY` | `formula_header.unit_type` | Keep |
| `FHSIZE` | `formula_header.size_description` | Keep |
| `FHTYPM` | `formula_header.formula_material_type` | Keep; business name should be confirmed |
| `FHFMCT` | `formula_header.formula_category` | Keep |
| `FHCLOR` | `formula_header.color_description` | Keep |
| `FHDOSE` | `formula_header.units_per_daily_dose` | Keep |
| `FHSRVG` | `formula_header.servings` | Keep |
| `FHDLYD` | `formula_header.daily_doses` | Keep |
| `FHHOBN` | `formula_header.hob_number` | Keep |
| `FHRMM` | `formula_header.raw_material_markup_percent` | Convert to `decimal(10,4)` |
| `FHOVRA` | `formula_header.manufacturing_overage_percent` | Convert to `decimal(10,4)` |
| `FHMTCP` | Commented pending `CAPSULE_COMPONENT` decision | Item reference does not belong as anonymous header text |
| `FHSLDS` | `formula_header.coating_solids_percent` | Convert to `decimal(10,4)` |
| `FHWGHT` | `formula_header.coating_weight_gain_percent` | Convert to `decimal(10,4)` |
| `FHCWAX` | `formula_header.coating_wax_percent` | Convert to `decimal(10,4)` |
| `FHCHNG` | `formula_header.change_code` | Keep |
| `FHECDV` | `formula_header.change_reference` | Keep |
| `FHTRDJ` | `formula_header.legacy_transaction_julian_date` | Preserve for migration/audit; convert to a real date later if semantics are confirmed |
| `FHNOTE` | `formula_header.notes` | Keep |
| `FHADDL` | `formula_header.additional_information` | Keep |

### `dbo.Formula_Item`

| Source column | Proposed destination | Treatment |
|---|---|---|
| `FMRWNO` | `formula_line.line_number` | Keep |
| `FMMCU` | Commented; derive through header/item map | Do not duplicate on every line |
| `FMPRNT` | Commented; header parent and `PARENT` map | Do not duplicate on every line |
| `FMBLND` | Commented; header blend and `BLEND` map | Do not duplicate on every line |
| `FMCHLD` | `formula_line.material_item_number` | Keep |
| `FMRVNO` | Commented; `formula_header.revision_number` | Replaced by `formula_header_id` |
| `FMSTUS` | Commented; `formula_header.workflow_status` | Replaced by `formula_header_id` |
| `FMDSCR` | `formula_line.material_description_snapshot` | Keep as revision snapshot |
| `FMTMRK` | `formula_line.trademark_snapshot` | Keep as revision snapshot |
| `FMVEND` | `formula_line.selected_vendor_name_snapshot` | Keep only the vendor actually selected |
| `FMQUOT` | `formula_line.quoted_cost` | Convert to `decimal(10,4)` |
| `FMCOST` | `formula_line.selected_unit_cost` | Existing formula snapshot takes migration precedence |
| `FMNAME` | Commented; `formula_header.formula_name` | Do not duplicate on every line |
| `FMUSER` | `formula_line.entered_by_user_name` | Keep |
| `FMPTNC` | `formula_line.potency` | Convert to `decimal(10,4)` |
| `FMPTUM` | `formula_line.potency_uom` | Keep |
| `FMTIVE` | `formula_line.active_amount` | Convert to `decimal(10,4)` |
| `FMOVRA` | `formula_line.line_overage_percent` | Convert to `decimal(10,4)` |
| `FMGORY` | `formula_line.material_category_snapshot` | Keep as revision snapshot |
| `FMDLYD` | `formula_line.calculated_daily_dose_mg` | Convert to `decimal(10,4)` |
| `FMMGTB` | `formula_line.calculated_mg_per_unit` | Convert to `decimal(10,4)` |
| `FMMGMO` | `formula_line.calculated_mg_per_unit_with_overage` | Convert to `decimal(10,4)` |
| `FMPRFM` | `formula_line.calculated_formula_percent` | Convert to `decimal(10,4)` |
| `FMPCST` | `formula_line.calculated_cost_percent` | Convert to `decimal(10,4)` |
| `FMPRNC` | `formula_line.print_cost_flag` | Normalize `Y/N` or `1/0` to `bit` |
| `FMPRNV` | `formula_line.print_vendor_flag` | Normalize `Y/N` or `1/0` to `bit` |
| `FMNOTE` | `formula_line.notes` | Keep |

### `dbo.Formula_Item_Cost`

| Source column | Proposed destination | Treatment |
|---|---|---|
| `RunDate` | `formula_line.cost_snapshot_run_julian_date`, only for the cost actually selected | Full time series does not fit the three-table model |
| `Item_Num` | Matches `formula_line.material_item_number` | Lookup key, not another stored column |
| `Item_Cost` | `formula_line.selected_unit_cost`, only if no authored `FMCOST` snapshot exists | Full history should remain in `mat.material_cost_history` or the source system |

Migration precedence for a formula line should be:

1. Existing `Formula_Item.FMCOST` because it is the authored formula snapshot.
2. The applicable `Formula_Item_Cost.Item_Cost` record for the chosen run date.
3. The approved material-catalog cost policy only when neither snapshot exists.

### `dbo.Formula_Wt_and_Cost`

| Source column | Proposed destination | Treatment |
|---|---|---|
| `RunDate` | `formula_header.calculation_run_julian_date` for the selected/latest snapshot | Full time series does not fit |
| `Branch` | Resolve header/item-map relationship | Do not duplicate calculation identity |
| `Parent` | Resolve `PARENT` item map | Do not duplicate calculation identity |
| `Blend` | Resolve `BLEND` item map | Do not duplicate calculation identity |
| `Total_Daily Dose/mg Wt` | `formula_header.total_daily_dose_mg` | Use `decimal(12,4)`; current values exceed `decimal(10,4)` |
| `Total_mg/Unit Wt` | `formula_header.total_mg_per_unit` | Use `decimal(12,4)` |
| `Total_mg/Unit Wt + MO%` | `formula_header.total_mg_per_unit_with_overage` | Use `decimal(12,4)` |
| `TotalFormula` | `formula_header.total_formula_amount` | Use `decimal(10,4)`; unit meaning must be confirmed |
| `Raw_Materials` | `formula_header.raw_material_count` | Snapshot/derived value |
| `Formula_Cost` | `formula_header.formula_cost` | Snapshot/derived value |
| `Last_Active_Date` | `formula_header.last_active_julian_date` | Preserve until date semantics are confirmed |

If every calculation run must remain reproducible, add a future
`form.formula_calculation_snapshot` table instead of retaining only the latest values
on `formula_header`.

### `dbo.Formulation_Assistant`

| Source column | Proposed destination | Treatment |
|---|---|---|
| `IB_item_number` | `formula_line.material_item_number` when selected | JDE item identity |
| `EX_item_number` | Commented; `mat`/`specs` extension view | Optional enrichment, not separate line identity |
| `prefer` | Commented; material regulatory/preference view | Volatile lookup/default |
| `IB_branch` | `formula_line.material_branch_code` when selected | Snapshot source context |
| `EX_branch` | Commented; `mat`/`specs` extension view | Optional enrichment |
| `last_in_cost` | Commented; material cost-policy input | Do not store both raw and normalized cache costs |
| `potency` | `formula_line.potency` as a creation default | Authored line value wins thereafter |
| `potency_UOM` | `formula_line.potency_uom` as a creation default | Authored line value wins thereafter |
| `item_status` | Commented; `mat.vw_item_branch_cost` | Volatile material status |
| `stocking_type` | Commented; `mat.vw_item_branch_cost` | Material lookup property |
| `tier_level` | Commented; future material/JDE view when verified | Missing from the verified base contract today |
| `vendor_name` | `formula_line.selected_vendor_name_snapshot` only when selected | Otherwise remains material lookup data |
| `quantity_available` | Commented; `mat.vw_inventory_balance` | Volatile inventory, never formula state |
| `total_last_12_months` | Commented; `mat.vw_material_usage_12_month` | Rolling measure, never formula state |
| `trademark` | `formula_line.trademark_snapshot` when selected | Revision snapshot |
| `item_description_1` | Fold into `formula_line.material_description_snapshot` | Do not retain duplicate description columns |
| `item_description_2` | Fold into `formula_line.material_description_snapshot` | Do not retain duplicate description columns |
| `primary_UOM` | `formula_line.primary_uom_snapshot` | Needed to reproduce quantity calculations |
| `purch_UOM` | `formula_line.cost_uom_snapshot` if it describes the selected cost | Otherwise material lookup data |
| `last_in_cost_v2` | `formula_line.selected_unit_cost` only as a default | Existing `FMCOST` wins during migration |
| `Category` | `formula_line.material_category_snapshot` | Revision snapshot |
| `PLM_Vendor1` | Commented; material-vendor view | Store only the selected vendor on a line |
| `PLM_Vendor2` | Commented; material-vendor view | Store only the selected vendor on a line |
| `PLM_Vendor_UNK` | Commented; material-vendor cleanup/view | Not formula state |
| `Allergen` | Commented; `specs` allergen data and derived formula allergen result | Do not store a denormalized flag from the cache |
| `Item_Description` | Fold into `formula_line.material_description_snapshot` | Duplicate combined description |

## Decisions required before ORM implementation

1. Confirm that a `formula_header` row is one revision and that `formula_code` groups
   revisions without a separate root table.
2. Define how new internal `formula_code` values are generated and how legacy rows
   are grouped into codes during migration.
3. Confirm that cloning a new revision should copy its lines and item-map rows, as
   proposed, so each revision remains a complete independent snapshot.
4. Confirm whether `PARENT` and `BLEND` map rows may have additional assignments of
   the same role or only one primary assignment per role.
5. Decide whether `FHMTCP` is a `CAPSULE_COMPONENT` assignment, a special ingredient
   line, or a header formulation parameter.
6. Confirm the business meaning and unit of `TotalFormula`.
7. Confirm the recommendation to preserve legacy item-cost and calculation tables as
   read-only archives while migrating only the snapshot selected by each revision.
8. Confirm the cost-selection policy and UOM normalization that replaces
   `Proc_PLM_Cost_Update` and `last_in_cost_v2`.

After approval, update the three SQLAlchemy models, Pydantic contracts, repositories,
tests, and Alembic migration together. Do not deploy the current normalized migration
before that refactor.
