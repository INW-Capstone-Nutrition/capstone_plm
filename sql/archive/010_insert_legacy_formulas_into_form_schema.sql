/*
    Load the approved legacy formula tables into:

        form.formula
        form.formula_header
        form.formula_line

    Safety conventions
    ------------------
    1. This script previews only until @ApplyChanges is changed to 1.
    2. The three targets must be empty. This prevents accidental duplicate loads.
    3. A duplicate legacy header composite or an orphaned Formula_Item aborts the load.
    4. Active/Archive rows are grouped by branch + parent + blend because those values
       are stable after activation. Every other legacy header becomes its own formula.
       Development-to-Active lineage is intentionally not guessed.
    5. The complete calculation history remains in its legacy table. Formula-level
       calculation results are not stored on the authored revision.
    6. is_active is true only for Active/Copy. is_production is false for blank or
       provisional FHPRNT values (P-, B-, AG1 after removing spaces) and for
       Development/Review/Quote; all other latest revision combinations are true.

    Run the Alembic upgrade through revision b6f2c91e45ad before this script.
*/

USE [PLM_DEV];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ApplyChanges bit = 0; -- Change to 1 only after reviewing the preview result sets.
DECLARE @MigrationActor nvarchar(100) = N'LEGACY_MIGRATION';
DECLARE @MigrationDt datetime2(3) = SYSUTCDATETIME();

IF OBJECT_ID(N'[form].[formula]', N'U') IS NULL
    OR OBJECT_ID(N'[form].[formula_header]', N'U') IS NULL
    OR OBJECT_ID(N'[form].[formula_line]', N'U') IS NULL
BEGIN
    THROW 50001, 'The form schema is missing. Apply Alembic migration b6f2c91e45ad first.', 1;
END;

IF COL_LENGTH(N'form.formula', N'is_active') IS NULL
    OR COL_LENGTH(N'form.formula', N'is_production') IS NULL
    OR COL_LENGTH(N'form.formula', N'status') IS NOT NULL
    OR COL_LENGTH(N'form.formula', N'voided_dt') IS NOT NULL
BEGIN
    THROW 50002, 'form.formula does not match the approved ERD.', 1;
END;

IF EXISTS (SELECT 1 FROM [form].[formula])
    OR EXISTS (SELECT 1 FROM [form].[formula_header])
    OR EXISTS (SELECT 1 FROM [form].[formula_line])
BEGIN
    THROW 50003, 'Target formula tables must be empty before the legacy load.', 1;
END;

IF EXISTS (
    SELECT 1
    FROM [dbo].[Formula_Header]
    GROUP BY
        LTRIM(RTRIM([FHMCU])),
        LTRIM(RTRIM([FHPRNT])),
        LTRIM(RTRIM([FHBLND])),
        LTRIM(RTRIM([FHSTUS])),
        TRY_CONVERT(decimal(16, 8), [FHRVNO])
    HAVING COUNT_BIG(*) > 1
)
BEGIN
    THROW 50004, 'Duplicate legacy formula-header composite keys exist; resolve them before loading.', 1;
END;

;WITH normalized AS (
    SELECT
        NULLIF(LTRIM(RTRIM([FHMCU])), N'') AS branch_code,
        NULLIF(LTRIM(RTRIM([FHPRNT])), N'') AS parent_item_number,
        NULLIF(LTRIM(RTRIM([FHBLND])), N'') AS blend_item_number,
        COALESCE(NULLIF(LTRIM(RTRIM([FHNAME])), N''), N'Unnamed legacy formula')
            AS formula_name,
        COALESCE(TRY_CONVERT(decimal(16, 8), [FHRVNO]), CONVERT(decimal(16, 8), 0))
            AS revision_number,
        COALESCE(NULLIF(LTRIM(RTRIM([FHSTUS])), N''), N'Unknown') AS workflow_status,
        [FHCUSN],
        [FHCUSP],
        [FHUSER],
        [FHUNTY],
        [FHSIZE],
        [FHTYPM],
        [FHFMCT],
        [FHCLOR],
        [FHDOSE],
        [FHSRVG],
        [FHDLYD],
        [FHHOBN],
        [FHRMM],
        [FHOVRA],
        [FHMTCP],
        [FHSLDS],
        [FHWGHT],
        [FHCWAX],
        [FHCHNG],
        [FHECDV],
        [FHTRDJ],
        [FHNOTE],
        [FHADDL]
    FROM [dbo].[Formula_Header]
), grouped AS (
    SELECT
        *,
        CONVERT(
            nvarchar(450),
            CASE
                WHEN UPPER(workflow_status) IN (N'ACTIVE', N'ARCHIVE', N'ARCHIVED')
                    AND parent_item_number IS NOT NULL
                    AND blend_item_number IS NOT NULL THEN
                    CONCAT(
                        N'ACTIVE|', LEN(COALESCE(branch_code, N'')), N':', COALESCE(branch_code, N''),
                        N'|', LEN(COALESCE(parent_item_number, N'')), N':',
                        COALESCE(parent_item_number, N''),
                        N'|', LEN(COALESCE(blend_item_number, N'')), N':',
                        COALESCE(blend_item_number, N'')
                    )
                ELSE
                    CONCAT(
                        N'ROW|', LEN(COALESCE(branch_code, N'')), N':', COALESCE(branch_code, N''),
                        N'|', LEN(COALESCE(parent_item_number, N'')), N':',
                        COALESCE(parent_item_number, N''),
                        N'|', LEN(COALESCE(blend_item_number, N'')), N':',
                        COALESCE(blend_item_number, N''),
                        N'|', LEN(workflow_status), N':', workflow_status,
                        N'|', CONVERT(nvarchar(40), revision_number)
                    )
            END
        ) AS formula_group_key
    FROM normalized
)
SELECT
    IDENTITY(int, 1, 1) AS legacy_header_row_id,
    *,
    ROW_NUMBER() OVER (
        PARTITION BY formula_group_key
        ORDER BY revision_number, workflow_status, formula_name
    ) AS formula_sequence,
    ROW_NUMBER() OVER (
        PARTITION BY formula_group_key
        ORDER BY revision_number DESC, workflow_status DESC, formula_name DESC
    ) AS reverse_sequence
INTO #HeaderSource
FROM grouped;

IF EXISTS (
    SELECT 1
    FROM [dbo].[Formula_Item]
    WHERE NULLIF(LTRIM(RTRIM([FMCHLD])), N'') IS NULL
)
BEGIN
    THROW 50005, 'Formula_Item contains a blank child material number.', 1;
END;

IF EXISTS (
    SELECT 1
    FROM [dbo].[Formula_Item] AS item
    LEFT JOIN #HeaderSource AS header
        ON header.branch_code = NULLIF(LTRIM(RTRIM(item.[FMMCU])), N'')
       AND header.parent_item_number = NULLIF(LTRIM(RTRIM(item.[FMPRNT])), N'')
       AND header.blend_item_number = NULLIF(LTRIM(RTRIM(item.[FMBLND])), N'')
       AND header.workflow_status = COALESCE(
            NULLIF(LTRIM(RTRIM(item.[FMSTUS])), N''), N'Unknown'
       )
       AND header.revision_number = COALESCE(
            TRY_CONVERT(decimal(16, 8), item.[FMRVNO]), CONVERT(decimal(16, 8), 0)
       )
    WHERE header.legacy_header_row_id IS NULL
)
BEGIN
    THROW 50006, 'At least one Formula_Item cannot be matched to a Formula_Header.', 1;
END;

IF EXISTS (
    SELECT 1
    FROM [dbo].[Formula_Item] AS item
    INNER JOIN #HeaderSource AS header
        ON header.branch_code = NULLIF(LTRIM(RTRIM(item.[FMMCU])), N'')
       AND header.parent_item_number = NULLIF(LTRIM(RTRIM(item.[FMPRNT])), N'')
       AND header.blend_item_number = NULLIF(LTRIM(RTRIM(item.[FMBLND])), N'')
       AND header.workflow_status = COALESCE(
            NULLIF(LTRIM(RTRIM(item.[FMSTUS])), N''), N'Unknown'
       )
       AND header.revision_number = COALESCE(
            TRY_CONVERT(decimal(16, 8), item.[FMRVNO]), CONVERT(decimal(16, 8), 0)
       )
    WHERE NULLIF(LTRIM(RTRIM(item.[FMNAME])), N'') IS NOT NULL
      AND LTRIM(RTRIM(item.[FMNAME])) <> header.formula_name
)
BEGIN
    THROW 50007, 'Formula_Item.FMNAME disagrees with its matched Formula_Header.FHNAME.', 1;
END;

SELECT
    formula_group_key,
    MAX(CASE WHEN reverse_sequence = 1 THEN workflow_status END) AS latest_status,
    MAX(CASE WHEN reverse_sequence = 1 THEN parent_item_number END)
        AS latest_parent_item_number
INTO #FormulaGroupSource
FROM #HeaderSource
GROUP BY formula_group_key;

;WITH ranked AS (
    SELECT
        NULLIF(LTRIM(RTRIM([Branch])), '') AS branch_code,
        NULLIF(LTRIM(RTRIM([Parent])), '') AS parent_item_number,
        NULLIF(LTRIM(RTRIM([Blend])), '') AS blend_item_number,
        [RunDate],
        [Total_Daily Dose/mg Wt] AS total_daily_dose_mg,
        [Total_mg/Unit Wt] AS total_mg_per_unit,
        [Total_mg/Unit Wt + MO%] AS total_mg_per_unit_with_overage,
        [TotalFormula] AS total_formula_amount,
        [Raw_Materials] AS raw_material_count,
        [Formula_Cost] AS formula_cost,
        [Last_Active_Date] AS last_active_julian_date,
        ROW_NUMBER() OVER (
            PARTITION BY
                NULLIF(LTRIM(RTRIM([Branch])), ''),
                NULLIF(LTRIM(RTRIM([Parent])), ''),
                NULLIF(LTRIM(RTRIM([Blend])), '')
            ORDER BY [RunDate] DESC
        ) AS source_rank
    FROM [dbo].[Formula_Wt_and_Cost]
)
SELECT *
INTO #LatestCalculation
FROM ranked
WHERE source_rank = 1;

;WITH ranked AS (
    SELECT
        NULLIF(LTRIM(RTRIM([Item_Num])), N'') AS material_item_number,
        [RunDate],
        [Item_Cost],
        ROW_NUMBER() OVER (
            PARTITION BY NULLIF(LTRIM(RTRIM([Item_Num])), N'')
            ORDER BY [RunDate] DESC
        ) AS source_rank
    FROM [dbo].[Formula_Item_Cost]
)
SELECT *
INTO #LatestItemCost
FROM ranked
WHERE source_rank = 1;

SELECT
    NULLIF(LTRIM(RTRIM([IB_item_number])), N'') AS material_item_number,
    NULLIF(LTRIM(RTRIM([IB_branch])), N'') AS branch_code,
    MAX([vendor_name]) AS vendor_name,
    MAX([potency]) AS potency,
    MAX([potency_UOM]) AS potency_uom,
    MAX([trademark]) AS trademark,
    MAX([item_description_1]) AS item_description_1,
    MAX([item_description_2]) AS item_description_2,
    MAX([primary_UOM]) AS primary_uom,
    MAX([purch_UOM]) AS purchase_uom,
    MAX([last_in_cost_v2]) AS last_in_cost_v2,
    MAX([Category]) AS category,
    MAX([Item_Description]) AS item_description
INTO #UniqueAssistant
FROM [dbo].[Formulation_Assistant]
GROUP BY
    NULLIF(LTRIM(RTRIM([IB_item_number])), N''),
    NULLIF(LTRIM(RTRIM([IB_branch])), N'')
HAVING COUNT_BIG(*) = 1;

SELECT
    (SELECT COUNT_BIG(*) FROM #FormulaGroupSource) AS formulas_to_insert,
    (SELECT COUNT_BIG(*) FROM #HeaderSource) AS revisions_to_insert,
    (SELECT COUNT_BIG(*) FROM [dbo].[Formula_Item]) AS lines_to_insert,
    (
        SELECT COUNT_BIG(*)
        FROM #HeaderSource
        WHERE formula_group_key LIKE N'ROW|%'
    ) AS conservatively_ungrouped_revisions;

SELECT latest_status, COUNT_BIG(*) AS formula_count
FROM #FormulaGroupSource
GROUP BY latest_status
ORDER BY latest_status;

IF @ApplyChanges = 0
BEGIN
    PRINT 'Preview only. No rows inserted. Set @ApplyChanges = 1 after reviewing the counts.';
    RETURN;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    CREATE TABLE #FormulaMap (
        formula_group_key nvarchar(450) NOT NULL PRIMARY KEY,
        formula_id int NOT NULL UNIQUE
    );

    MERGE INTO [form].[formula] AS target
    USING #FormulaGroupSource AS source
        ON 1 = 0
    WHEN NOT MATCHED THEN
        INSERT (
            [record_origin],
            [is_voided],
            [is_active],
            [is_production],
            [created_by],
            [created_dt],
            [updated_by],
            [updated_dt]
        )
        VALUES (
            'LEGACY',
            CASE WHEN UPPER(source.latest_status) = N'DELETE' THEN 1 ELSE 0 END,
            CASE
                WHEN UPPER(LTRIM(RTRIM(source.latest_status))) IN (N'ACTIVE', N'COPY') THEN 1
                ELSE 0
            END,
            CASE
                WHEN source.latest_parent_item_number IS NULL THEN 0
                WHEN UPPER(
                    REPLACE(LTRIM(RTRIM(source.latest_parent_item_number)), N' ', N'')
                ) LIKE N'P-%' THEN 0
                WHEN UPPER(
                    REPLACE(LTRIM(RTRIM(source.latest_parent_item_number)), N' ', N'')
                ) LIKE N'B-%' THEN 0
                WHEN UPPER(
                    REPLACE(LTRIM(RTRIM(source.latest_parent_item_number)), N' ', N'')
                ) LIKE N'AG1%' THEN 0
                WHEN UPPER(LTRIM(RTRIM(source.latest_status)))
                    IN (N'DEVELOPMENT', N'REVIEW', N'QUOTE') THEN 0
                ELSE 1
            END,
            @MigrationActor,
            @MigrationDt,
            @MigrationActor,
            @MigrationDt
        )
    OUTPUT source.formula_group_key, inserted.formula_id
        INTO #FormulaMap (formula_group_key, formula_id);

    CREATE TABLE #HeaderMap (
        legacy_header_row_id int NOT NULL PRIMARY KEY,
        formula_header_id int NOT NULL UNIQUE
    );

    MERGE INTO [form].[formula_header] AS target
    USING (
        SELECT
            header.*,
            formula_map.formula_id
        FROM #HeaderSource AS header
        INNER JOIN #FormulaMap AS formula_map
            ON formula_map.formula_group_key = header.formula_group_key
    ) AS source
        ON 1 = 0
    WHEN NOT MATCHED THEN
        INSERT (
            [formula_id],
            [sequence],
            [revision_number],
            [workflow_status],
            [approval_dt],
            [approved_by],
            [formula_name],
            [branch_code],
            [parent_item_number],
            [blend_item_number],
            [customer_number],
            [customer_name],
            [customer_part_number],
            [revision_author],
            [unit_type],
            [size],
            [material_type],
            [category],
            [color],
            [dosage_per_unit],
            [serving_size],
            [daily_dose],
            [hobb_number],
            [raw_material_markup],
            [overage_percent],
            [empty_capsule_number],
            [solids],
            [weight],
            [carnuba_wax],
            [change_type],
            [change_number],
            [legacy_transaction_julian_date],
            [notes],
            [additional_information],
            [calculation_version],
            [version],
            [created_by],
            [created_dt],
            [updated_by],
            [updated_dt]
        )
        VALUES (
            source.formula_id,
            source.formula_sequence,
            source.revision_number,
            LEFT(source.workflow_status, 32),
            NULL,
            NULL,
            LEFT(source.formula_name, 60),
            LEFT(source.branch_code, 12),
            LEFT(source.parent_item_number, 64),
            LEFT(source.blend_item_number, 64),
            NULL,
            LEFT(NULLIF(LTRIM(RTRIM(source.[FHCUSN])), N''), 60),
            LEFT(NULLIF(LTRIM(RTRIM(source.[FHCUSP])), N''), 60),
            LEFT(NULLIF(LTRIM(RTRIM(source.[FHUSER])), N''), 30),
            LEFT(NULLIF(LTRIM(RTRIM(source.[FHUNTY])), N''), 30),
            LEFT(NULLIF(LTRIM(RTRIM(source.[FHSIZE])), N''), 30),
            LEFT(NULLIF(LTRIM(RTRIM(source.[FHTYPM])), N''), 30),
            LEFT(NULLIF(LTRIM(RTRIM(source.[FHFMCT])), N''), 30),
            LEFT(NULLIF(LTRIM(RTRIM(source.[FHCLOR])), N''), 30),
            source.[FHDOSE],
            source.[FHSRVG],
            source.[FHDLYD],
            LEFT(NULLIF(LTRIM(RTRIM(source.[FHHOBN])), N''), 30),
            TRY_CONVERT(decimal(16, 8), source.[FHRMM]),
            TRY_CONVERT(decimal(16, 8), source.[FHOVRA]),
            LEFT(NULLIF(LTRIM(RTRIM(source.[FHMTCP])), N''), 30),
            TRY_CONVERT(decimal(16, 8), source.[FHSLDS]),
            TRY_CONVERT(decimal(16, 8), source.[FHWGHT]),
            TRY_CONVERT(decimal(16, 8), source.[FHCWAX]),
            LEFT(NULLIF(LTRIM(RTRIM(source.[FHCHNG])), N''), 8),
            LEFT(NULLIF(LTRIM(RTRIM(source.[FHECDV])), N''), 32),
            TRY_CONVERT(bigint, source.[FHTRDJ]),
            source.[FHNOTE],
            source.[FHADDL],
            1,
            1,
            @MigrationActor,
            @MigrationDt,
            @MigrationActor,
            @MigrationDt
        )
    OUTPUT source.legacy_header_row_id, inserted.formula_header_id
        INTO #HeaderMap (legacy_header_row_id, formula_header_id);

    INSERT INTO [form].[formula_line] (
        [formula_header_id],
        [material_id],
        [line_number],
        [material_item_number],
        [material_branch_code],
        [material_description_snapshot],
        [material_category_snapshot],
        [trademark_snapshot],
        [selected_vendor_name_snapshot],
        [primary_uom_snapshot],
        [cost_uom_snapshot],
        [quoted_cost],
        [selected_unit_cost],
        [cost_snapshot_run_julian_date],
        [cost_source_code],
        [potency],
        [potency_uom],
        [active_percent],
        [overage_percent],
        [daily_dose_percent],
        [mg_per_capsule_percent],
        [mg_per_capsule_with_overage],
        [formula_percent],
        [cost_percent],
        [is_total_cost_percent],
        [is_total_formula_percent],
        [entered_by],
        [notes]
    )
    SELECT
        header_map.formula_header_id,
        material.[id],
        item.[FMRWNO],
        LEFT(NULLIF(LTRIM(RTRIM(item.[FMCHLD])), N''), 25),
        LEFT(header.branch_code, 12),
        LEFT(
            COALESCE(
                NULLIF(LTRIM(RTRIM(item.[FMDSCR])), N''),
                NULLIF(LTRIM(RTRIM(assistant.item_description)), N''),
                NULLIF(
                    LTRIM(RTRIM(CONCAT(
                        COALESCE(assistant.item_description_1, N''),
                        N' ',
                        COALESCE(assistant.item_description_2, N'')
                    ))),
                    N''
                )
            ),
            60
        ),
        LEFT(
            COALESCE(
                NULLIF(LTRIM(RTRIM(item.[FMGORY])), N''),
                NULLIF(LTRIM(RTRIM(assistant.category)), N'')
            ),
            30
        ),
        LEFT(
            COALESCE(
                NULLIF(LTRIM(RTRIM(item.[FMTMRK])), N''),
                NULLIF(LTRIM(RTRIM(assistant.trademark)), N'')
            ),
            64
        ),
        LEFT(
            COALESCE(
                NULLIF(LTRIM(RTRIM(item.[FMVEND])), N''),
                NULLIF(LTRIM(RTRIM(assistant.vendor_name)), N'')
            ),
            128
        ),
        LEFT(NULLIF(LTRIM(RTRIM(assistant.primary_uom)), N''), 8),
        LEFT(NULLIF(LTRIM(RTRIM(assistant.purchase_uom)), N''), 8),
        TRY_CONVERT(decimal(16, 8), item.[FMQUOT]),
        COALESCE(
            TRY_CONVERT(decimal(16, 8), item.[FMCOST]),
            TRY_CONVERT(decimal(16, 8), item_cost.[Item_Cost]),
            TRY_CONVERT(decimal(16, 8), assistant.last_in_cost_v2)
        ),
        CASE
            WHEN item.[FMCOST] IS NULL AND item_cost.[Item_Cost] IS NOT NULL
                THEN item_cost.[RunDate]
            ELSE NULL
        END,
        CASE
            WHEN item.[FMCOST] IS NOT NULL THEN N'FORMULA_ITEM'
            WHEN item_cost.[Item_Cost] IS NOT NULL THEN N'ITEM_COST'
            WHEN assistant.last_in_cost_v2 IS NOT NULL THEN N'ASSISTANT'
            ELSE NULL
        END,
        COALESCE(
            TRY_CONVERT(decimal(16, 8), item.[FMPTNC]),
            TRY_CONVERT(decimal(16, 8), assistant.potency)
        ),
        LEFT(
            COALESCE(
                NULLIF(LTRIM(RTRIM(item.[FMPTUM])), N''),
                NULLIF(LTRIM(RTRIM(assistant.potency_uom)), N'')
            ),
            8
        ),
        TRY_CONVERT(decimal(16, 8), item.[FMTIVE]),
        TRY_CONVERT(decimal(16, 8), item.[FMOVRA]),
        TRY_CONVERT(decimal(16, 8), item.[FMDLYD]),
        TRY_CONVERT(decimal(16, 8), item.[FMMGTB]),
        TRY_CONVERT(decimal(16, 8), item.[FMMGMO]),
        TRY_CONVERT(decimal(16, 8), item.[FMPRFM]),
        TRY_CONVERT(decimal(16, 8), item.[FMPCST]),
        CASE
            WHEN UPPER(LTRIM(RTRIM(COALESCE(item.[FMPRNC], N'')))) IN (N'Y', N'1', N'T')
                THEN 1
            ELSE 0
        END,
        CASE
            WHEN UPPER(LTRIM(RTRIM(COALESCE(item.[FMPRNV], N'')))) IN (N'Y', N'1', N'T')
                THEN 1
            ELSE 0
        END,
        LEFT(NULLIF(LTRIM(RTRIM(item.[FMUSER])), N''), 30),
        item.[FMNOTE]
    FROM [dbo].[Formula_Item] AS item
    INNER JOIN #HeaderSource AS header
        ON header.branch_code = NULLIF(LTRIM(RTRIM(item.[FMMCU])), N'')
       AND header.parent_item_number = NULLIF(LTRIM(RTRIM(item.[FMPRNT])), N'')
       AND header.blend_item_number = NULLIF(LTRIM(RTRIM(item.[FMBLND])), N'')
       AND header.workflow_status = COALESCE(
            NULLIF(LTRIM(RTRIM(item.[FMSTUS])), N''), N'Unknown'
       )
       AND header.revision_number = COALESCE(
            TRY_CONVERT(decimal(16, 8), item.[FMRVNO]), CONVERT(decimal(16, 8), 0)
       )
    INNER JOIN #HeaderMap AS header_map
        ON header_map.legacy_header_row_id = header.legacy_header_row_id
    LEFT JOIN #LatestItemCost AS item_cost
        ON item_cost.material_item_number = NULLIF(LTRIM(RTRIM(item.[FMCHLD])), N'')
    LEFT JOIN #UniqueAssistant AS assistant
        ON assistant.material_item_number = NULLIF(LTRIM(RTRIM(item.[FMCHLD])), N'')
       AND assistant.branch_code = header.branch_code
    LEFT JOIN [dbo].[material] AS material
        ON NULLIF(LTRIM(RTRIM(material.[item_number])), N'') =
            NULLIF(LTRIM(RTRIM(item.[FMCHLD])), N'');

    IF (SELECT COUNT_BIG(*) FROM [form].[formula])
        <> (SELECT COUNT_BIG(*) FROM #FormulaGroupSource)
        OR (SELECT COUNT_BIG(*) FROM [form].[formula_header])
        <> (SELECT COUNT_BIG(*) FROM #HeaderSource)
        OR (SELECT COUNT_BIG(*) FROM [form].[formula_line])
        <> (SELECT COUNT_BIG(*) FROM [dbo].[Formula_Item])
    BEGIN
        THROW 50008, 'Inserted row counts do not match the staged source counts.', 1;
    END;

    COMMIT TRANSACTION;

    SELECT
        (SELECT COUNT_BIG(*) FROM [form].[formula]) AS inserted_formulas,
        (SELECT COUNT_BIG(*) FROM [form].[formula_header]) AS inserted_headers,
        (SELECT COUNT_BIG(*) FROM [form].[formula_line]) AS inserted_lines;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
