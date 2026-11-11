# PLM mapping to the central JDE source views

Source reviewed: `C:\Users\wgao\Documents\dw_source_views.sql` (`data_source_prod`).

The central source already contains a `[jde]` view for every JDE table required by
the PLM procedures, jobs, reports, and supplied PowerBuilder main window. Four are
ready as-is; four require small additions before PLM can stop reading
`JDE_Prod_Replica` directly.

## Coverage summary

| JDE entity | Central source view | PLM coverage | Action |
|---|---|---:|---|
| F0101 Address Book | `data_source_prod.jde.vw_f0101_address_book_prod` | Complete | Reuse as-is |
| F3002 Bill of Material | `data_source_prod.jde.vw_f3002_bom_master_prod` | Complete | Reuse as-is |
| F3111 Work Order Parts | `data_source_prod.jde.vw_f3111_wo_parts_list_prod` | Partial | Expose `WMDCT` as `document_type` |
| F4101 Item Master | `data_source_prod.jde.vw_f4101_item_master_prod` | Partial | Expose four PLM fields and retain split descriptions |
| F4102 Item Branch | `data_source_prod.jde.vw_f4102_item_branch_prod` | Partial | Expose tier/category/vendor/warranty fields |
| F41021 Item Location | `data_source_prod.jde.vw_f41021_item_loc_prod` | Functionally sufficient | Add inspection quantity only if that metric is retained |
| F4105 Cost Ledger | `data_source_prod.jde.vw_f4105_cost_ledger_prod` | Complete | Reuse as-is |
| F4801 Work Order Master | `data_source_prod.jde.vw_f4801_wo_master_prod` | Complete | Reuse as-is |

No additional active JDE tables are needed. `PROD_CATALOG_DET_F41903` appears only in
commented-out PowerBuilder code and is not part of the PLM contract.

## Column-level mapping

### F0101 — Address Book

| Original JDE | PLM meaning | Central output | Status |
|---|---|---|---|
| `ABAN8` | Vendor/address number | `address_number` | Ready |
| `ABALPH` | Vendor display name | `address_name` | Ready |

### F3002 — Bill of Material

| Original JDE | PLM meaning | Central output | Status |
|---|---|---|---|
| `IXKITL` | Parent/top-level item | `parent_item_number` | Ready |
| `IXLITM` | Blend/component item | `child_item_number` | Ready |
| `IXMMCU` | BOM branch | `branch` | Ready, already trimmed |
| `IXTBM` | BOM type | `bom_type` | Ready |

The PLM MMR report filters `bom_type = 'M'` and joins `child_item_number` to F4102.

### F3111 — Work Order Parts List

| Original JDE | PLM meaning | Central output | Status |
|---|---|---|---|
| `WMCPIL` | Component/material item | `item_number` | Ready |
| `WMMCU` | Work-order branch | `branch` | Ready |
| `WMTRDJ` | Usage transaction date | `transaction_date_jde` and `transaction_date` | Ready |
| `WMUORG` | Ordered/usage quantity | `qty_ordered_raw` and scaled `qty_ordered` | Ready |
| `WMDCT` | Document type used by `WMDCT = 'IM'` | Not exposed | **Required gap** |

Add to the F3111 CTE and final projection:

```sql
NULLIF(CONVERT(varchar(2), TRIM(WMDCT)), '') AS document_type
```

The PLM rolling-12-month calculation should use `qty_ordered`, which is already
scaled, rather than multiplying `qty_ordered_raw` by `0.001` again.

### F4101 — Item Master

| Original JDE | PLM meaning | Central output | Status |
|---|---|---|---|
| `IMITM` | Short item identifier | `item_id` | Ready |
| `IMLITM` | Long item number | `item_number` | Ready |
| `IMDSC1` | Description part 1 | Only folded into `item_description` | **Expose for exact parity** |
| `IMDSC2` | Description part 2 | Only folded into `item_description` | **Expose for exact parity** |
| `IMDSGP` | Dispatch group; `TNT` overrides PLM status | Not exposed | **Required gap** |
| `IMUOM1` | Primary UOM | `primary_uom` | Ready |
| `IMUOM3` | Purchasing UOM used for cost normalization | Not exposed | **Required gap** |
| `IMPRP2` | Item category | `prp2` | Ready |
| `IMSLD` | Shelf-life days | `shelf_life_days` | Ready |
| `IMLTLV` | Item-master lead time | Not exposed | **UI parity gap** |

Add to the F4101 CTE:

```sql
NULLIF(CONVERT(varchar(30), TRIM(IMDSGP)), '') AS dispatch_group,
CONVERT(varchar(2), TRIM(IMUOM3)) AS purchasing_uom,
TRY_CONVERT(int, IMLTLV) AS lead_time_level
```

`description_1` and `description_2` already exist inside the CTE; expose both in the
final `SELECT`. The existing combined description should also preserve the legacy
period rule:

```sql
CONVERT(
    varchar(61),
    CONCAT(
        description_1,
        CASE WHEN description_2 IN ('', '.') THEN '' ELSE ' ' + description_2 END
    )
) AS item_description
```

### F4102 — Item Branch

| Original JDE | PLM meaning | Central output | Status |
|---|---|---|---|
| `IBITM` | Short item identifier | `item_id` | Ready |
| `IBLITM` | Long item number | `item_number` | Ready |
| `IBMCU` | Branch | `branch_code` and numeric `branch` | Ready |
| `IBSTKT` | Stocking type | `stocking_type` | Ready |
| `IBGLPT` | Finance/GL category | `finance_gl_code` | Ready |
| `IBSRP4` | Formulation tier | Not exposed | **Required gap** |
| `IBPRP4` | Branch category used in catalog eligibility | Not exposed | **Required gap** |
| `IBPRP2` | Purchasing/material category | `item_type` and `prp2` | Ready |
| `IBVEND` | Primary vendor number | Not exposed | **Required gap** |
| `IBSLD` | Branch shelf life | `shelf_life_days` | Ready |
| `IBLTLV` | Branch lead time | `lead_time_days` | Ready |
| `IBWARR` | Legacy branch tier/warranty field displayed by UI | Not exposed | **UI parity gap** |

Add to the F4102 CTE and final projection:

```sql
CONVERT(varchar(6), TRIM(IBSRP4)) AS tier_level,
CONVERT(varchar(3), TRIM(IBPRP4)) AS branch_category,
CASE WHEN ISNULL(IBVEND, 0) = 0 THEN NULL ELSE TRY_CONVERT(int, IBVEND) END AS vendor_number,
NULLIF(CONVERT(varchar(8), TRIM(IBWARR)), '') AS branch_tier_code
```

### F41021 — Item Location

| Original JDE | PLM meaning | Central output | Status |
|---|---|---|---|
| `LIITM` | Short item identifier | `item_id` | Ready |
| `LIMCU` | Branch | `branch` | Ready |
| `LIPQOH` | Quantity on hand | `qty_on_hand` | Ready and already scaled |
| `LIQTO1` | Quantity in inspection | Not exposed | Optional gap |
| `LILOTS` | Hold/lot status | `lot_status` | Ready |

The current formulation-assistant procedures select `LIQTO1`, but do not carry that
value into the final assistant tables. It is not required for current output parity.
If inspection quantity is retained, add this to the CTE and final projection:

```sql
TRY_CONVERT(decimal(18,3), LIQTO1 / 1000.0) AS qty_in_inspection
```

The PLM inventory projection must use `qty_on_hand` directly because the central view
has already applied JDE's `1/1000` scale.

### F4105 — Cost Ledger

| Original JDE | PLM meaning | Central output | Status |
|---|---|---|---|
| `COLITM` | Costed long item number | `item_number` | Ready |
| `COMCU` | Cost branch | `branch` | Ready and already trimmed |
| `COLEDG` | Cost method | `cost_ledger_code` | Ready |
| `COUNCS` | Raw/scaled cost | `unit_cost_raw`, `unit_cost` | Ready |

PLM uses methods `01` (last), `05` (future), `07` (standard), and `21` (PLM). Use
`unit_cost` directly; the central view already applies the `1/10000` scale.

### F4801 — Work Order Master

| Original JDE | PLM meaning | Central output | Status |
|---|---|---|---|
| `WALITM` | Work-order item/blend | `item_number` | Ready |
| `WASTRT` | Planned start Julian date | `start_date_jde` and `start_date` | Ready |

For new reporting, use the converted `start_date`. Keep `start_date_jde` only where
legacy result comparison requires the raw JDE integer.

## Central-source adapter mapping

Once the gaps above are exposed, the PLM integration contracts map as follows:

| PLM integration contract | Central source |
|---|---|
| `integration.vw_jde_address_book_f0101` | `data_source_prod.jde.vw_f0101_address_book_prod` |
| `integration.vw_jde_bill_of_material_f3002` | `data_source_prod.jde.vw_f3002_bom_master_prod` |
| `integration.vw_jde_work_order_parts_f3111` | `data_source_prod.jde.vw_f3111_wo_parts_list_prod` |
| `integration.vw_jde_item_master_f4101` | `data_source_prod.jde.vw_f4101_item_master_prod` |
| `integration.vw_jde_item_branch_f4102` | `data_source_prod.jde.vw_f4102_item_branch_prod` |
| `integration.vw_jde_item_location_f41021` | `data_source_prod.jde.vw_f41021_item_loc_prod` |
| `integration.vw_jde_cost_ledger_f4105` | `data_source_prod.jde.vw_f4105_cost_ledger_prod` |
| `integration.vw_jde_work_order_master_f4801` | `data_source_prod.jde.vw_f4801_wo_master_prod` |

Do not point the PLM adapters at the central views until the required gaps pass the
contract check in `sql/002_validate_central_jde_contract.sql`. Until then, the direct
replica views in `sql/001_base_views.sql` remain the parity-safe transitional source.

## Warehouse modeling note

The `[jde]` views are a sound source/staging layer, but the PLM application should not
depend on warehouse facts that refresh less frequently than its operational freshness
requirements. Preserve source update timestamps, document refresh SLAs, and keep
branch/item as explicit dimensions. Cost, inventory, work-order usage, and formula
history have different grains and should not be collapsed into one warehouse table.
