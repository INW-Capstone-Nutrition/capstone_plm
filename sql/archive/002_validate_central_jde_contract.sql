/*
    Read-only validation of the central JDE source contract required by PLM.

    Run after applying the small view extensions documented in:
      docs/jde_central_source_mapping.md

    A PASS result for every row means the central views expose the columns needed to
    replace direct JDE_Prod_Replica access. This script changes no database objects.
*/

SET NOCOUNT ON;

WITH required_columns AS
(
    SELECT *
    FROM (VALUES
        (N'vw_f0101_address_book_prod', N'address_number',             N'ABAN8',  N'required'),
        (N'vw_f0101_address_book_prod', N'address_name',               N'ABALPH', N'required'),

        (N'vw_f3002_bom_master_prod', N'parent_item_number',           N'IXKITL', N'required'),
        (N'vw_f3002_bom_master_prod', N'child_item_number',            N'IXLITM', N'required'),
        (N'vw_f3002_bom_master_prod', N'branch',                       N'IXMMCU', N'required'),
        (N'vw_f3002_bom_master_prod', N'bom_type',                     N'IXTBM',  N'required'),

        (N'vw_f3111_wo_parts_list_prod', N'item_number',               N'WMCPIL', N'required'),
        (N'vw_f3111_wo_parts_list_prod', N'branch',                    N'WMMCU',  N'required'),
        (N'vw_f3111_wo_parts_list_prod', N'transaction_date_jde',      N'WMTRDJ', N'required'),
        (N'vw_f3111_wo_parts_list_prod', N'qty_ordered_raw',           N'WMUORG', N'required'),
        (N'vw_f3111_wo_parts_list_prod', N'document_type',             N'WMDCT',  N'required'),

        (N'vw_f4101_item_master_prod', N'item_id',                     N'IMITM',  N'required'),
        (N'vw_f4101_item_master_prod', N'item_number',                 N'IMLITM', N'required'),
        (N'vw_f4101_item_master_prod', N'description_1',               N'IMDSC1', N'parity'),
        (N'vw_f4101_item_master_prod', N'description_2',               N'IMDSC2', N'parity'),
        (N'vw_f4101_item_master_prod', N'item_description',            N'derived',N'required'),
        (N'vw_f4101_item_master_prod', N'dispatch_group',              N'IMDSGP', N'required'),
        (N'vw_f4101_item_master_prod', N'primary_uom',                 N'IMUOM1', N'required'),
        (N'vw_f4101_item_master_prod', N'purchasing_uom',              N'IMUOM3', N'required'),
        (N'vw_f4101_item_master_prod', N'prp2',                        N'IMPRP2', N'required'),
        (N'vw_f4101_item_master_prod', N'shelf_life_days',             N'IMSLD',  N'required'),
        (N'vw_f4101_item_master_prod', N'lead_time_level',             N'IMLTLV', N'parity'),

        (N'vw_f4102_item_branch_prod', N'item_id',                     N'IBITM',  N'required'),
        (N'vw_f4102_item_branch_prod', N'item_number',                 N'IBLITM', N'required'),
        (N'vw_f4102_item_branch_prod', N'branch_code',                 N'IBMCU',  N'required'),
        (N'vw_f4102_item_branch_prod', N'stocking_type',               N'IBSTKT', N'required'),
        (N'vw_f4102_item_branch_prod', N'finance_gl_code',             N'IBGLPT', N'required'),
        (N'vw_f4102_item_branch_prod', N'tier_level',                  N'IBSRP4', N'required'),
        (N'vw_f4102_item_branch_prod', N'branch_category',             N'IBPRP4', N'required'),
        (N'vw_f4102_item_branch_prod', N'item_type',                   N'IBPRP2', N'required'),
        (N'vw_f4102_item_branch_prod', N'vendor_number',               N'IBVEND', N'required'),
        (N'vw_f4102_item_branch_prod', N'shelf_life_days',             N'IBSLD',  N'required'),
        (N'vw_f4102_item_branch_prod', N'lead_time_days',              N'IBLTLV', N'required'),
        (N'vw_f4102_item_branch_prod', N'branch_tier_code',            N'IBWARR', N'parity'),

        (N'vw_f41021_item_loc_prod', N'item_id',                       N'LIITM',  N'required'),
        (N'vw_f41021_item_loc_prod', N'branch',                        N'LIMCU',  N'required'),
        (N'vw_f41021_item_loc_prod', N'qty_on_hand',                   N'LIPQOH', N'required'),
        (N'vw_f41021_item_loc_prod', N'qty_in_inspection',             N'LIQTO1', N'optional'),
        (N'vw_f41021_item_loc_prod', N'lot_status',                    N'LILOTS', N'required'),

        (N'vw_f4105_cost_ledger_prod', N'item_number',                 N'COLITM', N'required'),
        (N'vw_f4105_cost_ledger_prod', N'branch',                      N'COMCU',  N'required'),
        (N'vw_f4105_cost_ledger_prod', N'cost_ledger_code',            N'COLEDG', N'required'),
        (N'vw_f4105_cost_ledger_prod', N'unit_cost_raw',               N'COUNCS', N'required'),
        (N'vw_f4105_cost_ledger_prod', N'unit_cost',                   N'derived',N'required'),

        (N'vw_f4801_wo_master_prod', N'item_number',                   N'WALITM', N'required'),
        (N'vw_f4801_wo_master_prod', N'start_date_jde',                N'WASTRT', N'required'),
        (N'vw_f4801_wo_master_prod', N'start_date',                    N'derived',N'preferred')
    ) AS r(view_name, column_name, jde_source_column, requirement_level)
),
actual_columns AS
(
    SELECT
        v.name AS view_name,
        c.name AS column_name
    FROM [data_source_prod].sys.views AS v
    JOIN [data_source_prod].sys.schemas AS s
        ON s.schema_id = v.schema_id
    JOIN [data_source_prod].sys.columns AS c
        ON c.object_id = v.object_id
    WHERE s.name = N'jde'
)
SELECT
    N'data_source_prod.jde.' + r.view_name AS central_view,
    r.jde_source_column,
    r.column_name AS required_output_column,
    r.requirement_level,
    CASE WHEN a.column_name IS NULL THEN N'MISSING' ELSE N'PASS' END AS contract_status
FROM required_columns AS r
LEFT JOIN actual_columns AS a
    ON  a.view_name = r.view_name
    AND a.column_name = r.column_name
ORDER BY
    r.view_name,
    CASE r.requirement_level
        WHEN N'required' THEN 1
        WHEN N'parity' THEN 2
        WHEN N'preferred' THEN 3
        ELSE 4
    END,
    r.column_name;

/* Required failures only. An empty result set means the cutover contract is ready. */
WITH required_columns AS
(
    SELECT *
    FROM (VALUES
        (N'vw_f0101_address_book_prod', N'address_number'),
        (N'vw_f0101_address_book_prod', N'address_name'),
        (N'vw_f3002_bom_master_prod', N'parent_item_number'),
        (N'vw_f3002_bom_master_prod', N'child_item_number'),
        (N'vw_f3002_bom_master_prod', N'branch'),
        (N'vw_f3002_bom_master_prod', N'bom_type'),
        (N'vw_f3111_wo_parts_list_prod', N'item_number'),
        (N'vw_f3111_wo_parts_list_prod', N'branch'),
        (N'vw_f3111_wo_parts_list_prod', N'transaction_date_jde'),
        (N'vw_f3111_wo_parts_list_prod', N'qty_ordered_raw'),
        (N'vw_f3111_wo_parts_list_prod', N'document_type'),
        (N'vw_f4101_item_master_prod', N'item_id'),
        (N'vw_f4101_item_master_prod', N'item_number'),
        (N'vw_f4101_item_master_prod', N'item_description'),
        (N'vw_f4101_item_master_prod', N'dispatch_group'),
        (N'vw_f4101_item_master_prod', N'primary_uom'),
        (N'vw_f4101_item_master_prod', N'purchasing_uom'),
        (N'vw_f4101_item_master_prod', N'prp2'),
        (N'vw_f4101_item_master_prod', N'shelf_life_days'),
        (N'vw_f4102_item_branch_prod', N'item_id'),
        (N'vw_f4102_item_branch_prod', N'item_number'),
        (N'vw_f4102_item_branch_prod', N'branch_code'),
        (N'vw_f4102_item_branch_prod', N'stocking_type'),
        (N'vw_f4102_item_branch_prod', N'finance_gl_code'),
        (N'vw_f4102_item_branch_prod', N'tier_level'),
        (N'vw_f4102_item_branch_prod', N'branch_category'),
        (N'vw_f4102_item_branch_prod', N'item_type'),
        (N'vw_f4102_item_branch_prod', N'vendor_number'),
        (N'vw_f4102_item_branch_prod', N'shelf_life_days'),
        (N'vw_f4102_item_branch_prod', N'lead_time_days'),
        (N'vw_f41021_item_loc_prod', N'item_id'),
        (N'vw_f41021_item_loc_prod', N'branch'),
        (N'vw_f41021_item_loc_prod', N'qty_on_hand'),
        (N'vw_f41021_item_loc_prod', N'lot_status'),
        (N'vw_f4105_cost_ledger_prod', N'item_number'),
        (N'vw_f4105_cost_ledger_prod', N'branch'),
        (N'vw_f4105_cost_ledger_prod', N'cost_ledger_code'),
        (N'vw_f4105_cost_ledger_prod', N'unit_cost_raw'),
        (N'vw_f4105_cost_ledger_prod', N'unit_cost'),
        (N'vw_f4801_wo_master_prod', N'item_number'),
        (N'vw_f4801_wo_master_prod', N'start_date_jde')
    ) AS r(view_name, column_name)
),
actual_columns AS
(
    SELECT v.name AS view_name, c.name AS column_name
    FROM [data_source_prod].sys.views AS v
    JOIN [data_source_prod].sys.schemas AS s ON s.schema_id = v.schema_id
    JOIN [data_source_prod].sys.columns AS c ON c.object_id = v.object_id
    WHERE s.name = N'jde'
)
SELECT
    N'data_source_prod.jde.' + r.view_name AS central_view,
    r.column_name AS missing_required_column
FROM required_columns AS r
LEFT JOIN actual_columns AS a
    ON  a.view_name = r.view_name
    AND a.column_name = r.column_name
WHERE a.column_name IS NULL
ORDER BY r.view_name, r.column_name;
