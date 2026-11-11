/*
    PLM_DEV shaped read views
    =========================

    Preconditions:
      - C:\Users\wgao\Documents\base_for_plm.sql has been deployed to PLM_DEV.
      - sql/001_base_views.sql has been deployed to PLM_DEV for the [app] views.
      - The JDE base views retain their current `_prod` physical names.

    Design:
      - All JDE reads go through [jde] base views; no shaped view reads JDE tables.
      - PLM-owned attributes are read through [app] base views.
      - JDE scaling is not repeated: qty_* and unit_cost are already normalized.
      - Cost methods remain separate. The only precedence calculation is explicitly
        named legacy_selected_cost to document legacy Formulation Assistant behavior.
      - No foreign keys or indexes are created.
*/

USE [PLM_DEV];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF SCHEMA_ID(N'integration') IS NULL
    EXEC(N'CREATE SCHEMA [integration] AUTHORIZATION [dbo];');
GO

IF SCHEMA_ID(N'reporting') IS NULL
    EXEC(N'CREATE SCHEMA [reporting] AUTHORIZATION [dbo];');
GO

/*
    One intended row per branch/item.

    F4105 can contain location- and lot-specific rows, so only branch-level cost rows
    are pivoted. Row counts expose duplicate method rows instead of hiding them.
*/
CREATE OR ALTER VIEW [integration].[vw_plm_item_branch_cost]
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
    One row per branch/short item. Blank JDE lot status is normalized to NULL by the
    base view, so NULL must be included explicitly; `NOT IN` alone would drop it.
*/
CREATE OR ALTER VIEW [integration].[vw_plm_inventory_balance]
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

/* One row per branch/material for the current rolling 365-day usage window. */
CREATE OR ALTER VIEW [integration].[vw_plm_material_usage_12_month]
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

/* One row per item with its latest known work-order start. */
CREATE OR ALTER VIEW [integration].[vw_plm_latest_work_order_start]
AS
SELECT
    item_number,
    MAX(start_date_jde) AS latest_start_date_jde,
    MAX(start_date) AS latest_start_date
FROM [jde].[vw_f4801_wo_master_prod]
GROUP BY item_number;
GO

/*
    PLM-facing manufacturing BOM projection. This retains effectivity/status fields;
    consumers choose the business date rather than the view silently assuming today.
*/
CREATE OR ALTER VIEW [integration].[vw_plm_manufacturing_bom_component]
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

/*
    Branch-neutral replacement for the three Formulation_Assistant snapshot shapes.
    This view does not include the missing F4102 tier_level until the base view exposes
    IBSRP4. It exposes all costs plus a clearly labeled legacy policy result.
*/
CREATE OR ALTER VIEW [reporting].[vw_plm_material_catalog]
AS
WITH vendor_summary AS
(
    SELECT
        LTRIM(RTRIM(branch_code)) COLLATE DATABASE_DEFAULT AS branch_code,
        item_number COLLATE DATABASE_DEFAULT AS item_number,
        MAX(CASE WHEN vendor_priority = 'Primary' THEN vendor_name END) AS primary_plm_vendor,
        MAX(CASE WHEN vendor_priority = 'Secondary' THEN vendor_name END) AS secondary_plm_vendor,
        MAX(CASE WHEN vendor_priority IS NULL THEN vendor_name END) AS unclassified_plm_vendor,
        COUNT(CASE WHEN vendor_priority = 'Primary' THEN 1 END) AS primary_vendor_row_count,
        COUNT(CASE WHEN vendor_priority = 'Secondary' THEN 1 END) AS secondary_vendor_row_count,
        COUNT(CASE WHEN vendor_priority IS NULL THEN 1 END) AS unclassified_vendor_row_count
    FROM [app].[vw_item_vendor_part]
    GROUP BY
        LTRIM(RTRIM(branch_code)) COLLATE DATABASE_DEFAULT,
        item_number COLLATE DATABASE_DEFAULT
),
allergen_summary AS
(
    SELECT
        LTRIM(RTRIM(branch_code)) COLLATE DATABASE_DEFAULT AS branch_code,
        item_number COLLATE DATABASE_DEFAULT AS item_number,
        CAST(MAX(CASE WHEN UPPER(LTRIM(RTRIM(present_status))) = 'YES' THEN 1 ELSE 0 END) AS bit)
            AS has_present_allergen,
        COUNT_BIG(*) AS allergen_row_count
    FROM [app].[vw_item_allergen]
    GROUP BY
        LTRIM(RTRIM(branch_code)) COLLATE DATABASE_DEFAULT,
        item_number COLLATE DATABASE_DEFAULT
),
catalog AS
(
    SELECT
        item.branch_code,
        item.item_id,
        item.item_number,
        item.item_description,
        item.primary_uom,
        item.purchasing_uom,
        item.item_category,
        item.dispatch_group,
        CASE
            WHEN item.dispatch_group = 'TNT' THEN 'TNT'
            ELSE ext.item_status
        END AS item_status,
        item.stocking_type,
        item.finance_gl_code,
        item.item_type,
        item.branch_category,
        item.vendor_number,
        item.jde_vendor_name,
        ext.item_number AS extension_item_number,
        ext.potency,
        LTRIM(RTRIM(ext.potency_unit)) AS potency_uom,
        ext.trademark,
        CASE
            WHEN NULLIF(LTRIM(RTRIM(reg.preference_code)), '') IS NULL THEN '99'
            ELSE LTRIM(RTRIM(reg.preference_code))
        END AS preference_code,
        inv.quantity_on_hand,
        usage.quantity_used_last_12_months,
        item.last_cost,
        item.future_cost,
        item.standard_cost,
        item.plm_cost,
        COALESCE(item.plm_cost, item.standard_cost, item.future_cost, 0) AS legacy_selected_cost,
        vendor.primary_plm_vendor,
        vendor.secondary_plm_vendor,
        vendor.unclassified_plm_vendor,
        vendor.primary_vendor_row_count,
        vendor.secondary_vendor_row_count,
        vendor.unclassified_vendor_row_count,
        ISNULL(allergen.has_present_allergen, 0) AS has_present_allergen,
        ISNULL(allergen.allergen_row_count, 0) AS allergen_row_count,
        item.has_duplicate_cost_method_rows,
        CAST
        (
            CASE
                WHEN
                (
                    item.finance_gl_code BETWEEN '100' AND '200L'
                    OR item.branch_category IN ('180', '185')
                )
                AND item.stocking_type NOT IN ('O', 'D')
                    THEN 1
                ELSE 0
            END
            AS bit
        ) AS is_formulation_candidate
    FROM [integration].[vw_plm_item_branch_cost] AS item
    LEFT JOIN [integration].[vw_plm_inventory_balance] AS inv
        ON  inv.branch_code = item.branch_code
        AND inv.item_id = item.item_id
    LEFT JOIN [integration].[vw_plm_material_usage_12_month] AS usage
        ON  usage.branch_code COLLATE DATABASE_DEFAULT = item.branch_code COLLATE DATABASE_DEFAULT
        AND usage.item_number COLLATE DATABASE_DEFAULT = item.item_number COLLATE DATABASE_DEFAULT
    LEFT JOIN [app].[vw_item_extension] AS ext
        ON  LTRIM(RTRIM(ext.branch_code)) COLLATE DATABASE_DEFAULT = item.branch_code COLLATE DATABASE_DEFAULT
        AND ext.item_number COLLATE DATABASE_DEFAULT = item.item_number COLLATE DATABASE_DEFAULT
    LEFT JOIN [app].[vw_item_regulatory_requirement] AS reg
        ON  LTRIM(RTRIM(reg.branch_code)) COLLATE DATABASE_DEFAULT = item.branch_code COLLATE DATABASE_DEFAULT
        AND reg.item_number COLLATE DATABASE_DEFAULT = item.item_number COLLATE DATABASE_DEFAULT
    LEFT JOIN vendor_summary AS vendor
        ON  vendor.branch_code = item.branch_code COLLATE DATABASE_DEFAULT
        AND vendor.item_number = item.item_number COLLATE DATABASE_DEFAULT
    LEFT JOIN allergen_summary AS allergen
        ON  allergen.branch_code = item.branch_code COLLATE DATABASE_DEFAULT
        AND allergen.item_number = item.item_number COLLATE DATABASE_DEFAULT
)
SELECT
    catalog.branch_code,
    catalog.item_id,
    catalog.item_number,
    catalog.item_description,
    catalog.primary_uom,
    catalog.purchasing_uom,
    catalog.item_category,
    catalog.dispatch_group,
    catalog.item_status,
    catalog.stocking_type,
    catalog.finance_gl_code,
    catalog.item_type,
    catalog.branch_category,
    catalog.vendor_number,
    catalog.jde_vendor_name,
    catalog.extension_item_number,
    catalog.potency,
    catalog.potency_uom,
    catalog.trademark,
    catalog.preference_code,
    catalog.quantity_on_hand,
    catalog.quantity_used_last_12_months,
    catalog.last_cost,
    catalog.future_cost,
    catalog.standard_cost,
    catalog.plm_cost,
    catalog.legacy_selected_cost,
    catalog.primary_plm_vendor,
    catalog.secondary_plm_vendor,
    catalog.unclassified_plm_vendor,
    catalog.primary_vendor_row_count,
    catalog.secondary_vendor_row_count,
    catalog.unclassified_vendor_row_count,
    catalog.has_present_allergen,
    catalog.allergen_row_count,
    catalog.has_duplicate_cost_method_rows,
    catalog.is_formulation_candidate,
    CASE
        WHEN catalog.primary_uom = 'GM'
         AND catalog.purchasing_uom IN ('KG', 'GM')
            THEN catalog.legacy_selected_cost * 1000
        ELSE catalog.legacy_selected_cost
    END AS legacy_normalized_cost
FROM catalog;
GO

/*
    Suggested consumers:
      - Material search: reporting.vw_plm_material_catalog
      - Formula costing: integration.vw_plm_item_branch_cost
      - Obsolete-material report: item-branch cost + inventory balance
      - MMR/BOM lookup: integration.vw_plm_manufacturing_bom_component
      - Cost comparison: integration.vw_plm_latest_work_order_start

    Keep write operations on PLM-owned base views/tables/use cases. These are read projections.
*/
