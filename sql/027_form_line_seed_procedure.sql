/*
  PLM_DEV only. Seed lines using the owner's exact five-column source linkage.
  Name and status-ignored matches are never used. Missing branch, parent, or
  blend lines and exact-key orphans are excluded. Every exact target header
  receives a copy of the source line, including source duplicate rows.

  Source-only fields are copied directly. Material, assistant, and item-cost
  enrichment is intentionally deferred. Blank FMCHLD is stored as N'' because
  form.formula_line.material_item_number is NOT NULL.
  Requires form.formula_line.potency numeric(18,8) (migration 52d91f6c80ab).

  EXEC form.line_seed @PreviewOnly=1; -- counts only
  EXEC form.line_seed;                -- replace target lines using current headers
*/
USE [PLM_DEV];
GO
CREATE OR ALTER PROCEDURE [form].[line_seed]
    @PreviewOnly bit = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @EligibleLines bigint,
            @MatchedSourceLines bigint,
            @ExpectedTargetRows bigint,
            @BlankChildSourceLines bigint,
            @InsertedRows bigint;

    IF NOT EXISTS (SELECT 1 FROM [form].[formula_header])
        THROW 50100,N'form.formula_header is empty; seed headers first.',1;

    SELECT @EligibleLines=COUNT_BIG(*)
    FROM [dbo].[Formula_Item] AS i
    WHERE NULLIF(LTRIM(RTRIM(i.FMMCU)),N'') IS NOT NULL
      AND NULLIF(LTRIM(RTRIM(i.FMPRNT)),N'') IS NOT NULL
      AND NULLIF(LTRIM(RTRIM(i.FMBLND)),N'') IS NOT NULL;

    SELECT @MatchedSourceLines=COUNT_BIG(*),
           @BlankChildSourceLines=SUM(CASE WHEN NULLIF(LTRIM(RTRIM(i.FMCHLD)),N'') IS NULL
                                           THEN CONVERT(bigint,1) ELSE 0 END)
    FROM [dbo].[Formula_Item] AS i
    WHERE NULLIF(LTRIM(RTRIM(i.FMMCU)),N'') IS NOT NULL
      AND NULLIF(LTRIM(RTRIM(i.FMPRNT)),N'') IS NOT NULL
      AND NULLIF(LTRIM(RTRIM(i.FMBLND)),N'') IS NOT NULL
      AND EXISTS (
          SELECT 1 FROM [form].[formula_header] AS h
          WHERE h.branch_code=i.FMMCU
            AND h.parent_item_number=i.FMPRNT
            AND h.blend_item_number=i.FMBLND
            AND h.workflow_status=i.FMSTUS
            AND h.revision_number=i.FMRVNO
      );

    SELECT @ExpectedTargetRows=COUNT_BIG(*)
    FROM [dbo].[Formula_Item] AS i
    JOIN [form].[formula_header] AS h
      ON h.branch_code=i.FMMCU
     AND h.parent_item_number=i.FMPRNT
     AND h.blend_item_number=i.FMBLND
     AND h.workflow_status=i.FMSTUS
     AND h.revision_number=i.FMRVNO
    WHERE NULLIF(LTRIM(RTRIM(i.FMMCU)),N'') IS NOT NULL
      AND NULLIF(LTRIM(RTRIM(i.FMPRNT)),N'') IS NOT NULL
      AND NULLIF(LTRIM(RTRIM(i.FMBLND)),N'') IS NOT NULL;

    SELECT @EligibleLines AS eligible_source_lines,
           @MatchedSourceLines AS matched_source_lines,
           @EligibleLines-@MatchedSourceLines AS ignored_orphan_lines,
           @ExpectedTargetRows AS expected_target_rows,
           @BlankChildSourceLines AS blank_child_source_lines;

    IF @PreviewOnly=1 RETURN;

    IF @ExpectedTargetRows=0
        THROW 50101,N'No exact header-line links were found; line seed stopped.',1;

    IF EXISTS (
        SELECT 1 FROM [dbo].[Formula_Item] AS i
        WHERE NULLIF(LTRIM(RTRIM(i.FMMCU)),N'') IS NOT NULL
          AND NULLIF(LTRIM(RTRIM(i.FMPRNT)),N'') IS NOT NULL
          AND NULLIF(LTRIM(RTRIM(i.FMBLND)),N'') IS NOT NULL
          AND EXISTS (SELECT 1 FROM [form].[formula_header] AS h
                      WHERE h.branch_code=i.FMMCU
                        AND h.parent_item_number=i.FMPRNT
                        AND h.blend_item_number=i.FMBLND
                        AND h.workflow_status=i.FMSTUS
                        AND h.revision_number=i.FMRVNO)
          AND (i.FMRWNO IS NULL
               OR LEN(LTRIM(RTRIM(i.FMCHLD)))>25
               OR (i.FMQUOT IS NOT NULL AND TRY_CONVERT(decimal(16,8),i.FMQUOT) IS NULL)
               OR (i.FMCOST IS NOT NULL AND TRY_CONVERT(decimal(16,8),i.FMCOST) IS NULL)
               OR (i.FMPTNC IS NOT NULL AND TRY_CONVERT(decimal(18,8),i.FMPTNC) IS NULL)
               OR (i.FMTIVE IS NOT NULL AND TRY_CONVERT(decimal(16,8),i.FMTIVE) IS NULL)
               OR (i.FMOVRA IS NOT NULL AND TRY_CONVERT(decimal(16,8),i.FMOVRA) IS NULL)
               OR (i.FMDLYD IS NOT NULL AND TRY_CONVERT(decimal(16,8),i.FMDLYD) IS NULL)
               OR (i.FMMGTB IS NOT NULL AND TRY_CONVERT(decimal(16,8),i.FMMGTB) IS NULL)
               OR (i.FMMGMO IS NOT NULL AND TRY_CONVERT(decimal(16,8),i.FMMGMO) IS NULL)
               OR (i.FMPRFM IS NOT NULL AND TRY_CONVERT(decimal(16,8),i.FMPRFM) IS NULL)
               OR (i.FMPCST IS NOT NULL AND TRY_CONVERT(decimal(16,8),i.FMPCST) IS NULL))
    )
        THROW 50102,N'A matched source line has a required-field or numeric conversion error.',1;

    IF EXISTS (SELECT 1 FROM [form].[formula_review_issue] WHERE formula_line_id IS NOT NULL)
        THROW 50103,N'Line-linked review issues must be handled before replacing lines.',1;

    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM [form].[formula_line];
        DBCC CHECKIDENT (N'form.formula_line', RESEED, 0) WITH NO_INFOMSGS;

        INSERT INTO [form].[formula_line] (
            formula_header_id,material_id,line_number,material_item_number,
            material_branch_code,material_description,
            material_category,trademark,selected_vendor_name,
            primary_uom,cost_uom,quoted_cost,selected_unit_cost,
            cost_run_julian_date,cost_source_code,potency,potency_uom,
            active_percent,overage_percent,daily_dose_percent,mg_per_capsule_percent,
            mg_per_capsule_with_overage,formula_percent,cost_percent,
            is_total_cost_percent,is_total_formula_percent,entered_by,notes
        )
        SELECT h.id,NULL,i.FMRWNO,
               LEFT(LTRIM(RTRIM(COALESCE(i.FMCHLD,N''))),25),
               LEFT(LTRIM(RTRIM(i.FMMCU)),12),
               LEFT(NULLIF(LTRIM(RTRIM(i.FMDSCR)),N''),60),
               LEFT(NULLIF(LTRIM(RTRIM(i.FMGORY)),N''),30),
               LEFT(NULLIF(LTRIM(RTRIM(i.FMTMRK)),N''),64),
               LEFT(NULLIF(LTRIM(RTRIM(i.FMVEND)),N''),128),
               NULL,NULL,
               TRY_CONVERT(decimal(16,8),i.FMQUOT),
               TRY_CONVERT(decimal(16,8),i.FMCOST),
               NULL,
               CASE WHEN i.FMCOST IS NOT NULL THEN N'FORMULA_ITEM' ELSE NULL END,
               TRY_CONVERT(decimal(18,8),i.FMPTNC),
               LEFT(NULLIF(LTRIM(RTRIM(i.FMPTUM)),N''),8),
               TRY_CONVERT(decimal(16,8),i.FMTIVE),
               TRY_CONVERT(decimal(16,8),i.FMOVRA),
               TRY_CONVERT(decimal(16,8),i.FMDLYD),
               TRY_CONVERT(decimal(16,8),i.FMMGTB),
               TRY_CONVERT(decimal(16,8),i.FMMGMO),
               TRY_CONVERT(decimal(16,8),i.FMPRFM),
               TRY_CONVERT(decimal(16,8),i.FMPCST),
               CASE WHEN UPPER(LTRIM(RTRIM(COALESCE(i.FMPRNC,N'')))) IN (N'Y',N'1',N'T')
                    THEN 1 ELSE 0 END,
               CASE WHEN UPPER(LTRIM(RTRIM(COALESCE(i.FMPRNV,N'')))) IN (N'Y',N'1',N'T')
                    THEN 1 ELSE 0 END,
               LEFT(NULLIF(LTRIM(RTRIM(i.FMUSER)),N''),30),
               i.FMNOTE
        FROM [dbo].[Formula_Item] AS i
        JOIN [form].[formula_header] AS h
          ON h.branch_code=i.FMMCU
         AND h.parent_item_number=i.FMPRNT
         AND h.blend_item_number=i.FMBLND
         AND h.workflow_status=i.FMSTUS
         AND h.revision_number=i.FMRVNO
        WHERE NULLIF(LTRIM(RTRIM(i.FMMCU)),N'') IS NOT NULL
          AND NULLIF(LTRIM(RTRIM(i.FMPRNT)),N'') IS NOT NULL
          AND NULLIF(LTRIM(RTRIM(i.FMBLND)),N'') IS NOT NULL;

        SET @InsertedRows=@@ROWCOUNT;
        IF @InsertedRows<>@ExpectedTargetRows
            THROW 50104,N'Inserted line count differs from exact-link projection.',1;
        COMMIT TRANSACTION;
        SELECT @InsertedRows AS inserted_formula_lines;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
