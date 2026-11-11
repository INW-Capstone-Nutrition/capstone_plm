# PLM_DEV JDE base-view gap analysis

Source reviewed: `C:\Users\wgao\Documents\base_for_plm.sql` dated September 30,
2026. The file defines the JDE base views inside `PLM_DEV` and includes all eight JDE
entities required by PLM.

## Result

The base views are sufficient for the shaped cost, inventory, usage, BOM, work-order,
and material-catalog views in `sql/004_plm_dev_shaped_views.sql`.

Four legacy-parity fields and one unused metric remain absent:

| Base view | Missing output | Source column | Impact | Recommendation |
|---|---|---|---|---|
| `jde.vw_f4102_item_branch_prod` | `tier_level` | `IBSRP4` | The legacy Formulation Assistant displayed this value | Add before tier filtering/display is migrated |
| `jde.vw_f4102_item_branch_prod` | `branch_tier_code` | `IBWARR` | Referenced by one legacy PowerBuilder data contract | Add only if confirmed distinct from `IBSRP4` and still needed |
| `jde.vw_f4101_item_master_prod` | `description_1`, `description_2` | `IMDSC1`, `IMDSC2` | Combined description exists, but exact legacy handling of description 2 equal to `.` cannot be reproduced | Expose both or change the combined-description CASE to treat `.` as empty |
| `jde.vw_f41021_item_loc_prod` | `qty_in_inspection` | `LIQTO1` | Legacy refresh selected it but never persisted or reported it | Optional; add only if the new application will display it |

## Gaps closed since the earlier source review

- F3111 now exposes `document_type` from `WMDCT`.
- F4101 now exposes `purchasing_uom`, `lead_time_level`, and `dispatch_group`.
- F4102 now exposes `branch_category` and `vendor_number`.
- The base views already normalize JDE quantities and costs. Shaped views must not
  divide `qty_on_hand`/`qty_ordered` by 1,000 or `unit_cost` by 10,000 again.

## Suggested base-view additions

Inside the F4102 CTE and final projection:

```sql
CONVERT(varchar(6), TRIM(IBSRP4)) AS tier_level,
NULLIF(CONVERT(varchar(8), TRIM(IBWARR)), '') AS branch_tier_code
```

Inside the F4101 final projection, expose the already-defined CTE fields:

```sql
description_1,
description_2,
```

For exact combined-description parity:

```sql
CONVERT(
    varchar(61),
    CONCAT(
        description_1,
        CASE WHEN description_2 IN ('', '.') THEN '' ELSE ' ' + description_2 END
    )
) AS item_description
```

Optional F41021 CTE/output addition:

```sql
TRY_CONVERT(decimal(18,3), LIQTO1 / 1000.0) AS qty_in_inspection
```

No placeholder columns were added to the shaped views. A missing business value should
remain an explicit source-contract gap rather than silently becoming `NULL`.
