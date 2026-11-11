/*
  SUPERSEDED. The earlier 180-row partial insert was reversed by script 026.
  Use form.formula_and_header_seed for the full one-pass rebuild. This script
  cannot apply changes even if @ApplyChanges is set to 1.

  PLM_DEV only: copy every eligible EXACT_KEY_AMBIGUOUS source line to each
  matching form.formula_header. No Julian-date cutoff or status relaxation.
  All source rows, including exact duplicates, were retained in the preview.
*/
USE [PLM_DEV];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @ApplyChanges bit = 0;

WITH header_keys AS (
    SELECT NULLIF(LTRIM(RTRIM(branch_code)),N'') AS branch_code,
           NULLIF(LTRIM(RTRIM(parent_item_number)),N'') AS parent_item_number,
           NULLIF(LTRIM(RTRIM(blend_item_number)),N'') AS blend_item_number,
           UPPER(COALESCE(NULLIF(LTRIM(RTRIM(workflow_status)),N''),N'UNKNOWN')) AS workflow_status,
           CONVERT(decimal(10,4),revision_number) AS revision_number,
           COUNT_BIG(*) AS header_count
    FROM [form].[formula_header]
    GROUP BY NULLIF(LTRIM(RTRIM(branch_code)),N''),
             NULLIF(LTRIM(RTRIM(parent_item_number)),N''),
             NULLIF(LTRIM(RTRIM(blend_item_number)),N''),
             UPPER(COALESCE(NULLIF(LTRIM(RTRIM(workflow_status)),N''),N'UNKNOWN')),
             CONVERT(decimal(10,4),revision_number)
    HAVING COUNT_BIG(*)>1
), header_names AS (
    SELECT NULLIF(LTRIM(RTRIM(branch_code)),N'') AS branch_code,
           NULLIF(LTRIM(RTRIM(parent_item_number)),N'') AS parent_item_number,
           NULLIF(LTRIM(RTRIM(blend_item_number)),N'') AS blend_item_number,
           UPPER(COALESCE(NULLIF(LTRIM(RTRIM(workflow_status)),N''),N'UNKNOWN')) AS workflow_status,
           CONVERT(decimal(10,4),revision_number) AS revision_number,
           UPPER(NULLIF(LTRIM(RTRIM(formula_name)),N'')) AS formula_name,
           COUNT_BIG(*) AS header_count
    FROM [form].[formula_header]
    GROUP BY NULLIF(LTRIM(RTRIM(branch_code)),N''),
             NULLIF(LTRIM(RTRIM(parent_item_number)),N''),
             NULLIF(LTRIM(RTRIM(blend_item_number)),N''),
             UPPER(COALESCE(NULLIF(LTRIM(RTRIM(workflow_status)),N''),N'UNKNOWN')),
             CONVERT(decimal(10,4),revision_number),
             UPPER(NULLIF(LTRIM(RTRIM(formula_name)),N''))
)
SELECT IDENTITY(int,1,1) AS source_row_id,item.*
INTO #SourceLines
FROM [dbo].[Formula_Item] AS item
JOIN header_keys AS hk
  ON ISNULL(hk.branch_code,N'')=ISNULL(NULLIF(LTRIM(RTRIM(item.FMMCU)),N''),N'')
 AND hk.parent_item_number=NULLIF(LTRIM(RTRIM(item.FMPRNT)),N'')
 AND hk.blend_item_number=NULLIF(LTRIM(RTRIM(item.FMBLND)),N'')
 AND hk.workflow_status=UPPER(COALESCE(NULLIF(LTRIM(RTRIM(item.FMSTUS)),N''),N'UNKNOWN'))
 AND hk.revision_number=COALESCE(TRY_CONVERT(decimal(10,4),item.FMRVNO),0)
LEFT JOIN header_names AS hn
  ON ISNULL(hn.branch_code,N'')=ISNULL(NULLIF(LTRIM(RTRIM(item.FMMCU)),N''),N'')
 AND hn.parent_item_number=NULLIF(LTRIM(RTRIM(item.FMPRNT)),N'')
 AND hn.blend_item_number=NULLIF(LTRIM(RTRIM(item.FMBLND)),N'')
 AND hn.workflow_status=UPPER(COALESCE(NULLIF(LTRIM(RTRIM(item.FMSTUS)),N''),N'UNKNOWN'))
 AND hn.revision_number=COALESCE(TRY_CONVERT(decimal(10,4),item.FMRVNO),0)
 AND hn.formula_name=UPPER(NULLIF(LTRIM(RTRIM(item.FMNAME)),N''))
WHERE NULLIF(LTRIM(RTRIM(item.FMMCU)),N'') IS NOT NULL
  AND NULLIF(LTRIM(RTRIM(item.FMPRNT)),N'') IS NOT NULL
  AND NULLIF(LTRIM(RTRIM(item.FMBLND)),N'') IS NOT NULL
  AND ISNULL(hn.header_count,0)<>1;

SELECT s.source_row_id,h.formula_header_id
INTO #Stage
FROM #SourceLines AS s
JOIN [form].[formula_header] AS h
  ON ISNULL(NULLIF(LTRIM(RTRIM(h.branch_code)),N''),N'')=ISNULL(NULLIF(LTRIM(RTRIM(s.FMMCU)),N''),N'')
 AND NULLIF(LTRIM(RTRIM(h.parent_item_number)),N'')=NULLIF(LTRIM(RTRIM(s.FMPRNT)),N'')
 AND NULLIF(LTRIM(RTRIM(h.blend_item_number)),N'')=NULLIF(LTRIM(RTRIM(s.FMBLND)),N'')
 AND UPPER(COALESCE(NULLIF(LTRIM(RTRIM(h.workflow_status)),N''),N'UNKNOWN'))
     =UPPER(COALESCE(NULLIF(LTRIM(RTRIM(s.FMSTUS)),N''),N'UNKNOWN'))
 AND CONVERT(decimal(10,4),h.revision_number)
     =COALESCE(TRY_CONVERT(decimal(10,4),s.FMRVNO),0);

SELECT (SELECT COUNT_BIG(*) FROM #SourceLines) AS source_line_rows,
       (SELECT COUNT_BIG(*) FROM #Stage) AS proposed_target_rows,
       (SELECT COUNT_BIG(*) FROM #SourceLines
        WHERE FMRWNO IS NULL OR NULLIF(LTRIM(RTRIM(FMCHLD)),N'') IS NULL
           OR LEN(LTRIM(RTRIM(FMCHLD)))>25) AS invalid_required_values,
       (SELECT COUNT_BIG(*) FROM [form].[formula_line]) AS current_target_rows;

IF @ApplyChanges=0 RETURN;
THROW 50014,N'Partial seed was superseded by the full migration procedure.',1;

BEGIN TRY
    BEGIN TRANSACTION;
    IF EXISTS (SELECT 1 FROM [form].[formula_line])
        THROW 50011,N'form.formula_line is no longer empty; seed stopped.',1;
    IF (SELECT COUNT_BIG(*) FROM #SourceLines)<>90
       OR (SELECT COUNT_BIG(*) FROM #Stage)<>180
       OR EXISTS (SELECT 1 FROM #SourceLines
                  WHERE FMRWNO IS NULL OR NULLIF(LTRIM(RTRIM(FMCHLD)),N'') IS NULL
                     OR LEN(LTRIM(RTRIM(FMCHLD)))>25)
        THROW 50012,N'Staged line counts or required values changed; seed stopped.',1;

    INSERT INTO [form].[formula_line] (
        formula_header_id,material_id,line_number,material_item_number,
        material_branch_code,material_description_snapshot,material_category_snapshot,
        trademark_snapshot,selected_vendor_name_snapshot,primary_uom_snapshot,
        cost_uom_snapshot,quoted_cost,selected_unit_cost,cost_snapshot_run_julian_date,
        cost_source_code,potency,potency_uom,active_percent,overage_percent,
        daily_dose_percent,mg_per_capsule_percent,mg_per_capsule_with_overage,
        formula_percent,cost_percent,is_total_cost_percent,is_total_formula_percent,
        entered_by,notes
    )
    SELECT p.formula_header_id,NULL,s.FMRWNO,LTRIM(RTRIM(s.FMCHLD)),
           LEFT(NULLIF(LTRIM(RTRIM(s.FMMCU)),N''),12),
           LEFT(NULLIF(LTRIM(RTRIM(s.FMDSCR)),N''),60),
           LEFT(NULLIF(LTRIM(RTRIM(s.FMGORY)),N''),30),
           LEFT(NULLIF(LTRIM(RTRIM(s.FMTMRK)),N''),64),
           LEFT(NULLIF(LTRIM(RTRIM(s.FMVEND)),N''),128),
           NULL,NULL,
           TRY_CONVERT(decimal(16,8),s.FMQUOT),
           TRY_CONVERT(decimal(16,8),s.FMCOST),
           NULL,
           CASE WHEN s.FMCOST IS NOT NULL THEN N'FORMULA_ITEM' ELSE NULL END,
           TRY_CONVERT(decimal(16,8),s.FMPTNC),
           LEFT(NULLIF(LTRIM(RTRIM(s.FMPTUM)),N''),8),
           TRY_CONVERT(decimal(16,8),s.FMTIVE),
           TRY_CONVERT(decimal(16,8),s.FMOVRA),
           TRY_CONVERT(decimal(16,8),s.FMDLYD),
           TRY_CONVERT(decimal(16,8),s.FMMGTB),
           TRY_CONVERT(decimal(16,8),s.FMMGMO),
           TRY_CONVERT(decimal(16,8),s.FMPRFM),
           TRY_CONVERT(decimal(16,8),s.FMPCST),
           CASE WHEN UPPER(LTRIM(RTRIM(COALESCE(s.FMPRNC,N'')))) IN (N'Y',N'1',N'T') THEN 1 ELSE 0 END,
           CASE WHEN UPPER(LTRIM(RTRIM(COALESCE(s.FMPRNV,N'')))) IN (N'Y',N'1',N'T') THEN 1 ELSE 0 END,
           LEFT(NULLIF(LTRIM(RTRIM(s.FMUSER)),N''),30),s.FMNOTE
    FROM #Stage AS p
    JOIN #SourceLines AS s ON s.source_row_id=p.source_row_id;

    IF @@ROWCOUNT<>180
        THROW 50013,N'Inserted line count did not match the staged count.',1;
    COMMIT TRANSACTION;
    SELECT COUNT_BIG(*) AS inserted_formula_lines FROM [form].[formula_line];
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO


