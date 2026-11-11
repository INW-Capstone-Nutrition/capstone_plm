/*
    Formula feature views after sql/008_harden_legacy_formula_tables.sql
    ==================================================================

    The two CRUD views remain one-table projections so ordinary SQL Server
    INSERT/UPDATE/DELETE operations can target them. The two history views are
    query surfaces only by application convention; their population jobs own writes.
*/

USE [PLM_DEV];
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF SCHEMA_ID(N'form') IS NULL
    EXEC(N'CREATE SCHEMA [form] AUTHORIZATION [dbo];');
GO

CREATE OR ALTER VIEW [form].[vw_formula_header]
AS
SELECT
    FormulaHeaderId AS formula_header_id,
    FHMCU AS branch_code,
    FHPRNT AS parent_item_number,
    FHBLND AS blend_item_number,
    FHNAME AS formula_name,
    FHRVNO AS revision_number,
    FHSTUS AS workflow_status,
    FHCUSN AS customer_number,
    FHCUSP AS customer_part_number,
    FHUSER AS entered_by,
    FHUNTY AS unit_type,
    FHSIZE AS size_description,
    FHTYPM AS material_description,
    FHFMCT AS formula_category,
    FHCLOR AS color_description,
    FHDOSE AS units_per_daily_dose,
    FHSRVG AS servings,
    FHDLYD AS daily_doses,
    FHHOBN AS hob_number,
    FHRMM AS raw_material_markup_percent,
    FHOVRA AS manufacturing_overage_percent,
    FHMTCP AS capsule_item_number,
    FHSLDS AS coating_solids_percent,
    FHWGHT AS coating_weight_gain_percent,
    FHCWAX AS coating_wax_percent,
    FHCHNG AS change_code,
    FHECDV AS change_number,
    FHTRDJ AS original_transaction_julian_date,
    FHNOTE AS notes,
    FHADDL AS additional_information,
    CreatedAtUtc AS created_at_utc,
    UpdatedAtUtc AS updated_at_utc,
    RowVersion AS row_version
FROM dbo.Formula_Header;
GO

CREATE OR ALTER VIEW [form].[vw_formula_item]
AS
SELECT
    FormulaItemId AS formula_item_id,
    FormulaHeaderId AS formula_header_id,
    FMRWNO AS line_number,
    FMMCU AS branch_code,
    FMPRNT AS parent_item_number,
    FMBLND AS blend_item_number,
    FMCHLD AS material_item_number,
    FMRVNO AS revision_number,
    FMSTUS AS workflow_status,
    FMDSCR AS material_description,
    FMTMRK AS trademark,
    FMVEND AS vendor_name,
    FMQUOT AS quoted_cost,
    FMCOST AS material_cost,
    FMNAME AS formula_name,
    FMUSER AS entered_by,
    FMPTNC AS potency,
    FMPTUM AS potency_unit,
    FMTIVE AS active_amount,
    FMOVRA AS line_overage_percent,
    FMGORY AS material_category,
    FMDLYD AS calculated_daily_dose_mg,
    FMMGTB AS calculated_mg_per_unit,
    FMMGMO AS calculated_mg_per_unit_with_overage,
    FMPRFM AS calculated_formula_percent,
    FMPCST AS calculated_cost_percent,
    FMPRNC AS print_cost_flag,
    FMPRNV AS print_vendor_flag,
    FMNOTE AS notes,
    CreatedAtUtc AS created_at_utc,
    UpdatedAtUtc AS updated_at_utc,
    RowVersion AS row_version
FROM dbo.Formula_Item;
GO

/* Read-only application surface; dbo population job remains the writer. */
CREATE OR ALTER VIEW [form].[vw_formula_item_cost_history]
AS
SELECT
    RunDate AS run_julian_date,
    Item_Num AS material_item_number,
    Item_Cost AS item_cost,
    BranchCode AS branch_code,
    CostMethodCode AS cost_method_code,
    CapturedAtUtc AS captured_at_utc
FROM dbo.Formula_Item_Cost;
GO

/* Read-only application surface; dbo population job remains the writer. */
CREATE OR ALTER VIEW [form].[vw_formula_weight_cost_history]
AS
SELECT
    RunDate AS run_julian_date,
    Branch AS branch_code,
    Parent AS parent_item_number,
    Blend AS blend_item_number,
    FormulaHeaderId AS formula_header_id,
    RevisionNumber AS revision_number,
    WorkflowStatus AS workflow_status,
    CalculationVersion AS calculation_version,
    [Total_Daily Dose/mg Wt] AS total_daily_dose_mg,
    [Total_mg/Unit Wt] AS total_mg_per_unit,
    [Total_mg/Unit Wt + MO%] AS total_mg_per_unit_with_overage,
    TotalFormula AS total_formula,
    Raw_Materials AS raw_material_count,
    Formula_Cost AS formula_cost,
    Last_Active_Date AS last_active_julian_date,
    CapturedAtUtc AS captured_at_utc
FROM dbo.Formula_Wt_and_Cost;
GO
