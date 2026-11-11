/*
    APPEND-ONLY LEGACY SNAPSHOT SYNCHRONIZATION

    The procedure reads PLM and writes only to PLM_DEV. It never updates or
    deletes a PLM_DEV snapshot row. A source row is new when its complete row
    value does not already exist locally. Consequently:

      - a new revision or changed source row is appended;
      - the prior local version remains available for audit;
      - a newly added byte-for-byte duplicate is intentionally ignored because
        these legacy tables have no source surrogate key that can distinguish it.

    Preview is the default:
        EXEC dbo.usp_append_legacy_formula_snapshot;

    Apply after reviewing the counts:
        EXEC dbo.usp_append_legacy_formula_snapshot @ApplyChanges = 1;
*/

USE [PLM_DEV];
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_append_legacy_formula_snapshot]
    @ApplyChanges bit = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DROP TABLE IF EXISTS #NewFormulaHeader;
    DROP TABLE IF EXISTS #NewFormulaItem;
    DROP TABLE IF EXISTS #NewFormulationAssistant;

    SELECT
        [FHMCU], [FHPRNT], [FHBLND], [FHNAME], [FHRVNO], [FHSTUS],
        [FHCUSN], [FHCUSP], [FHUSER], [FHUNTY], [FHSIZE], [FHTYPM],
        [FHFMCT], [FHCLOR], [FHDOSE], [FHSRVG], [FHDLYD], [FHHOBN],
        [FHRMM], [FHOVRA], [FHMTCP], [FHSLDS], [FHWGHT], [FHCWAX],
        [FHCHNG], [FHECDV], [FHTRDJ], [FHNOTE], [FHADDL]
    INTO #NewFormulaHeader
    FROM [PLM].[dbo].[Formula_Header]
    EXCEPT
    SELECT
        [FHMCU], [FHPRNT], [FHBLND], [FHNAME], [FHRVNO], [FHSTUS],
        [FHCUSN], [FHCUSP], [FHUSER], [FHUNTY], [FHSIZE], [FHTYPM],
        [FHFMCT], [FHCLOR], [FHDOSE], [FHSRVG], [FHDLYD], [FHHOBN],
        [FHRMM], [FHOVRA], [FHMTCP], [FHSLDS], [FHWGHT], [FHCWAX],
        [FHCHNG], [FHECDV], [FHTRDJ], [FHNOTE], [FHADDL]
    FROM [PLM_DEV].[dbo].[Formula_Header];

    SELECT
        [FMRWNO], [FMMCU], [FMPRNT], [FMBLND], [FMCHLD], [FMRVNO],
        [FMSTUS], [FMDSCR], [FMTMRK], [FMVEND], [FMQUOT], [FMCOST],
        [FMNAME], [FMUSER], [FMPTNC], [FMPTUM], [FMTIVE], [FMOVRA],
        [FMGORY], [FMDLYD], [FMMGTB], [FMMGMO], [FMPRFM], [FMPCST],
        [FMPRNC], [FMPRNV], [FMNOTE]
    INTO #NewFormulaItem
    FROM [PLM].[dbo].[Formula_Item]
    EXCEPT
    SELECT
        [FMRWNO], [FMMCU], [FMPRNT], [FMBLND], [FMCHLD], [FMRVNO],
        [FMSTUS], [FMDSCR], [FMTMRK], [FMVEND], [FMQUOT], [FMCOST],
        [FMNAME], [FMUSER], [FMPTNC], [FMPTUM], [FMTIVE], [FMOVRA],
        [FMGORY], [FMDLYD], [FMMGTB], [FMMGMO], [FMPRFM], [FMPCST],
        [FMPRNC], [FMPRNV], [FMNOTE]
    FROM [PLM_DEV].[dbo].[Formula_Item];

    SELECT
        [IB_item_number], [EX_item_number], [prefer], [IB_branch], [EX_branch],
        [last_in_cost], [potency], [potency_UOM], [item_status], [stocking_type],
        [tier_level], [vendor_name], [quantity_available], [total_last_12_months],
        [trademark], [item_description_1], [item_description_2], [primary_UOM],
        [purch_UOM], [last_in_cost_v2], [Category], [PLM_Vendor1], [PLM_Vendor2],
        [PLM_Vendor_UNK], [Allergen], [Item_Description]
    INTO #NewFormulationAssistant
    FROM [PLM].[dbo].[Formulation_Assistant]
    EXCEPT
    SELECT
        [IB_item_number], [EX_item_number], [prefer], [IB_branch], [EX_branch],
        [last_in_cost], [potency], [potency_UOM], [item_status], [stocking_type],
        [tier_level], [vendor_name], [quantity_available], [total_last_12_months],
        [trademark], [item_description_1], [item_description_2], [primary_UOM],
        [purch_UOM], [last_in_cost_v2], [Category], [PLM_Vendor1], [PLM_Vendor2],
        [PLM_Vendor_UNK], [Allergen], [Item_Description]
    FROM [PLM_DEV].[dbo].[Formulation_Assistant];

    DECLARE @HeaderRows bigint = (SELECT COUNT_BIG(*) FROM #NewFormulaHeader);
    DECLARE @ItemRows bigint = (SELECT COUNT_BIG(*) FROM #NewFormulaItem);
    DECLARE @AssistantRows bigint =
        (SELECT COUNT_BIG(*) FROM #NewFormulationAssistant);

    SELECT
        @ApplyChanges AS apply_changes,
        @HeaderRows AS new_formula_header_rows,
        @ItemRows AS new_formula_item_rows,
        @AssistantRows AS new_formulation_assistant_rows;

    IF @ApplyChanges = 0
        RETURN;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO [PLM_DEV].[dbo].[Formula_Header] (
            [FHMCU], [FHPRNT], [FHBLND], [FHNAME], [FHRVNO], [FHSTUS],
            [FHCUSN], [FHCUSP], [FHUSER], [FHUNTY], [FHSIZE], [FHTYPM],
            [FHFMCT], [FHCLOR], [FHDOSE], [FHSRVG], [FHDLYD], [FHHOBN],
            [FHRMM], [FHOVRA], [FHMTCP], [FHSLDS], [FHWGHT], [FHCWAX],
            [FHCHNG], [FHECDV], [FHTRDJ], [FHNOTE], [FHADDL]
        )
        SELECT * FROM #NewFormulaHeader;

        INSERT INTO [PLM_DEV].[dbo].[Formula_Item] (
            [FMRWNO], [FMMCU], [FMPRNT], [FMBLND], [FMCHLD], [FMRVNO],
            [FMSTUS], [FMDSCR], [FMTMRK], [FMVEND], [FMQUOT], [FMCOST],
            [FMNAME], [FMUSER], [FMPTNC], [FMPTUM], [FMTIVE], [FMOVRA],
            [FMGORY], [FMDLYD], [FMMGTB], [FMMGMO], [FMPRFM], [FMPCST],
            [FMPRNC], [FMPRNV], [FMNOTE]
        )
        SELECT * FROM #NewFormulaItem;

        INSERT INTO [PLM_DEV].[dbo].[Formulation_Assistant] (
            [IB_item_number], [EX_item_number], [prefer], [IB_branch], [EX_branch],
            [last_in_cost], [potency], [potency_UOM], [item_status], [stocking_type],
            [tier_level], [vendor_name], [quantity_available], [total_last_12_months],
            [trademark], [item_description_1], [item_description_2], [primary_UOM],
            [purch_UOM], [last_in_cost_v2], [Category], [PLM_Vendor1], [PLM_Vendor2],
            [PLM_Vendor_UNK], [Allergen], [Item_Description]
        )
        SELECT * FROM #NewFormulationAssistant;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage nvarchar(2048) = ERROR_MESSAGE();
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        RAISERROR(@ErrorMessage, 16, 1);
        RETURN;
    END CATCH;
END;
GO
