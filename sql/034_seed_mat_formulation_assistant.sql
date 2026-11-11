/*
    Refresh the unified assistant snapshot from the three PLM_DEV dbo copies.
    Run after 033_reseed_mat_material_from_assistants.sql. Every source row,
    including duplicate rows, is retained with its source table name.
    The production PLM database is never written to by this script.
*/
USE [PLM_DEV];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() <> N'PLM_DEV'
    THROW 50000, 'Run this script only in PLM_DEV.', 1;

IF OBJECT_ID(N'dbo.Formulation_Assistant_BP05', N'U') IS NULL
   OR OBJECT_ID(N'dbo.Formulation_Assistant_BP15', N'U') IS NULL
    THROW 50001, 'Snapshot both BP assistant tables before seeding.', 1;

DROP TABLE IF EXISTS #assistant_source;

SELECT CONVERT(nvarchar(64), N'Formulation_Assistant') AS source_table, a.*
INTO #assistant_source
FROM (
    SELECT IB_item_number, EX_item_number, prefer, IB_branch, EX_branch,
           last_in_cost, potency, potency_UOM, item_status, stocking_type,
           tier_level, vendor_name, quantity_available, total_last_12_months,
           trademark, item_description_1, item_description_2, primary_UOM,
           purch_UOM, last_in_cost_v2, Category, PLM_Vendor1, PLM_Vendor2,
           PLM_Vendor_UNK, Allergen, Item_Description
    FROM dbo.Formulation_Assistant
) AS a;

INSERT INTO #assistant_source
SELECT N'Formulation_Assistant_BP05',
       IB_item_number, EX_item_number, prefer, IB_branch, EX_branch,
       last_in_cost, potency, potency_UOM, item_status, stocking_type,
       tier_level, vendor_name, quantity_available, total_last_12_months,
       trademark, item_description_1, item_description_2, primary_UOM,
       purch_UOM, last_in_cost_v2, Category, PLM_Vendor1, PLM_Vendor2,
       PLM_Vendor_UNK, Allergen, Item_Description
FROM dbo.Formulation_Assistant_BP05;

INSERT INTO #assistant_source
SELECT N'Formulation_Assistant_BP15',
       IB_item_number, EX_item_number, prefer, IB_branch, EX_branch,
       last_in_cost, potency, potency_UOM, item_status, stocking_type,
       tier_level, vendor_name, quantity_available, total_last_12_months,
       trademark, item_description_1, item_description_2, primary_UOM,
       purch_UOM, last_in_cost_v2, Category, PLM_Vendor1, PLM_Vendor2,
       PLM_Vendor_UNK, Allergen, CONVERT(nvarchar(200), NULL)
FROM dbo.Formulation_Assistant_BP15;

IF EXISTS (
    SELECT 1 FROM #assistant_source
    WHERE NULLIF(TRIM(Allergen), N'') IS NOT NULL
      AND UPPER(TRIM(Allergen)) NOT IN (N'Y', N'YES', N'TRUE', N'1',
                                      N'N', N'NO', N'FALSE', N'0')
)
    THROW 50002, 'Unrecognized assistant Allergen flag; review before conversion.', 1;

IF EXISTS (
    SELECT 1 FROM #assistant_source AS s
    WHERE NULLIF(TRIM(COALESCE(NULLIF(TRIM(s.IB_branch), N''), s.EX_branch)), N'') IS NOT NULL
      AND NULLIF(TRIM(COALESCE(NULLIF(TRIM(s.IB_item_number), N''), s.EX_item_number)), N'') IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM mat.material AS m
          WHERE m.branch_code = TRIM(COALESCE(NULLIF(TRIM(s.IB_branch), N''), s.EX_branch))
            AND m.item_number = TRIM(COALESCE(NULLIF(TRIM(s.IB_item_number), N''), s.EX_item_number))
      )
)
    THROW 50003, 'An assistant branch/item key is missing from mat.material.', 1;

DECLARE @ExpectedRows bigint = (SELECT COUNT_BIG(*) FROM #assistant_source);
DECLARE @RefreshedAt datetime2(3) = SYSUTCDATETIME();

BEGIN TRY
    BEGIN TRANSACTION;

    DELETE FROM mat.formulation_assistant;
    IF EXISTS (SELECT 1 FROM sys.identity_columns
               WHERE object_id = OBJECT_ID(N'mat.formulation_assistant')
                 AND last_value IS NOT NULL)
        DBCC CHECKIDENT (N'mat.formulation_assistant', RESEED, 0) WITH NO_INFOMSGS;

    INSERT INTO mat.formulation_assistant (
        material_id, source_table, branch_code, item_number, ext_branch_code,
        ext_item_number, preference_code, last_in_cost, last_in_cost_v2,
        potency, potency_uom, item_status, stocking_type, tier_level,
        vendor_name, quantity_available, total_last_12_months, trademark,
        item_description_1, item_description_2, item_description, primary_uom,
        purchasing_uom, category, primary_plm_vendor, secondary_plm_vendor,
        unclassified_plm_vendor, has_allergen, source_built_at, refreshed_at
    )
    SELECT m.id, s.source_table, s.IB_branch, s.IB_item_number,
           s.EX_branch, s.EX_item_number, s.prefer,
           CONVERT(decimal(20,8), s.last_in_cost),
           CONVERT(decimal(20,8), s.last_in_cost_v2),
           CONVERT(decimal(18,8), s.potency), s.potency_UOM,
           s.item_status, s.stocking_type, s.tier_level, s.vendor_name,
           CONVERT(decimal(20,4), s.quantity_available),
           CONVERT(decimal(20,4), s.total_last_12_months), s.trademark,
           s.item_description_1, s.item_description_2, s.Item_Description,
           s.primary_UOM, s.purch_UOM, s.Category, s.PLM_Vendor1,
           s.PLM_Vendor2, s.PLM_Vendor_UNK,
           CASE WHEN UPPER(TRIM(s.Allergen)) IN (N'Y', N'YES', N'TRUE', N'1') THEN CONVERT(bit, 1)
                WHEN UPPER(TRIM(s.Allergen)) IN (N'N', N'NO', N'FALSE', N'0') THEN CONVERT(bit, 0)
                ELSE CONVERT(bit, NULL) END,
           NULL, @RefreshedAt
    FROM #assistant_source AS s
    LEFT JOIN mat.material AS m
      ON m.branch_code = TRIM(COALESCE(NULLIF(TRIM(s.IB_branch), N''), s.EX_branch))
     AND m.item_number = TRIM(COALESCE(NULLIF(TRIM(s.IB_item_number), N''), s.EX_item_number));

    IF (SELECT COUNT_BIG(*) FROM mat.formulation_assistant) <> @ExpectedRows
        THROW 50004, 'Assistant snapshot count did not reconcile.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT source_table, COUNT_BIG(*) AS target_rows
FROM mat.formulation_assistant
GROUP BY source_table
ORDER BY source_table;
