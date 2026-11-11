/*
    Read-only contract check for the JDE base views deployed in PLM_DEV.

    This reports both the columns required by sql/004_plm_dev_shaped_views.sql and
    the remaining columns required only for complete legacy UI/report parity.
*/

USE [PLM_DEV];
GO

SET NOCOUNT ON;

WITH required_columns AS
(
    SELECT *
    FROM (VALUES
        (N'vw_f0101_address_book_prod', N'address_number',        N'required'),
        (N'vw_f0101_address_book_prod', N'address_name',          N'required'),

        (N'vw_f3002_bom_master_prod', N'bom_type',                N'required'),
        (N'vw_f3002_bom_master_prod', N'branch',                  N'required'),
        (N'vw_f3002_bom_master_prod', N'parent_item_id',          N'required'),
        (N'vw_f3002_bom_master_prod', N'parent_item_number',      N'required'),
        (N'vw_f3002_bom_master_prod', N'child_item_id',           N'required'),
        (N'vw_f3002_bom_master_prod', N'child_item_number',       N'required'),
        (N'vw_f3002_bom_master_prod', N'component_line',          N'required'),
        (N'vw_f3002_bom_master_prod', N'component_number',        N'required'),
        (N'vw_f3002_bom_master_prod', N'operation_sequence',      N'required'),
        (N'vw_f3002_bom_master_prod', N'current_status_code',     N'required'),
        (N'vw_f3002_bom_master_prod', N'current_status',          N'required'),
        (N'vw_f3002_bom_master_prod', N'child_qty',               N'required'),
        (N'vw_f3002_bom_master_prod', N'uom',                     N'required'),
        (N'vw_f3002_bom_master_prod', N'scrap_pct',               N'required'),
        (N'vw_f3002_bom_master_prod', N'cumulative_yield_pct',    N'required'),
        (N'vw_f3002_bom_master_prod', N'begin_effective_date_jde',N'required'),
        (N'vw_f3002_bom_master_prod', N'end_effective_date_jde',  N'required'),
        (N'vw_f3002_bom_master_prod', N'begin_effective_date',    N'required'),
        (N'vw_f3002_bom_master_prod', N'end_effective_date',      N'required'),
        (N'vw_f3002_bom_master_prod', N'revision_number',         N'required'),
        (N'vw_f3002_bom_master_prod', N'child_has_bom',           N'required'),

        (N'vw_f3111_wo_parts_list_prod', N'branch',               N'required'),
        (N'vw_f3111_wo_parts_list_prod', N'item_number',          N'required'),
        (N'vw_f3111_wo_parts_list_prod', N'document_type',        N'required'),
        (N'vw_f3111_wo_parts_list_prod', N'transaction_date',     N'required'),
        (N'vw_f3111_wo_parts_list_prod', N'qty_ordered',          N'required'),

        (N'vw_f4101_item_master_prod', N'item_id',                N'required'),
        (N'vw_f4101_item_master_prod', N'item_description',       N'required'),
        (N'vw_f4101_item_master_prod', N'primary_uom',            N'required'),
        (N'vw_f4101_item_master_prod', N'purchasing_uom',         N'required'),
        (N'vw_f4101_item_master_prod', N'prp2',                   N'required'),
        (N'vw_f4101_item_master_prod', N'dispatch_group',         N'required'),
        (N'vw_f4101_item_master_prod', N'shelf_life_days',        N'required'),
        (N'vw_f4101_item_master_prod', N'lead_time_level',        N'required'),
        (N'vw_f4101_item_master_prod', N'description_1',          N'parity'),
        (N'vw_f4101_item_master_prod', N'description_2',          N'parity'),

        (N'vw_f4102_item_branch_prod', N'branch_code',            N'required'),
        (N'vw_f4102_item_branch_prod', N'item_id',                N'required'),
        (N'vw_f4102_item_branch_prod', N'item_number',            N'required'),
        (N'vw_f4102_item_branch_prod', N'stocking_type',          N'required'),
        (N'vw_f4102_item_branch_prod', N'finance_gl_code',        N'required'),
        (N'vw_f4102_item_branch_prod', N'item_type',              N'required'),
        (N'vw_f4102_item_branch_prod', N'branch_category',        N'required'),
        (N'vw_f4102_item_branch_prod', N'shelf_life_days',        N'required'),
        (N'vw_f4102_item_branch_prod', N'lead_time_days',         N'required'),
        (N'vw_f4102_item_branch_prod', N'vendor_number',          N'required'),
        (N'vw_f4102_item_branch_prod', N'tier_level',             N'parity'),
        (N'vw_f4102_item_branch_prod', N'branch_tier_code',       N'parity'),

        (N'vw_f41021_item_loc_prod', N'branch',                   N'required'),
        (N'vw_f41021_item_loc_prod', N'item_id',                  N'required'),
        (N'vw_f41021_item_loc_prod', N'lot_status',               N'required'),
        (N'vw_f41021_item_loc_prod', N'qty_on_hand',              N'required'),
        (N'vw_f41021_item_loc_prod', N'qty_backordered',          N'required'),
        (N'vw_f41021_item_loc_prod', N'qty_on_po',                N'required'),
        (N'vw_f41021_item_loc_prod', N'qty_on_work_order',        N'required'),
        (N'vw_f41021_item_loc_prod', N'qty_hard_committed',       N'required'),
        (N'vw_f41021_item_loc_prod', N'qty_soft_committed',       N'required'),
        (N'vw_f41021_item_loc_prod', N'qty_in_inspection',        N'optional'),

        (N'vw_f4105_cost_ledger_prod', N'branch',                 N'required'),
        (N'vw_f4105_cost_ledger_prod', N'item_number',            N'required'),
        (N'vw_f4105_cost_ledger_prod', N'location',               N'required'),
        (N'vw_f4105_cost_ledger_prod', N'lot_number',             N'required'),
        (N'vw_f4105_cost_ledger_prod', N'cost_ledger_code',       N'required'),
        (N'vw_f4105_cost_ledger_prod', N'unit_cost',              N'required'),

        (N'vw_f4801_wo_master_prod', N'item_number',              N'required'),
        (N'vw_f4801_wo_master_prod', N'start_date_jde',           N'required'),
        (N'vw_f4801_wo_master_prod', N'start_date',               N'required')
    ) AS r(view_name, column_name, requirement_level)
),
actual_columns AS
(
    SELECT
        v.name AS view_name,
        c.name AS column_name
    FROM sys.views AS v
    JOIN sys.schemas AS s
        ON s.schema_id = v.schema_id
    JOIN sys.columns AS c
        ON c.object_id = v.object_id
    WHERE s.name = N'jde'
)
SELECT
    required_object = N'PLM_DEV.jde.' + r.view_name,
    r.column_name,
    r.requirement_level,
    contract_status = CASE WHEN a.column_name IS NULL THEN N'MISSING' ELSE N'PASS' END
FROM required_columns AS r
LEFT JOIN actual_columns AS a
    ON  a.view_name = r.view_name
    AND a.column_name = r.column_name
ORDER BY
    CASE WHEN a.column_name IS NULL THEN 0 ELSE 1 END,
    CASE r.requirement_level
        WHEN N'required' THEN 1
        WHEN N'parity' THEN 2
        ELSE 3
    END,
    r.view_name,
    r.column_name;
GO
