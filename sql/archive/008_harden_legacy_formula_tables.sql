/*
    Harden the four legacy PLM formula tables
    =========================================

    Scope:
      - Convert REAL formula/cost fields to exact decimal values.
      - Use decimal(10,4) except for three historical mg totals whose existing
        values require decimal(12,4).
      - Add stable surrogate keys to Formula_Header and Formula_Item.
      - Preserve the four-column revision business key as a UNIQUE contract.
      - Relate Formula_Item to Formula_Header through FormulaHeaderId.
      - Preserve the existing history-table primary keys.
      - Add nullable lineage/context columns to the history tables for new writes.

    This script deliberately does not rename legacy columns or drop existing data.
    Run the preflight section against a restored production copy first. The script
    throws before BEGIN TRAN when duplicate/orphan data prevents a safe relationship.
*/

USE [PLM_DEV];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* --------------------------------------------------------------------------
   Required objects
   -------------------------------------------------------------------------- */

IF OBJECT_ID(N'dbo.Formula_Header', N'U') IS NULL
    THROW 50001, 'Missing dbo.Formula_Header.', 1;

IF OBJECT_ID(N'dbo.Formula_Item', N'U') IS NULL
    THROW 50002, 'Missing dbo.Formula_Item.', 1;

IF OBJECT_ID(N'dbo.Formula_Item_Cost', N'U') IS NULL
    THROW 50003, 'Missing dbo.Formula_Item_Cost.', 1;

IF OBJECT_ID(N'dbo.Formula_Wt_and_Cost', N'U') IS NULL
    THROW 50004, 'Missing dbo.Formula_Wt_and_Cost.', 1;

/* --------------------------------------------------------------------------
   Decimal conversion preflight
   -------------------------------------------------------------------------- */

IF EXISTS
(
    SELECT 1
    FROM dbo.Formula_Header
    WHERE (FHRVNO IS NOT NULL AND TRY_CONVERT(decimal(10,4), FHRVNO) IS NULL)
       OR (FHRMM  IS NOT NULL AND TRY_CONVERT(decimal(10,4), FHRMM)  IS NULL)
       OR (FHOVRA IS NOT NULL AND TRY_CONVERT(decimal(10,4), FHOVRA) IS NULL)
       OR (FHSLDS IS NOT NULL AND TRY_CONVERT(decimal(10,4), FHSLDS) IS NULL)
       OR (FHWGHT IS NOT NULL AND TRY_CONVERT(decimal(10,4), FHWGHT) IS NULL)
       OR (FHCWAX IS NOT NULL AND TRY_CONVERT(decimal(10,4), FHCWAX) IS NULL)
)
    THROW 50005, 'Formula_Header contains a REAL value outside decimal(10,4).', 1;

IF EXISTS
(
    SELECT 1
    FROM dbo.Formula_Item
    WHERE (FMRVNO IS NOT NULL AND TRY_CONVERT(decimal(10,4), FMRVNO) IS NULL)
       OR (FMQUOT IS NOT NULL AND TRY_CONVERT(decimal(10,4), FMQUOT) IS NULL)
       OR (FMCOST IS NOT NULL AND TRY_CONVERT(decimal(10,4), FMCOST) IS NULL)
       OR (FMPTNC IS NOT NULL AND TRY_CONVERT(decimal(10,4), FMPTNC) IS NULL)
       OR (FMTIVE IS NOT NULL AND TRY_CONVERT(decimal(10,4), FMTIVE) IS NULL)
       OR (FMOVRA IS NOT NULL AND TRY_CONVERT(decimal(10,4), FMOVRA) IS NULL)
       OR (FMDLYD IS NOT NULL AND TRY_CONVERT(decimal(10,4), FMDLYD) IS NULL)
       OR (FMMGTB IS NOT NULL AND TRY_CONVERT(decimal(10,4), FMMGTB) IS NULL)
       OR (FMMGMO IS NOT NULL AND TRY_CONVERT(decimal(10,4), FMMGMO) IS NULL)
       OR (FMPRFM IS NOT NULL AND TRY_CONVERT(decimal(10,4), FMPRFM) IS NULL)
       OR (FMPCST IS NOT NULL AND TRY_CONVERT(decimal(10,4), FMPCST) IS NULL)
)
    THROW 50006, 'Formula_Item contains a REAL value outside decimal(10,4).', 1;

IF EXISTS
(
    SELECT 1
    FROM dbo.Formula_Item_Cost
    WHERE Item_Cost IS NOT NULL
      AND TRY_CONVERT(decimal(10,4), Item_Cost) IS NULL
)
    THROW 50007, 'Formula_Item_Cost contains a REAL value outside decimal(10,4).', 1;

IF EXISTS
(
    SELECT 1
    FROM dbo.Formula_Wt_and_Cost
    WHERE ([Total_Daily Dose/mg Wt] IS NOT NULL
           AND TRY_CONVERT(decimal(12,4), [Total_Daily Dose/mg Wt]) IS NULL)
       OR ([Total_mg/Unit Wt] IS NOT NULL
           AND TRY_CONVERT(decimal(12,4), [Total_mg/Unit Wt]) IS NULL)
       OR ([Total_mg/Unit Wt + MO%] IS NOT NULL
           AND TRY_CONVERT(decimal(12,4), [Total_mg/Unit Wt + MO%]) IS NULL)
       OR (TotalFormula IS NOT NULL
           AND TRY_CONVERT(decimal(10,4), TotalFormula) IS NULL)
       OR (Formula_Cost IS NOT NULL
           AND TRY_CONVERT(decimal(10,4), Formula_Cost) IS NULL)
)
    THROW 50008, 'Formula_Wt_and_Cost contains a REAL value outside its target decimal precision.', 1;

/* --------------------------------------------------------------------------
   Relationship/key preflight after revision values are rounded to four decimals
   -------------------------------------------------------------------------- */

IF EXISTS
(
    SELECT 1
    FROM dbo.Formula_Header
    GROUP BY
        FHMCU,
        FHPRNT,
        FHBLND,
        TRY_CONVERT(decimal(10,4), FHRVNO)
    HAVING COUNT_BIG(*) > 1
)
    THROW 50009, 'Duplicate Formula_Header legacy revision keys exist.', 1;

IF EXISTS
(
    SELECT 1
    FROM dbo.Formula_Item AS i
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.Formula_Header AS h
        WHERE h.FHMCU = i.FMMCU
          AND h.FHPRNT = i.FMPRNT
          AND h.FHBLND = i.FMBLND
          AND TRY_CONVERT(decimal(10,4), h.FHRVNO)
              = TRY_CONVERT(decimal(10,4), i.FMRVNO)
    )
)
    THROW 50010, 'Orphan Formula_Item rows do not match a Formula_Header revision.', 1;

IF EXISTS
(
    SELECT 1
    FROM dbo.Formula_Item
    GROUP BY
        FMMCU,
        FMPRNT,
        FMBLND,
        TRY_CONVERT(decimal(10,4), FMRVNO),
        FMRWNO
    HAVING COUNT_BIG(*) > 1
)
    THROW 50011, 'Duplicate Formula_Item line numbers exist within a revision.', 1;

/* --------------------------------------------------------------------------
   Transactional schema/data migration
   -------------------------------------------------------------------------- */

BEGIN TRY
    BEGIN TRAN;

    /* Exact numeric formula fields. */
    EXEC(N'ALTER TABLE dbo.Formula_Header ALTER COLUMN FHRVNO decimal(10,4) NOT NULL;');
    EXEC(N'ALTER TABLE dbo.Formula_Header ALTER COLUMN FHRMM  decimal(10,4) NULL;');
    EXEC(N'ALTER TABLE dbo.Formula_Header ALTER COLUMN FHOVRA decimal(10,4) NULL;');
    EXEC(N'ALTER TABLE dbo.Formula_Header ALTER COLUMN FHSLDS decimal(10,4) NULL;');
    EXEC(N'ALTER TABLE dbo.Formula_Header ALTER COLUMN FHWGHT decimal(10,4) NULL;');
    EXEC(N'ALTER TABLE dbo.Formula_Header ALTER COLUMN FHCWAX decimal(10,4) NULL;');

    EXEC(N'ALTER TABLE dbo.Formula_Item ALTER COLUMN FMRVNO decimal(10,4) NOT NULL;');
    EXEC(N'ALTER TABLE dbo.Formula_Item ALTER COLUMN FMQUOT decimal(10,4) NULL;');
    EXEC(N'ALTER TABLE dbo.Formula_Item ALTER COLUMN FMCOST decimal(10,4) NULL;');
    EXEC(N'ALTER TABLE dbo.Formula_Item ALTER COLUMN FMPTNC decimal(10,4) NULL;');
    EXEC(N'ALTER TABLE dbo.Formula_Item ALTER COLUMN FMTIVE decimal(10,4) NULL;');
    EXEC(N'ALTER TABLE dbo.Formula_Item ALTER COLUMN FMOVRA decimal(10,4) NULL;');
    EXEC(N'ALTER TABLE dbo.Formula_Item ALTER COLUMN FMDLYD decimal(10,4) NULL;');
    EXEC(N'ALTER TABLE dbo.Formula_Item ALTER COLUMN FMMGTB decimal(10,4) NULL;');
    EXEC(N'ALTER TABLE dbo.Formula_Item ALTER COLUMN FMMGMO decimal(10,4) NULL;');
    EXEC(N'ALTER TABLE dbo.Formula_Item ALTER COLUMN FMPRFM decimal(10,4) NULL;');
    EXEC(N'ALTER TABLE dbo.Formula_Item ALTER COLUMN FMPCST decimal(10,4) NULL;');

    EXEC(N'ALTER TABLE dbo.Formula_Item_Cost ALTER COLUMN Item_Cost decimal(10,4) NULL;');

    EXEC(N'ALTER TABLE dbo.Formula_Wt_and_Cost
           ALTER COLUMN [Total_Daily Dose/mg Wt] decimal(12,4) NULL;');
    EXEC(N'ALTER TABLE dbo.Formula_Wt_and_Cost
           ALTER COLUMN [Total_mg/Unit Wt] decimal(12,4) NULL;');
    EXEC(N'ALTER TABLE dbo.Formula_Wt_and_Cost
           ALTER COLUMN [Total_mg/Unit Wt + MO%] decimal(12,4) NULL;');
    EXEC(N'ALTER TABLE dbo.Formula_Wt_and_Cost
           ALTER COLUMN TotalFormula decimal(10,4) NULL;');
    EXEC(N'ALTER TABLE dbo.Formula_Wt_and_Cost
           ALTER COLUMN Formula_Cost decimal(10,4) NULL;');

    /* Stable identities and optimistic concurrency for the two CRUD tables. */
    IF COL_LENGTH(N'dbo.Formula_Header', N'FormulaHeaderId') IS NULL
        EXEC(N'ALTER TABLE dbo.Formula_Header
               ADD FormulaHeaderId bigint IDENTITY(1,1) NOT NULL;');

    IF COL_LENGTH(N'dbo.Formula_Header', N'CreatedAtUtc') IS NULL
        EXEC(N'ALTER TABLE dbo.Formula_Header
               ADD CreatedAtUtc datetime2(3) NOT NULL
                   CONSTRAINT DF_Formula_Header_CreatedAtUtc DEFAULT SYSUTCDATETIME()
                   WITH VALUES;');

    IF COL_LENGTH(N'dbo.Formula_Header', N'UpdatedAtUtc') IS NULL
        EXEC(N'ALTER TABLE dbo.Formula_Header
               ADD UpdatedAtUtc datetime2(3) NOT NULL
                   CONSTRAINT DF_Formula_Header_UpdatedAtUtc DEFAULT SYSUTCDATETIME()
                   WITH VALUES;');

    IF COL_LENGTH(N'dbo.Formula_Header', N'RowVersion') IS NULL
        EXEC(N'ALTER TABLE dbo.Formula_Header ADD RowVersion rowversion NOT NULL;');

    IF COL_LENGTH(N'dbo.Formula_Item', N'FormulaItemId') IS NULL
        EXEC(N'ALTER TABLE dbo.Formula_Item
               ADD FormulaItemId bigint IDENTITY(1,1) NOT NULL;');

    IF COL_LENGTH(N'dbo.Formula_Item', N'FormulaHeaderId') IS NULL
        EXEC(N'ALTER TABLE dbo.Formula_Item ADD FormulaHeaderId bigint NULL;');

    IF COL_LENGTH(N'dbo.Formula_Item', N'CreatedAtUtc') IS NULL
        EXEC(N'ALTER TABLE dbo.Formula_Item
               ADD CreatedAtUtc datetime2(3) NOT NULL
                   CONSTRAINT DF_Formula_Item_CreatedAtUtc DEFAULT SYSUTCDATETIME()
                   WITH VALUES;');

    IF COL_LENGTH(N'dbo.Formula_Item', N'UpdatedAtUtc') IS NULL
        EXEC(N'ALTER TABLE dbo.Formula_Item
               ADD UpdatedAtUtc datetime2(3) NOT NULL
                   CONSTRAINT DF_Formula_Item_UpdatedAtUtc DEFAULT SYSUTCDATETIME()
                   WITH VALUES;');

    IF COL_LENGTH(N'dbo.Formula_Item', N'RowVersion') IS NULL
        EXEC(N'ALTER TABLE dbo.Formula_Item ADD RowVersion rowversion NOT NULL;');

    /* Populate the new relationship from the proven legacy revision key. */
    EXEC(N'
        UPDATE i
        SET FormulaHeaderId = h.FormulaHeaderId
        FROM dbo.Formula_Item AS i
        JOIN dbo.Formula_Header AS h
          ON h.FHMCU = i.FMMCU
         AND h.FHPRNT = i.FMPRNT
         AND h.FHBLND = i.FMBLND
         AND h.FHRVNO = i.FMRVNO
        WHERE i.FormulaHeaderId IS NULL;
    ');

    /* Dynamic SQL avoids compile-time binding when this run created the column. */
    EXEC(N'
        IF EXISTS
        (
            SELECT 1
            FROM dbo.Formula_Item
            WHERE FormulaHeaderId IS NULL
        )
            THROW 50012,
                  ''FormulaHeaderId backfill left orphan Formula_Item rows.'',
                  1;
    ');

    EXEC(N'ALTER TABLE dbo.Formula_Item
           ALTER COLUMN FormulaHeaderId bigint NOT NULL;');

    /* Primary and uniqueness contracts. */
    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.key_constraints
        WHERE parent_object_id = OBJECT_ID(N'dbo.Formula_Header')
          AND type = N'PK'
    )
        EXEC(N'ALTER TABLE dbo.Formula_Header
               ADD CONSTRAINT PK_Formula_Header
               PRIMARY KEY CLUSTERED (FormulaHeaderId);');

    IF EXISTS
    (
        SELECT 1
        FROM sys.key_constraints AS kc
        WHERE kc.parent_object_id = OBJECT_ID(N'dbo.Formula_Header')
          AND kc.type = N'PK'
          AND NOT EXISTS
          (
              SELECT 1
              FROM sys.index_columns AS ic
              JOIN sys.columns AS c
                ON c.object_id = ic.object_id
               AND c.column_id = ic.column_id
              WHERE ic.object_id = kc.parent_object_id
                AND ic.index_id = kc.unique_index_id
              GROUP BY ic.object_id, ic.index_id
              HAVING COUNT_BIG(*) = 1
                 AND MAX(c.name) = N'FormulaHeaderId'
          )
    )
        THROW 50013,
              'Formula_Header has an unexpected primary key; expected FormulaHeaderId only.',
              1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.key_constraints
        WHERE parent_object_id = OBJECT_ID(N'dbo.Formula_Item')
          AND type = N'PK'
    )
        EXEC(N'ALTER TABLE dbo.Formula_Item
               ADD CONSTRAINT PK_Formula_Item
               PRIMARY KEY CLUSTERED (FormulaItemId);');

    IF EXISTS
    (
        SELECT 1
        FROM sys.key_constraints AS kc
        WHERE kc.parent_object_id = OBJECT_ID(N'dbo.Formula_Item')
          AND kc.type = N'PK'
          AND NOT EXISTS
          (
              SELECT 1
              FROM sys.index_columns AS ic
              JOIN sys.columns AS c
                ON c.object_id = ic.object_id
               AND c.column_id = ic.column_id
              WHERE ic.object_id = kc.parent_object_id
                AND ic.index_id = kc.unique_index_id
              GROUP BY ic.object_id, ic.index_id
              HAVING COUNT_BIG(*) = 1
                 AND MAX(c.name) = N'FormulaItemId'
          )
    )
        THROW 50014,
              'Formula_Item has an unexpected primary key; expected FormulaItemId only.',
              1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.key_constraints
        WHERE parent_object_id = OBJECT_ID(N'dbo.Formula_Header')
          AND name = N'UQ_Formula_Header_Revision'
    )
        EXEC(N'ALTER TABLE dbo.Formula_Header
               ADD CONSTRAINT UQ_Formula_Header_Revision
               UNIQUE (FHMCU, FHPRNT, FHBLND, FHRVNO);');

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.key_constraints
        WHERE parent_object_id = OBJECT_ID(N'dbo.Formula_Item')
          AND name = N'UQ_Formula_Item_HeaderLine'
    )
        EXEC(N'ALTER TABLE dbo.Formula_Item
               ADD CONSTRAINT UQ_Formula_Item_HeaderLine
               UNIQUE (FormulaHeaderId, FMRWNO);');

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.foreign_keys
        WHERE parent_object_id = OBJECT_ID(N'dbo.Formula_Item')
          AND name = N'FK_Formula_Item_Formula_Header'
    )
        EXEC(N'ALTER TABLE dbo.Formula_Item WITH CHECK
               ADD CONSTRAINT FK_Formula_Item_Formula_Header
               FOREIGN KEY (FormulaHeaderId)
               REFERENCES dbo.Formula_Header (FormulaHeaderId)
               ON DELETE CASCADE;');

    /*
        History lineage for new writes. Existing rows remain NULL when their exact
        branch/revision/cost method cannot be reconstructed without guessing.
        Existing history primary keys are intentionally preserved.
    */
    IF COL_LENGTH(N'dbo.Formula_Item_Cost', N'BranchCode') IS NULL
        EXEC(N'ALTER TABLE dbo.Formula_Item_Cost ADD BranchCode nvarchar(12) NULL;');

    IF COL_LENGTH(N'dbo.Formula_Item_Cost', N'CostMethodCode') IS NULL
        EXEC(N'ALTER TABLE dbo.Formula_Item_Cost ADD CostMethodCode varchar(2) NULL;');

    IF COL_LENGTH(N'dbo.Formula_Item_Cost', N'CapturedAtUtc') IS NULL
        EXEC(N'ALTER TABLE dbo.Formula_Item_Cost
               ADD CapturedAtUtc datetime2(3) NOT NULL
                   CONSTRAINT DF_Formula_Item_Cost_CapturedAtUtc
                   DEFAULT SYSUTCDATETIME() WITH VALUES;');

    IF COL_LENGTH(N'dbo.Formula_Wt_and_Cost', N'FormulaHeaderId') IS NULL
        EXEC(N'ALTER TABLE dbo.Formula_Wt_and_Cost ADD FormulaHeaderId bigint NULL;');

    IF COL_LENGTH(N'dbo.Formula_Wt_and_Cost', N'RevisionNumber') IS NULL
        EXEC(N'ALTER TABLE dbo.Formula_Wt_and_Cost
               ADD RevisionNumber decimal(10,4) NULL;');

    IF COL_LENGTH(N'dbo.Formula_Wt_and_Cost', N'WorkflowStatus') IS NULL
        EXEC(N'ALTER TABLE dbo.Formula_Wt_and_Cost
               ADD WorkflowStatus nvarchar(32) NULL;');

    IF COL_LENGTH(N'dbo.Formula_Wt_and_Cost', N'CalculationVersion') IS NULL
        EXEC(N'ALTER TABLE dbo.Formula_Wt_and_Cost
               ADD CalculationVersion varchar(32) NULL;');

    IF COL_LENGTH(N'dbo.Formula_Wt_and_Cost', N'CapturedAtUtc') IS NULL
        EXEC(N'ALTER TABLE dbo.Formula_Wt_and_Cost
               ADD CapturedAtUtc datetime2(3) NOT NULL
                   CONSTRAINT DF_Formula_Wt_and_Cost_CapturedAtUtc
                   DEFAULT SYSUTCDATETIME() WITH VALUES;');

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.foreign_keys
        WHERE parent_object_id = OBJECT_ID(N'dbo.Formula_Wt_and_Cost')
          AND name = N'FK_Formula_Wt_and_Cost_Formula_Header'
    )
        EXEC(N'ALTER TABLE dbo.Formula_Wt_and_Cost WITH CHECK
               ADD CONSTRAINT FK_Formula_Wt_and_Cost_Formula_Header
               FOREIGN KEY (FormulaHeaderId)
               REFERENCES dbo.Formula_Header (FormulaHeaderId)
               ON DELETE SET NULL;');

    COMMIT;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK;
    THROW;
END CATCH;
GO

/*
    Required follow-up before enabling writes:
      1. Update the Formula_Item_Cost job to populate BranchCode, CostMethodCode and
         CapturedAtUtc. Its legacy PK still permits only one row per date/item.
      2. Update the Formula_Wt_and_Cost job to populate FormulaHeaderId,
         RevisionNumber, WorkflowStatus, CalculationVersion and CapturedAtUtc.
      3. After historical backfill, decide whether each history table needs a new
         surrogate PK or a wider revision/branch-aware unique key.
      4. Application updates must set UpdatedAtUtc; RowVersion is automatic.
*/
