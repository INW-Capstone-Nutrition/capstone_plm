/*
    FULL LEGACY FORMULA SNAPSHOT REFRESH

    Reads only from:
        PLM.dbo.Formula_Header
        PLM.dbo.Formula_Item
        PLM.dbo.Formulation_Assistant

    Replaces data only in:
        PLM_DEV.dbo.Formula_Header
        PLM_DEV.dbo.Formula_Item
        PLM_DEV.dbo.Formulation_Assistant

    No statement in this script inserts, updates, deletes, truncates, alters, or
    otherwise writes to PLM. Source rows are first copied into local temporary
    tables. The PLM_DEV replacement is then performed in one transaction so a
    failed load restores the previous PLM_DEV data.
*/

USE [PLM_DEV];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @SnapshotStartedDt datetime2(3) = SYSUTCDATETIME();
DECLARE @LockResult int;

EXEC @LockResult = sys.sp_getapplock
    @Resource = N'PLM_DEV_LEGACY_FORMULA_SNAPSHOT_REFRESH',
    @LockMode = N'Exclusive',
    @LockOwner = N'Session',
    @LockTimeout = 0;

IF @LockResult < 0
BEGIN
    RAISERROR('Another legacy formula snapshot refresh is already running.', 16, 1);
    RETURN;
END;

DROP TABLE IF EXISTS #FormulaHeaderSnapshot;
DROP TABLE IF EXISTS #FormulaItemSnapshot;
DROP TABLE IF EXISTS #FormulationAssistantSnapshot;

/* Read-only production extraction. */
SELECT
    [FHMCU], [FHPRNT], [FHBLND], [FHNAME], [FHRVNO], [FHSTUS],
    [FHCUSN], [FHCUSP], [FHUSER], [FHUNTY], [FHSIZE], [FHTYPM],
    [FHFMCT], [FHCLOR], [FHDOSE], [FHSRVG], [FHDLYD], [FHHOBN],
    [FHRMM], [FHOVRA], [FHMTCP], [FHSLDS], [FHWGHT], [FHCWAX],
    [FHCHNG], [FHECDV], [FHTRDJ], [FHNOTE], [FHADDL]
INTO #FormulaHeaderSnapshot
FROM [PLM].[dbo].[Formula_Header];

SELECT
    [FMRWNO], [FMMCU], [FMPRNT], [FMBLND], [FMCHLD], [FMRVNO],
    [FMSTUS], [FMDSCR], [FMTMRK], [FMVEND], [FMQUOT], [FMCOST],
    [FMNAME], [FMUSER], [FMPTNC], [FMPTUM], [FMTIVE], [FMOVRA],
    [FMGORY], [FMDLYD], [FMMGTB], [FMMGMO], [FMPRFM], [FMPCST],
    [FMPRNC], [FMPRNV], [FMNOTE]
INTO #FormulaItemSnapshot
FROM [PLM].[dbo].[Formula_Item];

SELECT
    [IB_item_number], [EX_item_number], [prefer], [IB_branch], [EX_branch],
    [last_in_cost], [potency], [potency_UOM], [item_status], [stocking_type],
    [tier_level], [vendor_name], [quantity_available], [total_last_12_months],
    [trademark], [item_description_1], [item_description_2], [primary_UOM],
    [purch_UOM], [last_in_cost_v2], [Category], [PLM_Vendor1], [PLM_Vendor2],
    [PLM_Vendor_UNK], [Allergen], [Item_Description]
INTO #FormulationAssistantSnapshot
FROM [PLM].[dbo].[Formulation_Assistant];

DECLARE @ExpectedHeaderRows bigint =
    (SELECT COUNT_BIG(*) FROM #FormulaHeaderSnapshot);
DECLARE @ExpectedItemRows bigint =
    (SELECT COUNT_BIG(*) FROM #FormulaItemSnapshot);
DECLARE @ExpectedAssistantRows bigint =
    (SELECT COUNT_BIG(*) FROM #FormulationAssistantSnapshot);

BEGIN TRY
    BEGIN TRANSACTION;

    /* Every destructive statement is explicitly scoped to PLM_DEV. */
    TRUNCATE TABLE [PLM_DEV].[dbo].[Formula_Item];
    TRUNCATE TABLE [PLM_DEV].[dbo].[Formula_Header];
    TRUNCATE TABLE [PLM_DEV].[dbo].[Formulation_Assistant];

    INSERT INTO [PLM_DEV].[dbo].[Formula_Header] (
        [FHMCU], [FHPRNT], [FHBLND], [FHNAME], [FHRVNO], [FHSTUS],
        [FHCUSN], [FHCUSP], [FHUSER], [FHUNTY], [FHSIZE], [FHTYPM],
        [FHFMCT], [FHCLOR], [FHDOSE], [FHSRVG], [FHDLYD], [FHHOBN],
        [FHRMM], [FHOVRA], [FHMTCP], [FHSLDS], [FHWGHT], [FHCWAX],
        [FHCHNG], [FHECDV], [FHTRDJ], [FHNOTE], [FHADDL]
    )
    SELECT
        [FHMCU], [FHPRNT], [FHBLND], [FHNAME], [FHRVNO], [FHSTUS],
        [FHCUSN], [FHCUSP], [FHUSER], [FHUNTY], [FHSIZE], [FHTYPM],
        [FHFMCT], [FHCLOR], [FHDOSE], [FHSRVG], [FHDLYD], [FHHOBN],
        [FHRMM], [FHOVRA], [FHMTCP], [FHSLDS], [FHWGHT], [FHCWAX],
        [FHCHNG], [FHECDV], [FHTRDJ], [FHNOTE], [FHADDL]
    FROM #FormulaHeaderSnapshot;

    INSERT INTO [PLM_DEV].[dbo].[Formula_Item] (
        [FMRWNO], [FMMCU], [FMPRNT], [FMBLND], [FMCHLD], [FMRVNO],
        [FMSTUS], [FMDSCR], [FMTMRK], [FMVEND], [FMQUOT], [FMCOST],
        [FMNAME], [FMUSER], [FMPTNC], [FMPTUM], [FMTIVE], [FMOVRA],
        [FMGORY], [FMDLYD], [FMMGTB], [FMMGMO], [FMPRFM], [FMPCST],
        [FMPRNC], [FMPRNV], [FMNOTE]
    )
    SELECT
        [FMRWNO], [FMMCU], [FMPRNT], [FMBLND], [FMCHLD], [FMRVNO],
        [FMSTUS], [FMDSCR], [FMTMRK], [FMVEND], [FMQUOT], [FMCOST],
        [FMNAME], [FMUSER], [FMPTNC], [FMPTUM], [FMTIVE], [FMOVRA],
        [FMGORY], [FMDLYD], [FMMGTB], [FMMGMO], [FMPRFM], [FMPCST],
        [FMPRNC], [FMPRNV], [FMNOTE]
    FROM #FormulaItemSnapshot;

    INSERT INTO [PLM_DEV].[dbo].[Formulation_Assistant] (
        [IB_item_number], [EX_item_number], [prefer], [IB_branch], [EX_branch],
        [last_in_cost], [potency], [potency_UOM], [item_status], [stocking_type],
        [tier_level], [vendor_name], [quantity_available], [total_last_12_months],
        [trademark], [item_description_1], [item_description_2], [primary_UOM],
        [purch_UOM], [last_in_cost_v2], [Category], [PLM_Vendor1], [PLM_Vendor2],
        [PLM_Vendor_UNK], [Allergen], [Item_Description]
    )
    SELECT
        [IB_item_number], [EX_item_number], [prefer], [IB_branch], [EX_branch],
        [last_in_cost], [potency], [potency_UOM], [item_status], [stocking_type],
        [tier_level], [vendor_name], [quantity_available], [total_last_12_months],
        [trademark], [item_description_1], [item_description_2], [primary_UOM],
        [purch_UOM], [last_in_cost_v2], [Category], [PLM_Vendor1], [PLM_Vendor2],
        [PLM_Vendor_UNK], [Allergen], [Item_Description]
    FROM #FormulationAssistantSnapshot;

    IF (SELECT COUNT_BIG(*) FROM [PLM_DEV].[dbo].[Formula_Header])
            <> @ExpectedHeaderRows
       OR (SELECT COUNT_BIG(*) FROM [PLM_DEV].[dbo].[Formula_Item])
            <> @ExpectedItemRows
       OR (SELECT COUNT_BIG(*) FROM [PLM_DEV].[dbo].[Formulation_Assistant])
            <> @ExpectedAssistantRows
    BEGIN
        RAISERROR('PLM_DEV snapshot row-count validation failed.', 16, 1);
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    DECLARE @ErrorMessage nvarchar(2048) = ERROR_MESSAGE();
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    EXEC sys.sp_releaseapplock
        @Resource = N'PLM_DEV_LEGACY_FORMULA_SNAPSHOT_REFRESH',
        @LockOwner = N'Session';
    RAISERROR(@ErrorMessage, 16, 1);
    RETURN;
END CATCH;

EXEC sys.sp_releaseapplock
    @Resource = N'PLM_DEV_LEGACY_FORMULA_SNAPSHOT_REFRESH',
    @LockOwner = N'Session';

SELECT
    @SnapshotStartedDt AS snapshot_started_utc,
    SYSUTCDATETIME() AS snapshot_completed_utc,
    @ExpectedHeaderRows AS formula_header_rows,
    @ExpectedItemRows AS formula_item_rows,
    @ExpectedAssistantRows AS formulation_assistant_rows;
GO
