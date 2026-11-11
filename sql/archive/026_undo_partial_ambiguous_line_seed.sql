/*
  Restore PLM_DEV.form.formula_line to its empty state before the full migration.
  This guarded reversal applies only to the 180-row partial seed in script 025.
  No PLM or dbo snapshot writes.
*/
USE [PLM_DEV];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    IF (SELECT COUNT_BIG(*) FROM [form].[formula_line]) <> 180
       OR (SELECT COUNT(DISTINCT formula_header_id) FROM [form].[formula_line]) <> 10
       OR EXISTS (SELECT 1 FROM [form].[formula_review_issue]
                  WHERE formula_line_id IS NOT NULL)
        THROW 50021,N'Partial seed no longer has its verified 180-row shape; reversal stopped.',1;

    DELETE FROM [form].[formula_line];
    IF @@ROWCOUNT <> 180
        THROW 50022,N'Partial seed reversal count differed from 180.',1;
    COMMIT TRANSACTION;
    SELECT COUNT_BIG(*) AS remaining_formula_lines FROM [form].[formula_line];
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
