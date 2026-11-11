# Required JDE tables, columns, and integration views

For the mapping to the existing `data_source_prod` warehouse-source views and its
column-gap analysis, see `docs/jde_central_source_mapping.md`.

The supplied PLM stored procedures require eight distinct JDE tables. The PowerBuilder
main window uses the same table set and adds several F4101/F4102 fields. New code
should use the `[integration]` views in `sql/001_base_views.sql` instead of querying
JDE objects directly.

The view layer targets `JDE_Prod_Replica.dbo` because that is the dominant source in
the current procedures. Direct `PRODDTA.F4101`, `PRODDTA.F4102`, and `PRODDTA.F41021`
references are alternate physical names for the same JDE entities. The two `RptData`
references are older copies of F4101/F4102 and should also be normalized to these
contracts rather than receiving duplicate views.

## JDE table inventory

### F0101 — Address Book Master

Source object: `JDE_Prod_Replica.dbo.Address_Book_F0101`  
View: `integration.vw_jde_address_book_f0101`

| JDE column | View column | PLM use |
|---|---|---|
| `ABAN8` | `address_number` | Join from `F4102.IBVEND` |
| `ABALPH` | `alpha_name` | Vendor display name |

### F3002 — Bill of Material Master

Source object: `JDE_Prod_Replica.dbo.Bill_Of_Material_F3002`  
View: `integration.vw_jde_bill_of_material_f3002`

| JDE column | View column | PLM use |
|---|---|---|
| `IXKITL` | `parent_item_number` | Requested/top-level manufacturing item |
| `IXLITM` | `component_item_number` | Resolve the blend/component item |
| `IXMMCU` | `branch_code` | Branch match to F4102 |
| `IXTBM` | `bill_type` | Filter manufacturing BOM rows (`M`) |

### F3111 — Work Order Parts List

Source object: `JDE_Prod_Replica.dbo.WO_Parts_List_F3111`  
View: `integration.vw_jde_work_order_parts_f3111`

| JDE column | View column | PLM use |
|---|---|---|
| `WMCPIL` | `component_item_number` | Material/item used by work orders |
| `WMMCU` | `branch_code` | Usage branch |
| `WMTRDJ` | `transaction_julian_date` | Rolling 12-month cutoff |
| `WMUORG` | `order_quantity_raw` | Quantity accumulated for usage |
| `WMDCT` | `document_type` | Filter work-order rows (`IM`) |

### F4101 — Item Master

Source object: `JDE_Prod_Replica.dbo.Item_Master_F4101`  
View: `integration.vw_jde_item_master_f4101`

| JDE column | View column | PLM use |
|---|---|---|
| `IMITM` | `short_item_number` | Join to F4102 |
| `IMLITM` | `item_number` | PLM/JDE long item identity |
| `IMDSC1` | `description_1` | Item description |
| `IMDSC2` | `description_2` | Item description continuation |
| `IMDSGP` | `dispatch_group` | TNT status override in assistant refresh |
| `IMUOM1` | `primary_unit` | Primary unit and cost normalization |
| `IMUOM3` | `purchasing_unit` | Purchasing unit and cost normalization |
| `IMPRP2` | `item_category` | Material category |
| `IMSLD` | `shelf_life_days` | Shelf life displayed in material lookup/editing |
| `IMLTLV` | `lead_time_level` | Lead-time value displayed in material lookup/editing |

### F4102 — Item Branch

Source object: `JDE_Prod_Replica.dbo.Item_Branch_F4102`  
View: `integration.vw_jde_item_branch_f4102`

| JDE column | View column | PLM use |
|---|---|---|
| `IBITM` | `short_item_number` | Join to F4101/F41021 |
| `IBLITM` | `item_number` | PLM/JDE long item identity |
| `IBMCU` | `branch_code` | Branch filtering and joins |
| `IBSTKT` | `stocking_type` | Exclude or report obsolete/discontinued items |
| `IBGLPT` | `gl_category` | Raw-material/catalog eligibility |
| `IBSRP4` | `tier_level` | Formulation assistant tier |
| `IBPRP4` | `branch_category` | Additional catalog eligibility |
| `IBPRP2` | `purchasing_category` | PowerBuilder material category filter/display |
| `IBVEND` | `vendor_number` | Join to F0101 |
| `IBSLD` | `branch_shelf_life_days` | Branch shelf-life field referenced by the UI data contract |
| `IBLTLV` | `branch_lead_time_level` | Branch lead-time field referenced by the UI data contract |
| `IBWARR` | `branch_tier_code` | Branch tier/warranty field referenced by the UI data contract |

### F41021 — Item Location

Source object: `JDE_Prod_Replica.dbo.Item_Location_F41021`  
View: `integration.vw_jde_item_location_f41021`

| JDE column | View column | PLM use |
|---|---|---|
| `LIITM` | `short_item_number` | Join to F4102 |
| `LIMCU` | `branch_code` | Branch/location aggregation |
| `LIPQOH` | `quantity_on_hand_raw` | Quantity on hand; JDE scaling applied in composed view |
| `LIQTO1` | `quantity_in_inspection_raw` | Quantity in inspection; JDE scaling applied in composed view |
| `LILOTS` | `lot_status` | Exclude hold statuses `A,E,R,P,S` |

### F4105 — Item Cost Ledger

Source object: `JDE_Prod_Replica.dbo.Cost_Ledger_F4105`  
View: `integration.vw_jde_cost_ledger_f4105`

| JDE column | View column | PLM use |
|---|---|---|
| `COLITM` | `item_number` | Costed long item number |
| `COMCU` | `branch_code` | Cost branch |
| `COLEDG` | `cost_method` | `01` last, `05` future, `07` standard, `21` PLM |
| `COUNCS` | `unit_cost_raw` | Native JDE cost value |
| Derived from `COUNCS` | `unit_cost` | `COUNCS * 0.0001`, matching current procedures |

The base view keeps both the raw and scaled cost. `integration.vw_jde_item_branch_cost`
pivots the four used cost methods but does not choose a preferred cost.

### F4801 — Work Order Master

Source object: `JDE_Prod_Replica.dbo.Work_Order_Master_F4801`  
View: `integration.vw_jde_work_order_master_f4801`

| JDE column | View column | PLM use |
|---|---|---|
| `WALITM` | `item_number` | Join formula blend to work orders |
| `WASTRT` | `planned_start_julian_date` | Latest/next work-order start date in cost comparison |

## Composed integration views

| View | Base views | Grain |
|---|---|---|
| `integration.vw_jde_item_branch_cost` | F4102 + F4101 + F0101 + F4105 | One intended row per branch/item, assuming one applicable cost row per method |
| `integration.vw_jde_inventory_balance` | F41021 | One row per branch/short item after excluding hold statuses |

## Source normalization decisions

- Use the `JDE_Prod_Replica.dbo` friendly objects as the view sources.
- Replace direct `[JDE_Prod_Replica].[PRODDTA].[F4101/F4102/F41021]` queries with the
  corresponding integration views.
- Replace `RptData.dbo.Item_Master_F4101` and `RptData.dbo.Item_Branch_F4102` reads
  with the same F4101/F4102 integration views after parity testing.
- `PROD_CATALOG_DET_F41903` appears only in commented-out PowerBuilder SQL and is not
  included as an active dependency.
- Keep JDE read-only from PLM. CRUD views apply to PLM-owned tables, not ERP tables.
- Confirm the F4105 grain in production. The composed cost view uses `MAX` to protect
  the branch/item projection from duplicate method rows, matching the current
  procedures' implicit single-row assumption without selecting a finance policy.
