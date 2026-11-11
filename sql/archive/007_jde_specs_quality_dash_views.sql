/*
    JDE-backed specs, quality and dashboard views
    =============================================

    These are read-only PLM application views over the existing [jde], [core],
    [mat] and [quality] contracts. No base/core view is changed. The unverified
    [rpt] schema is intentionally excluded.

    Important boundary:
      - [specs] views here provide ERP reference/default data only. User-authored
        PLM specifications still require PLM-owned tables/views.
      - [quality] views here cover ERP lot/hold/expiration/traceability facts only.
        Review decisions, assignments and certifications require PLM-owned sources.
      - [dash] views are aggregates for display; they are never CRUD targets.

    WORK-ORDER KEY NOTE:
      Existing core lot views currently enrich work orders by work_order_number
      alone. The PLM formula boundary uses branch_code + work_order_number because
      number alone is not fully unique. Hold the work-order-enriched quality views
      from production use until those core joins are reviewed against that key.
*/

USE [PLM_DEV];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF SCHEMA_ID(N'specs') IS NULL
    EXEC(N'CREATE SCHEMA [specs] AUTHORIZATION [dbo];');
GO
IF SCHEMA_ID(N'quality') IS NULL
    EXEC(N'CREATE SCHEMA [quality] AUTHORIZATION [dbo];');
GO
IF SCHEMA_ID(N'dash') IS NULL
    EXEC(N'CREATE SCHEMA [dash] AUTHORIZATION [dbo];');
GO

/* --------------------------------------------------------------------------
   specs: authoritative JDE reference/default data, not user-authored specs
   -------------------------------------------------------------------------- */

/*
    Purpose: supplies the JDE item/branch values shown while a user creates or
    edits a PLM-owned specification.

    Grain: one row per branch_code + item_id.

    MISSING-COLUMN NOTES (not added): tier_level/branch_tier_code and separate
    description_1/description_2 remain unavailable in the current base-view
    contract. These are optional unless a confirmed specification use case needs
    them.
*/
CREATE OR ALTER VIEW [specs].[vw_jde_item_reference]
AS
SELECT
    branch_code,
    item_id,
    item_number,
    item_description,
    primary_uom,
    purchasing_uom,
    item_category,
    dispatch_group,
    item_shelf_life_days,
    item_lead_time_level,
    stocking_type,
    finance_gl_code,
    item_type,
    branch_category,
    branch_shelf_life_days,
    branch_lead_time_days,
    vendor_number,
    jde_vendor_name
FROM [mat].[vw_item_branch_cost];
GO

/*
    Purpose: address-book search/validation for specification vendor selection.
    F0101 contains address-book entities, not a guaranteed vendor-only population;
    the selected vendor must also be valid for the material/business use case.
*/
CREATE OR ALTER VIEW [specs].[vw_jde_address_reference]
AS
SELECT
    address_number,
    address_name,
    address_search_key,
    address_type_code,
    updated_date_jde,
    updated_date
FROM [jde].[vw_f0101_address_book_prod];
GO

/*
    Purpose: authoritative JDE user-defined-code labels for dropdowns and display.

    MISSING-COLUMN NOTE (not added): separate description_1/description_2 are not
    exposed by the current F0005 base view; only the combined description is used.
*/
CREATE OR ALTER VIEW [specs].[vw_jde_code_reference]
AS
SELECT
    system_code,
    record_type,
    code_key,
    udc_key,
    description,
    special_handling_code,
    hard_coded_flag,
    is_hard_coded,
    updated_date_jde,
    updated_date
FROM [jde].[vw_f0005_meta_data_prod];
GO

/* --------------------------------------------------------------------------
   quality: JDE operational quality/lot facts
   -------------------------------------------------------------------------- */

/*
    Purpose: lot-level on-hand inventory for lot inquiry and quality investigation.

    MISSING-COLUMN NOTE (not added): qty_in_inspection would require F41021 LIQTO1
    to be exposed by the base view. Add only for a confirmed inspection workflow.
*/
CREATE OR ALTER VIEW [quality].[vw_lot_inventory]
AS
SELECT
    item_id,
    item_number,
    item_description,
    gl_code,
    primary_uom,
    branch AS branch_code,
    location,
    lot_number,
    lot_status,
    location_gl_code,
    lot_description,
    received_lot_number,
    lot_grade,
    source_document_number,
    source_document_type,
    vendor_number,
    expiration_date_jde,
    expiration_date,
    lot_updated_date_jde,
    lot_updated_date,
    item_class,
    item_type,
    finance_gl_code,
    last_receipt_date_jde,
    last_receipt_date,
    location_updated_date_jde,
    location_updated_date,
    qty_on_hand,
    qty_backordered,
    qty_required,
    qty_hard_committed,
    qty_soft_committed,
    has_on_hand_qty,
    has_lot_status,
    is_hold_or_micro_status,
    is_hold_or_quality_status,
    is_work_order_lot,
    is_purchase_order_lot
FROM [core].[vw_lot_inventory_onhand_prod];
GO

/*
    Purpose: actionable lot detail for quality/hold investigation using only the
    verified core contract. Status descriptions and ownership mappings are omitted
    until their business rules are independently verified.
*/
CREATE OR ALTER VIEW [quality].[vw_lot_hold_detail]
AS
SELECT
    hold.item_id,
    hold.item_number,
    hold.item_description,
    hold.primary_uom,
    hold.branch AS branch_code,
    hold.location,
    hold.lot_number,
    hold.lot_status,
    hold.qty_on_hand,
    hold.qty_hard_committed,
    hold.qty_soft_committed,
    hold.qty_required,
    hold.qty_backordered,
    hold.expiration_date_jde,
    hold.expiration_date,
    hold.last_receipt_date_jde,
    hold.last_receipt_date,
    hold.lot_updated_date,
    hold.source_document_number,
    hold.source_document_type,
    hold.display_document_type,
    hold.vendor_number,
    hold.vendor_name,
    hold.work_order_number,
    hold.customer_number,
    hold.customer_name,
    hold.work_order_item_number,
    hold.work_order_description,
    hold.work_order_reference,
    hold.standard_cost,
    hold.on_hand_value,
    hold.is_hold_or_micro_status,
    hold.is_hold_or_quality_status,
    hold.is_work_order_lot,
    hold.is_purchase_order_lot
FROM [core].[vw_lot_item_byholds_prod] AS hold
WHERE hold.has_lot_status = 1
  AND hold.qty_on_hand > 0;
GO

/* Purpose: lot transaction genealogy for investigation and traceability. */
CREATE OR ALTER VIEW [quality].[vw_lot_transaction_trace]
AS
SELECT
    lot_number,
    item_id,
    item_number,
    item_description,
    order_number,
    work_order_number,
    order_type,
    document_number,
    document_type,
    transaction_type,
    transaction_date_jde,
    transaction_date,
    transaction_time_jde,
    qty_transacted,
    uom,
    transaction_reference,
    transaction_explanation,
    work_order_item_number,
    work_order_description,
    work_order_reference,
    work_order_status,
    is_material_issue,
    is_completion,
    is_scrap_or_issue_out,
    is_shipment
FROM [core].[vw_lot_transaction_use_prod];
GO

/* Purpose: lot-to-work-order traceability for quality investigation. */
CREATE OR ALTER VIEW [quality].[vw_lot_work_order_reference]
AS
SELECT
    lot_number,
    item_id,
    item_number,
    third_item_number,
    branch AS branch_code,
    lot_description,
    lot_status,
    received_lot_number,
    expiration_date_jde,
    expiration_date,
    updated_date_jde,
    updated_date,
    updated_by,
    source_document_number,
    source_document_type,
    source_document_company,
    work_order_number,
    work_order_item_id,
    work_order_item_number,
    work_order_description,
    related_order,
    sales_order_number,
    work_order_reference,
    work_order_qty_ordered,
    work_order_uom,
    work_order_status,
    work_order_status_description,
    is_work_order_lot,
    has_work_order_match
FROM [core].[vw_lot_wo_reference_prod];
GO

/* --------------------------------------------------------------------------
   dash: final, non-CRUD aggregates over feature views
   -------------------------------------------------------------------------- */

/*
    Purpose: branch-level material/source-data health without summing quantities
    across incompatible UOMs or imposing an arbitrary low-stock threshold.
*/
CREATE OR ALTER VIEW [dash].[vw_material_summary]
AS
SELECT
    item.branch_code,
    COUNT_BIG(*) AS material_count,
    SUM(CASE WHEN item.standard_cost IS NULL THEN 1 ELSE 0 END) AS missing_standard_cost_count,
    SUM(CASE WHEN item.plm_cost IS NULL THEN 1 ELSE 0 END) AS missing_plm_cost_count,
    SUM(CASE WHEN item.has_duplicate_cost_method_rows = 1 THEN 1 ELSE 0 END)
        AS duplicate_cost_method_material_count,
    SUM(CASE WHEN ISNULL(inv.quantity_on_hand, 0) > 0 THEN 1 ELSE 0 END)
        AS material_with_on_hand_count,
    SUM(CASE WHEN ISNULL(inv.quantity_on_hand, 0) <= 0 THEN 1 ELSE 0 END)
        AS material_without_on_hand_count,
    SUM(CASE WHEN ISNULL(usage.quantity_used_last_12_months, 0) > 0 THEN 1 ELSE 0 END)
        AS material_with_usage_12_month_count,
    SUM(CASE WHEN ISNULL(usage.quantity_used_last_12_months, 0) <= 0 THEN 1 ELSE 0 END)
        AS material_without_usage_12_month_count
FROM [mat].[vw_item_branch_cost] AS item
LEFT JOIN [mat].[vw_inventory_balance] AS inv
    ON  inv.branch_code = item.branch_code
    AND inv.item_id = item.item_id
LEFT JOIN [mat].[vw_material_usage_12_month] AS usage
    ON  usage.branch_code COLLATE DATABASE_DEFAULT = item.branch_code COLLATE DATABASE_DEFAULT
    AND usage.item_number COLLATE DATABASE_DEFAULT = item.item_number COLLATE DATABASE_DEFAULT
GROUP BY item.branch_code;
GO

/* Purpose: work-order operational counts by branch/status. */
CREATE OR ALTER VIEW [dash].[vw_work_order_status_count]
AS
SELECT
    branch_code,
    status AS work_order_status,
    status_description AS work_order_status_description,
    COUNT_BIG(*) AS work_order_count,
    SUM(CASE WHEN is_default_open_status = 1 THEN 1 ELSE 0 END) AS open_work_order_count,
    SUM(CASE WHEN is_complete_status = 1 THEN 1 ELSE 0 END) AS complete_work_order_count,
    SUM(CASE WHEN is_open_supply = 1 THEN 1 ELSE 0 END) AS open_supply_work_order_count
FROM [jde].[vw_f4801_wo_master_prod]
GROUP BY
    branch_code,
    status,
    status_description;
GO
