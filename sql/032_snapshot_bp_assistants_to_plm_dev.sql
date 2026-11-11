USE [PLM_DEV];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() <> N'PLM_DEV'
    THROW 50000, 'Run this script only in PLM_DEV.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.Formulation_Assistant_BP05', N'U') IS NULL
        SELECT TOP (0) *
        INTO dbo.Formulation_Assistant_BP05
        FROM PLM.dbo.Formulation_Assistant_BP05;
    ELSE
        TRUNCATE TABLE dbo.Formulation_Assistant_BP05;

    INSERT INTO dbo.Formulation_Assistant_BP05 (
        IB_item_number, EX_item_number, prefer, IB_branch, EX_branch,
        last_in_cost, potency, potency_UOM, item_status, stocking_type,
        tier_level, vendor_name, quantity_available, total_last_12_months,
        trademark, item_description_1, item_description_2, primary_UOM,
        purch_UOM, last_in_cost_v2, Category, PLM_Vendor1, PLM_Vendor2,
        PLM_Vendor_UNK, Allergen, Item_Description
    )
    SELECT IB_item_number, EX_item_number, prefer, IB_branch, EX_branch,
           last_in_cost, potency, potency_UOM, item_status, stocking_type,
           tier_level, vendor_name, quantity_available, total_last_12_months,
           trademark, item_description_1, item_description_2, primary_UOM,
           purch_UOM, last_in_cost_v2, Category, PLM_Vendor1, PLM_Vendor2,
           PLM_Vendor_UNK, Allergen, Item_Description
    FROM PLM.dbo.Formulation_Assistant_BP05;

    IF OBJECT_ID(N'dbo.Formulation_Assistant_BP15', N'U') IS NULL
        SELECT TOP (0) *
        INTO dbo.Formulation_Assistant_BP15
        FROM PLM.dbo.Formulation_Assistant_BP15;
    ELSE
        TRUNCATE TABLE dbo.Formulation_Assistant_BP15;

    INSERT INTO dbo.Formulation_Assistant_BP15 (
        IB_item_number, EX_item_number, prefer, IB_branch, EX_branch,
        last_in_cost, potency, potency_UOM, item_status, stocking_type,
        tier_level, vendor_name, quantity_available, total_last_12_months,
        trademark, item_description_1, item_description_2, primary_UOM,
        purch_UOM, last_in_cost_v2, Category, PLM_Vendor1, PLM_Vendor2,
        PLM_Vendor_UNK, Allergen
    )
    SELECT IB_item_number, EX_item_number, prefer, IB_branch, EX_branch,
           last_in_cost, potency, potency_UOM, item_status, stocking_type,
           tier_level, vendor_name, quantity_available, total_last_12_months,
           trademark, item_description_1, item_description_2, primary_UOM,
           purch_UOM, last_in_cost_v2, Category, PLM_Vendor1, PLM_Vendor2,
           PLM_Vendor_UNK, Allergen
    FROM PLM.dbo.Formulation_Assistant_BP15;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT N'Formulation_Assistant' AS source_table,
       COUNT_BIG(*) AS plm_dev_rows FROM dbo.Formulation_Assistant
UNION ALL SELECT N'Formulation_Assistant_BP05', COUNT_BIG(*)
FROM dbo.Formulation_Assistant_BP05
UNION ALL SELECT N'Formulation_Assistant_BP15', COUNT_BIG(*)
FROM dbo.Formulation_Assistant_BP15;
