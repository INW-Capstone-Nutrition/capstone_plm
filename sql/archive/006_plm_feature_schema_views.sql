/*
    PLM_DEV feature-schema source views
    ===================================

    Reorganizes the five supplied [plm] views by their owning vertical slice:
      - [mat]  : material, cost, inventory and usage facts
      - [form] : formula/manufacturing context

    This script does not change [jde] or [core], does not add missing source
    columns, and does not drop the existing [plm] views. Consumers can be migrated
    to these names and the old objects retired separately after parity validation.
*/

USE [PLM_DEV];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF SCHEMA_ID(N'form') IS NULL
    EXEC(N'CREATE SCHEMA [form] AUTHORIZATION [dbo];');
GO
IF SCHEMA_ID(N'mat') IS NULL
    EXEC(N'CREATE SCHEMA [mat] AUTHORIZATION [dbo];');
GO
IF SCHEMA_ID(N'quality') IS NULL
    EXEC(N'CREATE SCHEMA [quality] AUTHORIZATION [dbo];');
GO
IF SCHEMA_ID(N'audit') IS NULL
    EXEC(N'CREATE SCHEMA [audit] AUTHORIZATION [dbo];');
GO
IF SCHEMA_ID(N'dash') IS NULL
    EXEC(N'CREATE SCHEMA [dash] AUTHORIZATION [dbo];');
GO
IF SCHEMA_ID(N'specs') IS NULL
    EXEC(N'CREATE SCHEMA [specs] AUTHORIZATION [dbo];');
GO

/*
    Purpose: material availability by branch/item for material search, formula
    material selection, obsolete-material review and dashboard composition.

    Grain: one row per branch_code + item_id.

    MISSING-COLUMN NOTE (not added): qty_in_inspection would come from F41021
    LIQTO1 via jde.vw_f41021_item_loc_prod. The legacy refresh selected it but did
    not persist or report it. Add only if a confirmed screen/report needs it.
*/
CREATE OR ALTER VIEW [mat].[vw_inventory_balance]
AS
SELECT
    branch AS branch_code,
    item_id,
    SUM(qty_on_hand) AS quantity_on_hand,
    SUM(qty_backordered) AS quantity_backordered,
    SUM(qty_on_po) AS quantity_on_purchase_order,
    SUM(qty_on_work_order) AS quantity_on_work_order,
    SUM(qty_hard_committed) AS quantity_hard_committed,
    SUM(qty_soft_committed) AS quantity_soft_committed
FROM [jde].[vw_f41021_item_loc_prod]
WHERE lot_status IS NULL
   OR lot_status NOT IN ('A', 'E', 'R', 'P', 'S')
GROUP BY branch, item_id;
GO

/*
    Purpose: authoritative branch/material identity, planning attributes, vendor
    and separate JDE cost methods for material search and formula costing.

    Grain: intended one row per branch_code + item_id. Duplicate cost-method row
    counts are exposed so source-data problems are visible.

    MISSING-COLUMN NOTES (not added):
      - tier_level: F4102 IBSRP4; legacy Formulation Assistant displayed it.
      - branch_tier_code: F4102 IBWARR; confirm it is distinct and still needed.
      - description_1 / description_2: F4101 IMDSC1 / IMDSC2; current base view
        exposes only item_description, so exact legacy handling of '.' in line 2
        cannot be reproduced.
*/
CREATE OR ALTER VIEW [mat].[vw_item_branch_cost]
AS
WITH branch_cost AS
(
    SELECT
        branch AS branch_code,
        item_number,
        MAX(CASE WHEN cost_ledger_code = '01' THEN unit_cost END) AS last_cost,
        MAX(CASE WHEN cost_ledger_code = '05' THEN unit_cost END) AS future_cost,
        MAX(CASE WHEN cost_ledger_code = '07' THEN unit_cost END) AS standard_cost,
        MAX(CASE WHEN cost_ledger_code = '21' THEN unit_cost END) AS plm_cost,
        COUNT(CASE WHEN cost_ledger_code = '01' THEN 1 END) AS last_cost_row_count,
        COUNT(CASE WHEN cost_ledger_code = '05' THEN 1 END) AS future_cost_row_count,
        COUNT(CASE WHEN cost_ledger_code = '07' THEN 1 END) AS standard_cost_row_count,
        COUNT(CASE WHEN cost_ledger_code = '21' THEN 1 END) AS plm_cost_row_count
    FROM [jde].[vw_f4105_cost_ledger_prod]
    WHERE location IS NULL
      AND lot_number IS NULL
      AND cost_ledger_code IN ('01', '05', '07', '21')
    GROUP BY branch, item_number
)
SELECT
    ib.branch_code,
    ib.item_id,
    ib.item_number,
    im.item_description,
    im.primary_uom,
    im.purchasing_uom,
    im.prp2 AS item_category,
    im.dispatch_group,
    im.shelf_life_days AS item_shelf_life_days,
    im.lead_time_level AS item_lead_time_level,
    ib.stocking_type,
    ib.finance_gl_code,
    ib.item_type,
    ib.branch_category,
    ib.shelf_life_days AS branch_shelf_life_days,
    ib.lead_time_days AS branch_lead_time_days,
    ib.vendor_number,
    vendor.address_name AS jde_vendor_name,
    cost.last_cost,
    cost.future_cost,
    cost.standard_cost,
    cost.plm_cost,
    cost.last_cost_row_count,
    cost.future_cost_row_count,
    cost.standard_cost_row_count,
    cost.plm_cost_row_count,
    CAST
    (
        CASE
            WHEN ISNULL(cost.last_cost_row_count, 0) > 1
              OR ISNULL(cost.future_cost_row_count, 0) > 1
              OR ISNULL(cost.standard_cost_row_count, 0) > 1
              OR ISNULL(cost.plm_cost_row_count, 0) > 1
                THEN 1
            ELSE 0
        END
        AS bit
    ) AS has_duplicate_cost_method_rows
FROM [jde].[vw_f4102_item_branch_prod] AS ib
JOIN [jde].[vw_f4101_item_master_prod] AS im
    ON im.item_id = ib.item_id
LEFT JOIN [jde].[vw_f0101_address_book_prod] AS vendor
    ON vendor.address_number = ib.vendor_number
LEFT JOIN branch_cost AS cost
    ON  cost.branch_code = ib.branch_code
    AND cost.item_number = ib.item_number;
GO

/*
    Purpose: current rolling usage for material search, purchasing context,
    obsolete-material review and dashboard aggregation.

    Grain: one row per branch_code + item_number for the rolling 365-day window.
    No currently known missing source column is required by this purpose.
*/
CREATE OR ALTER VIEW [mat].[vw_material_usage_12_month]
AS
SELECT
    branch AS branch_code,
    item_number,
    SUM(qty_ordered) AS quantity_used_last_12_months,
    COUNT_BIG(*) AS work_order_part_row_count,
    MIN(transaction_date) AS first_transaction_date_in_window,
    MAX(transaction_date) AS last_transaction_date_in_window
FROM [jde].[vw_f3111_wo_parts_list_prod]
WHERE document_type = 'IM'
  AND transaction_date >= DATEADD(day, -365, CONVERT(date, GETDATE()))
GROUP BY branch, item_number;
GO

/*
    Purpose: latest production context for formula cost comparison and formula/MMR
    inquiry.

    Grain: one row per branch_code + item_number. Branch is retained because the
    canonical JDE work-order business key is branch_code + work_order_number.
*/
CREATE OR ALTER VIEW [form].[vw_latest_work_order_start]
AS
SELECT
    branch_code,
    item_number,
    MAX(start_date_jde) AS latest_start_date_jde,
    MAX(start_date) AS latest_start_date
FROM [jde].[vw_f4801_wo_master_prod]
GROUP BY branch_code, item_number;
GO

/*
    Purpose: manufacturing BOM component lookup for formula comparison, MMR and
    production-reference screens.

    Grain: one manufacturing BOM component/effectivity row. Consumers must provide
    the business date and choose the applicable effective row; this view does not
    silently assume GETDATE(). No currently known missing source column is required.
*/
CREATE OR ALTER VIEW [form].[vw_manufacturing_bom_component]
AS
SELECT
    branch AS branch_code,
    parent_item_id,
    parent_item_number,
    child_item_id,
    child_item_number,
    component_line,
    component_number,
    operation_sequence,
    current_status_code,
    current_status,
    child_qty,
    uom,
    scrap_pct,
    cumulative_yield_pct,
    begin_effective_date_jde,
    end_effective_date_jde,
    begin_effective_date,
    end_effective_date,
    revision_number,
    child_has_bom
FROM [jde].[vw_f3002_bom_master_prod]
WHERE bom_type = 'M';
GO
