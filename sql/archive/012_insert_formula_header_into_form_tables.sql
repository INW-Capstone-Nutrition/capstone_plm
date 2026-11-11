/*
    HEADER-ONLY LEGACY MIGRATION

    Source:
        [PLM_DEV].[dbo].[Formula_Header] static snapshot

    Targets:
        [PLM_DEV].[form].[formula]
        [PLM_DEV].[form].[formula_header]
        [PLM_DEV].[form].[formula_review_issue]

    This script does not insert form.formula_line.

    REVIEW MODE IS THE DEFAULT:
        @ApplyChanges = 0 stages and displays the proposed result without inserting.
        Change @ApplyChanges to 1 only after approving the preview result sets.

    Legacy revision key:
        FHMCU + FHPRNT + FHBLND + FHSTUS + FHRVNO

    Duplicate preservation:
        legacy_duplicate_sequence is NULL for a unique legacy key. Every row in
        a duplicate-key group receives 1..n so no source row is discarded.

    Conservative formula-family grouping:
        1. Active/Archive/Archived rows with nonblank parent and blend values are
           grouped by FHMCU + FHPRNT + FHBLND.
        2. Every other Formula_Header row becomes its own formula with one revision.
        3. Development-to-Active lineage is not inferred.
        4. Copy is not grouped with Active/Archive without separate approval.

    Lifecycle classification from the latest revision in each proposed formula:
        is_voided = 1 for Delete, Void, or Voided.
        is_active = 1 only for Active or Copy.
        is_production = 0 when FHPRNT is blank, begins P-/B-/AG1 after removing
                        spaces, or FHSTUS is Development/Review/Quote.
        is_production = 1 for every other combination.
*/

USE [PLM_DEV];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ApplyChanges bit = 0; -- Set to 1 only after reviewing every result set.
DECLARE @ShowDetailedReview bit = 0; -- Set to 1 to display the large detail grids.
DECLARE @MigrationActor nvarchar(100) = N'LEGACY_MIGRATION';
DECLARE @MigrationDt datetime2(3) = SYSUTCDATETIME();

/* --------------------------------------------------------------------------
   Normalize source rows and construct the proposed formula grouping.
   -------------------------------------------------------------------------- */

DROP TABLE IF EXISTS #HeaderSource;
DROP TABLE IF EXISTS #FormulaGroupSource;
DROP TABLE IF EXISTS #DuplicateRevisionKey;

;WITH normalized AS (
    SELECT
        NULLIF(LTRIM(RTRIM([FHMCU])), N'') AS branch_code,
        NULLIF(LTRIM(RTRIM([FHPRNT])), N'') AS parent_item_number,
        NULLIF(LTRIM(RTRIM([FHBLND])), N'') AS blend_item_number,
        COALESCE(NULLIF(LTRIM(RTRIM([FHNAME])), N''), N'Unnamed legacy formula')
            AS formula_name,
        [FHNAME] AS legacy_formula_name,
        COALESCE(
            TRY_CONVERT(decimal(16, 8), [FHRVNO]),
            CONVERT(decimal(16, 8), 0)
        ) AS revision_number,
        COALESCE(NULLIF(LTRIM(RTRIM([FHSTUS])), N''), N'Unknown') AS workflow_status,
        UPPER(COALESCE(NULLIF(LTRIM(RTRIM([FHSTUS])), N''), N'UNKNOWN'))
            AS normalized_status,
        UPPER(REPLACE(COALESCE(LTRIM(RTRIM([FHPRNT])), N''), N' ', N''))
            AS compact_parent,
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
    FROM [PLM_DEV].[dbo].[Formula_Header]
), grouped AS (
    SELECT
        *,
        CONVERT(
            nvarchar(450),
            CASE
                WHEN normalized_status IN (N'ACTIVE', N'ARCHIVE', N'ARCHIVED')
                    AND parent_item_number IS NOT NULL
                    AND blend_item_number IS NOT NULL
                    THEN CONCAT(
                        N'ACTIVE|', LEN(COALESCE(branch_code, N'')), N':',
                        COALESCE(branch_code, N''),
                        N'|', LEN(parent_item_number), N':', parent_item_number,
                        N'|', LEN(blend_item_number), N':', blend_item_number
                    )
                ELSE CONCAT(
                    N'ROW|', LEN(COALESCE(branch_code, N'')), N':',
                    COALESCE(branch_code, N''),
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
    CONVERT(
        int,
        ROW_NUMBER() OVER (
            PARTITION BY formula_group_key
            ORDER BY revision_number, normalized_status, formula_name
        )
    ) AS formula_sequence,
    CONVERT(
        int,
        ROW_NUMBER() OVER (
            PARTITION BY formula_group_key
            ORDER BY revision_number DESC, normalized_status DESC, formula_name DESC
        )
    ) AS reverse_sequence
INTO #HeaderSource
FROM grouped;

ALTER TABLE #HeaderSource ADD
    legacy_duplicate_sequence smallint NULL,
    legacy_duplicate_count int NULL;

;WITH duplicate_ranking AS (
    SELECT
        legacy_header_row_id,
        COUNT(*) OVER (
            PARTITION BY
                branch_code,
                parent_item_number,
                blend_item_number,
                normalized_status,
                revision_number
        ) AS duplicate_count,
        ROW_NUMBER() OVER (
            PARTITION BY
                branch_code,
                parent_item_number,
                blend_item_number,
                normalized_status,
                revision_number
            ORDER BY
                formula_name,
                COALESCE(FHCUSN, N''),
                COALESCE(FHCUSP, N''),
                COALESCE(FHUSER, N''),
                COALESCE(FHTRDJ, 0),
                legacy_header_row_id
        ) AS duplicate_sequence
    FROM #HeaderSource
)
UPDATE header_source
SET
    legacy_duplicate_count = ranking.duplicate_count,
    legacy_duplicate_sequence = CASE
        WHEN ranking.duplicate_count > 1
            THEN CONVERT(smallint, ranking.duplicate_sequence)
        ELSE NULL
    END
FROM #HeaderSource AS header_source
INNER JOIN duplicate_ranking AS ranking
    ON ranking.legacy_header_row_id = header_source.legacy_header_row_id;

/* Stage duplicate five-part keys for review. All rows remain eligible to load. */
SELECT
    branch_code,
    parent_item_number,
    blend_item_number,
    normalized_status,
    revision_number,
    COUNT_BIG(*) AS duplicate_row_count,
    MIN(formula_name) AS first_formula_name,
    MAX(formula_name) AS last_formula_name
INTO #DuplicateRevisionKey
FROM #HeaderSource
GROUP BY
    branch_code,
    parent_item_number,
    blend_item_number,
    normalized_status,
    revision_number
HAVING COUNT_BIG(*) > 1;

;WITH group_summary AS (
    SELECT
        formula_group_key,
        COUNT_BIG(*) AS revision_count,
        MIN(revision_number) AS first_revision_number,
        MAX(revision_number) AS last_revision_number
    FROM #HeaderSource
    GROUP BY formula_group_key
), latest_revision AS (
    SELECT
        formula_group_key,
        normalized_status AS latest_status,
        parent_item_number AS latest_parent_item_number,
        formula_name AS latest_formula_name,
        branch_code AS latest_branch_code,
        blend_item_number AS latest_blend_item_number,
        compact_parent AS latest_compact_parent
    FROM #HeaderSource
    WHERE reverse_sequence = 1
)
SELECT
    summary.formula_group_key,
    latest.latest_status,
    latest.latest_parent_item_number,
    latest.latest_formula_name,
    latest.latest_branch_code,
    latest.latest_blend_item_number,
    summary.revision_count,
    summary.first_revision_number,
    summary.last_revision_number,
    CAST(
        CASE
            WHEN latest.latest_status IN (N'DELETE', N'VOID', N'VOIDED') THEN 1
            ELSE 0
        END AS bit
    ) AS proposed_is_voided,
    CAST(
        CASE
            WHEN latest.latest_status IN (N'ACTIVE', N'COPY') THEN 1
            ELSE 0
        END AS bit
    ) AS proposed_is_active,
    CAST(
        CASE
            WHEN latest.latest_parent_item_number IS NULL THEN 0
            WHEN latest.latest_compact_parent LIKE N'P-%' THEN 0
            WHEN latest.latest_compact_parent LIKE N'B-%' THEN 0
            WHEN latest.latest_compact_parent LIKE N'AG1%' THEN 0
            WHEN latest.latest_status IN (N'DEVELOPMENT', N'REVIEW', N'QUOTE') THEN 0
            ELSE 1
        END AS bit
    ) AS proposed_is_production
INTO #FormulaGroupSource
FROM group_summary AS summary
INNER JOIN latest_revision AS latest
    ON latest.formula_group_key = summary.formula_group_key;

CREATE TABLE #ReviewIssueSource (
    legacy_header_row_id int NOT NULL,
    formula_group_key nvarchar(450) NOT NULL,
    issue_code nvarchar(50) NOT NULL,
    severity nvarchar(20) NOT NULL,
    issue_detail nvarchar(1000) NULL
);

INSERT INTO #ReviewIssueSource (
    legacy_header_row_id,
    formula_group_key,
    issue_code,
    severity,
    issue_detail
)
SELECT
    header.legacy_header_row_id,
    header.formula_group_key,
    N'LEGACY_DUPLICATE_KEY',
    N'WARNING',
    CONCAT(
        N'The normalized legacy revision key occurs ',
        header.legacy_duplicate_count,
        N' times. This retained row has duplicate sequence ',
        header.legacy_duplicate_sequence,
        N'.'
    )
FROM #HeaderSource AS header
WHERE header.legacy_duplicate_sequence IS NOT NULL;

INSERT INTO #ReviewIssueSource (
    legacy_header_row_id,
    formula_group_key,
    issue_code,
    severity,
    issue_detail
)
SELECT
    header.legacy_header_row_id,
    header.formula_group_key,
    issue.issue_code,
    N'WARNING',
    issue.issue_detail
FROM #HeaderSource AS header
CROSS APPLY (
    VALUES
        (
            N'MISSING_BRANCH',
            CASE
                WHEN header.branch_code IS NULL
                    THEN N'The legacy Formula_Header row has no branch code.'
            END
        ),
        (
            N'MISSING_PARENT',
            CASE
                WHEN header.parent_item_number IS NULL
                    THEN N'The legacy Formula_Header row has no parent item number.'
            END
        ),
        (
            N'MISSING_BLEND',
            CASE
                WHEN header.blend_item_number IS NULL
                    THEN N'The legacy Formula_Header row has no blend item number.'
            END
        ),
        (
            N'MISSING_FORMULA_NAME',
            CASE
                WHEN NULLIF(LTRIM(RTRIM(header.legacy_formula_name)), N'') IS NULL
                    THEN N'The legacy Formula_Header row had no formula name; the migration used Unnamed legacy formula.'
            END
        )
) AS issue (issue_code, issue_detail)
WHERE issue.issue_detail IS NOT NULL;

INSERT INTO #ReviewIssueSource (
    legacy_header_row_id,
    formula_group_key,
    issue_code,
    severity,
    issue_detail
)
SELECT
    copy_row.legacy_header_row_id,
    copy_row.formula_group_key,
    N'POSSIBLE_COPY_LINEAGE',
    N'INFO',
    N'This Copy row shares branch, parent, and blend values with an Active/Archive formula family but was conservatively loaded as a separate formula.'
FROM #HeaderSource AS copy_row
WHERE copy_row.normalized_status = N'COPY'
  AND EXISTS (
        SELECT 1
        FROM #HeaderSource AS history
        WHERE history.normalized_status IN (N'ACTIVE', N'ARCHIVE', N'ARCHIVED')
          AND ISNULL(history.branch_code, N'') = ISNULL(copy_row.branch_code, N'')
          AND ISNULL(history.parent_item_number, N'') =
                ISNULL(copy_row.parent_item_number, N'')
          AND ISNULL(history.blend_item_number, N'') =
                ISNULL(copy_row.blend_item_number, N'')
    );

/* --------------------------------------------------------------------------
   Review result sets. No persistent data has been changed at this point.
   -------------------------------------------------------------------------- */

/* 1. Expected insert counts. */
SELECT
    (SELECT COUNT_BIG(*) FROM [PLM_DEV].[dbo].[Formula_Header]) AS source_header_rows,
    (SELECT COUNT_BIG(*) FROM #FormulaGroupSource) AS proposed_formula_rows,
    (SELECT COUNT_BIG(*) FROM #HeaderSource) AS proposed_revision_rows,
    (SELECT COUNT_BIG(*) FROM #DuplicateRevisionKey) AS duplicate_revision_key_groups,
    (
        SELECT COALESCE(SUM(duplicate_row_count - 1), 0)
        FROM #DuplicateRevisionKey
    ) AS excess_duplicate_rows,
    (
        SELECT COUNT_BIG(*)
        FROM #HeaderSource
        WHERE formula_group_key LIKE N'ROW|%'
    ) AS conservatively_ungrouped_revision_rows;

SELECT issue_code, severity, COUNT_BIG(*) AS proposed_review_issue_rows
FROM #ReviewIssueSource
GROUP BY issue_code, severity
ORDER BY severity DESC, issue_code;

IF @ShowDetailedReview = 1
BEGIN
/* 2. Duplicate composite-key groups: one row per duplicated five-part key. */
SELECT TOP (250)
    branch_code,
    parent_item_number,
    blend_item_number,
    normalized_status,
    revision_number,
    duplicate_row_count,
    first_formula_name,
    last_formula_name
FROM #DuplicateRevisionKey
ORDER BY
    duplicate_row_count DESC,
    branch_code,
    parent_item_number,
    blend_item_number,
    revision_number;

/* 3. Every source row belonging to those groups, including sequence 1. */
SELECT TOP (500)
    header.*
FROM #HeaderSource AS header
INNER JOIN #DuplicateRevisionKey AS duplicate_key
    ON ISNULL(duplicate_key.branch_code, N'') = ISNULL(header.branch_code, N'')
   AND ISNULL(duplicate_key.parent_item_number, N'') =
        ISNULL(header.parent_item_number, N'')
   AND ISNULL(duplicate_key.blend_item_number, N'') =
        ISNULL(header.blend_item_number, N'')
   AND duplicate_key.normalized_status = header.normalized_status
   AND duplicate_key.revision_number = header.revision_number
ORDER BY
    header.branch_code,
    header.parent_item_number,
    header.blend_item_number,
    header.normalized_status,
    header.revision_number,
    header.formula_name;

/* 4. Proposed formula lifecycle classifications. */
SELECT
    latest_status,
    proposed_is_voided,
    proposed_is_active,
    proposed_is_production,
    COUNT_BIG(*) AS formula_count
FROM #FormulaGroupSource
GROUP BY
    latest_status,
    proposed_is_voided,
    proposed_is_active,
    proposed_is_production
ORDER BY latest_status, proposed_is_production;

/* 5. Multi-revision formula families created by the conservative grouping. */
SELECT TOP (250)
    latest_branch_code AS branch_code,
    latest_parent_item_number AS parent_item_number,
    latest_blend_item_number AS blend_item_number,
    latest_formula_name AS latest_formula_name,
    latest_status,
    revision_count,
    first_revision_number,
    last_revision_number,
    proposed_is_active,
    proposed_is_production
FROM #FormulaGroupSource
WHERE revision_count > 1
ORDER BY revision_count DESC, branch_code, parent_item_number, blend_item_number;

/* 6. Active/Archive families that contain the same revision number more than once. */
SELECT TOP (250)
    formula_group_key,
    revision_number,
    COUNT_BIG(*) AS rows_at_revision_number,
    MIN(normalized_status) AS first_status,
    MAX(normalized_status) AS last_status,
    MIN(formula_name) AS first_formula_name,
    MAX(formula_name) AS last_formula_name
FROM #HeaderSource
WHERE formula_group_key LIKE N'ACTIVE|%'
GROUP BY formula_group_key, revision_number
HAVING COUNT_BIG(*) > 1
ORDER BY rows_at_revision_number DESC, formula_group_key, revision_number;

/* 7. Sample proposed formulas, including their derived lifecycle flags. */
SELECT TOP (250)
    latest_branch_code AS branch_code,
    latest_parent_item_number AS parent_item_number,
    latest_blend_item_number AS blend_item_number,
    latest_formula_name AS formula_name,
    latest_status,
    revision_count,
    first_revision_number,
    last_revision_number,
    proposed_is_voided,
    proposed_is_active,
    proposed_is_production,
    formula_group_key
FROM #FormulaGroupSource
ORDER BY
    proposed_is_production,
    latest_status,
    branch_code,
    parent_item_number,
    blend_item_number;

/* 8. Copy records that could potentially join an Active/Archive family. */
SELECT TOP (250)
    copy_row.branch_code,
    copy_row.parent_item_number,
    copy_row.blend_item_number,
    copy_row.formula_name AS copy_formula_name,
    copy_row.revision_number AS copy_revision_number,
    history.normalized_status AS history_status,
    history.formula_name AS history_formula_name,
    history.revision_number AS history_revision_number
FROM #HeaderSource AS copy_row
INNER JOIN #HeaderSource AS history
    ON history.branch_code = copy_row.branch_code
   AND history.parent_item_number = copy_row.parent_item_number
   AND history.blend_item_number = copy_row.blend_item_number
   AND history.normalized_status IN (N'ACTIVE', N'ARCHIVE', N'ARCHIVED')
WHERE copy_row.normalized_status = N'COPY'
ORDER BY
    copy_row.branch_code,
    copy_row.parent_item_number,
    copy_row.blend_item_number,
    copy_row.revision_number,
    history.revision_number;
END;

IF @ApplyChanges = 0
BEGIN
    PRINT 'PREVIEW ONLY: no target rows were inserted.';
    PRINT 'Set @ApplyChanges = 1 only after approving the result sets above.';
    RETURN;
END;

/* --------------------------------------------------------------------------
   Insert formula identities and revisions in one transaction.
   -------------------------------------------------------------------------- */

BEGIN TRY
    BEGIN TRANSACTION;

    CREATE TABLE #FormulaMap (
        formula_group_key nvarchar(450) NOT NULL PRIMARY KEY,
        formula_id int NOT NULL UNIQUE
    );

    MERGE INTO [PLM_DEV].[form].[formula] AS target
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
            source.proposed_is_voided,
            source.proposed_is_active,
            source.proposed_is_production,
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

    MERGE INTO [PLM_DEV].[form].[formula_header] AS target
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
            [legacy_duplicate_sequence],
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
            source.legacy_duplicate_sequence,
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

    INSERT INTO [PLM_DEV].[form].[formula_review_issue] (
        [formula_id],
        [formula_header_id],
        [formula_line_id],
        [issue_code],
        [severity],
        [review_status],
        [issue_detail],
        [resolution_note],
        [reviewed_by],
        [reviewed_dt],
        [created_by],
        [created_dt],
        [updated_by],
        [updated_dt]
    )
    SELECT
        formula_map.formula_id,
        header_map.formula_header_id,
        NULL,
        issue.issue_code,
        issue.severity,
        N'OPEN',
        issue.issue_detail,
        NULL,
        NULL,
        NULL,
        @MigrationActor,
        @MigrationDt,
        @MigrationActor,
        @MigrationDt
    FROM #ReviewIssueSource AS issue
    INNER JOIN #FormulaMap AS formula_map
        ON formula_map.formula_group_key = issue.formula_group_key
    INNER JOIN #HeaderMap AS header_map
        ON header_map.legacy_header_row_id = issue.legacy_header_row_id;

    IF (SELECT COUNT_BIG(*) FROM [PLM_DEV].[form].[formula])
        <> (SELECT COUNT_BIG(*) FROM #FormulaGroupSource)
        OR (SELECT COUNT_BIG(*) FROM [PLM_DEV].[form].[formula_header])
        <> (SELECT COUNT_BIG(*) FROM #HeaderSource)
        OR (SELECT COUNT_BIG(*) FROM [PLM_DEV].[form].[formula_review_issue])
            <> (SELECT COUNT_BIG(*) FROM #ReviewIssueSource)
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR('Inserted row counts do not match the staged header counts.', 16, 1);
        RETURN;
    END;

    COMMIT TRANSACTION;

    SELECT
        (SELECT COUNT_BIG(*) FROM [PLM_DEV].[form].[formula]) AS inserted_formulas,
        (SELECT COUNT_BIG(*) FROM [PLM_DEV].[form].[formula_header])
            AS inserted_formula_headers,
        (SELECT COUNT_BIG(*) FROM [PLM_DEV].[form].[formula_review_issue])
            AS inserted_review_issues;
END TRY
BEGIN CATCH
    DECLARE @ErrorMessage nvarchar(2048) = ERROR_MESSAGE();
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    RAISERROR(@ErrorMessage, 16, 1);
END CATCH;
GO
