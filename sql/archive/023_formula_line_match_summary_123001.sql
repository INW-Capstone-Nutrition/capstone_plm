/*
  PLM_DEV only. Cutoff scenario: only headers dated 123001 or later. Classify the frozen dbo.Formula_Item rows against the migrated
  form.formula_header rows. This view does not migrate lines or alter PLM.
  A status-only candidate is a review lead, never an automatic assignment.
*/
USE [PLM_DEV];
GO

CREATE OR ALTER VIEW [form].[vw_formula_line_match_summary_123001]
AS
WITH line_groups AS (
    SELECT
        NULLIF(LTRIM(RTRIM(FMMCU)), N'') AS branch_code,
        NULLIF(LTRIM(RTRIM(FMPRNT)), N'') AS parent_item_number,
        NULLIF(LTRIM(RTRIM(FMBLND)), N'') AS blend_item_number,
        UPPER(COALESCE(NULLIF(LTRIM(RTRIM(FMSTUS)), N''), N'UNKNOWN')) AS workflow_status,
        COALESCE(TRY_CONVERT(decimal(10, 4), FMRVNO), 0) AS revision_number,
        UPPER(NULLIF(LTRIM(RTRIM(FMNAME)), N'')) AS formula_name,
        COUNT_BIG(*) AS line_rows
    FROM [dbo].[Formula_Item]
    GROUP BY
        NULLIF(LTRIM(RTRIM(FMMCU)), N''),
        NULLIF(LTRIM(RTRIM(FMPRNT)), N''),
        NULLIF(LTRIM(RTRIM(FMBLND)), N''),
        UPPER(COALESCE(NULLIF(LTRIM(RTRIM(FMSTUS)), N''), N'UNKNOWN')),
        COALESCE(TRY_CONVERT(decimal(10, 4), FMRVNO), 0),
        UPPER(NULLIF(LTRIM(RTRIM(FMNAME)), N''))
), header_keys AS (
    SELECT
        NULLIF(LTRIM(RTRIM(branch_code)), N'') AS branch_code,
        NULLIF(LTRIM(RTRIM(parent_item_number)), N'') AS parent_item_number,
        NULLIF(LTRIM(RTRIM(blend_item_number)), N'') AS blend_item_number,
        UPPER(COALESCE(NULLIF(LTRIM(RTRIM(workflow_status)), N''), N'UNKNOWN')) AS workflow_status,
        CONVERT(decimal(10, 4), revision_number) AS revision_number,
        COUNT_BIG(*) AS header_count
    FROM [form].[formula_header]
    WHERE legacy_transaction_julian_date >= 123001
    GROUP BY
        NULLIF(LTRIM(RTRIM(branch_code)), N''),
        NULLIF(LTRIM(RTRIM(parent_item_number)), N''),
        NULLIF(LTRIM(RTRIM(blend_item_number)), N''),
        UPPER(COALESCE(NULLIF(LTRIM(RTRIM(workflow_status)), N''), N'UNKNOWN')),
        CONVERT(decimal(10, 4), revision_number)
), header_names AS (
    SELECT
        NULLIF(LTRIM(RTRIM(branch_code)), N'') AS branch_code,
        NULLIF(LTRIM(RTRIM(parent_item_number)), N'') AS parent_item_number,
        NULLIF(LTRIM(RTRIM(blend_item_number)), N'') AS blend_item_number,
        UPPER(COALESCE(NULLIF(LTRIM(RTRIM(workflow_status)), N''), N'UNKNOWN')) AS workflow_status,
        CONVERT(decimal(10, 4), revision_number) AS revision_number,
        UPPER(NULLIF(LTRIM(RTRIM(formula_name)), N'')) AS formula_name,
        COUNT_BIG(*) AS header_count
    FROM [form].[formula_header]
    WHERE legacy_transaction_julian_date >= 123001
    GROUP BY
        NULLIF(LTRIM(RTRIM(branch_code)), N''),
        NULLIF(LTRIM(RTRIM(parent_item_number)), N''),
        NULLIF(LTRIM(RTRIM(blend_item_number)), N''),
        UPPER(COALESCE(NULLIF(LTRIM(RTRIM(workflow_status)), N''), N'UNKNOWN')),
        CONVERT(decimal(10, 4), revision_number),
        UPPER(NULLIF(LTRIM(RTRIM(formula_name)), N''))
), status_ignored AS (
    SELECT
        NULLIF(LTRIM(RTRIM(branch_code)), N'') AS branch_code,
        NULLIF(LTRIM(RTRIM(parent_item_number)), N'') AS parent_item_number,
        NULLIF(LTRIM(RTRIM(blend_item_number)), N'') AS blend_item_number,
        CONVERT(decimal(10, 4), revision_number) AS revision_number,
        COUNT_BIG(*) AS header_count
    FROM [form].[formula_header]
    WHERE legacy_transaction_julian_date >= 123001
    GROUP BY
        NULLIF(LTRIM(RTRIM(branch_code)), N''),
        NULLIF(LTRIM(RTRIM(parent_item_number)), N''),
        NULLIF(LTRIM(RTRIM(blend_item_number)), N''),
        CONVERT(decimal(10, 4), revision_number)
), classified AS (
    SELECT l.line_rows,
        CASE
            WHEN l.parent_item_number IS NULL OR l.blend_item_number IS NULL
                THEN N'EXCLUDED_BLANK_PARENT_OR_BLEND'
            WHEN h.header_count = 1 THEN N'EXACT_KEY_ONE_HEADER'
            WHEN h.header_count > 1 AND hn.header_count = 1
                THEN N'EXACT_NAME_ONE_HEADER'
            WHEN h.header_count > 1 THEN N'EXACT_KEY_AMBIGUOUS'
            WHEN si.header_count = 1 THEN N'STATUS_DIFF_ONE_CANDIDATE'
            WHEN si.header_count > 1 THEN N'STATUS_DIFF_MULTIPLE_CANDIDATES'
            ELSE N'NO_HEADER_CANDIDATE'
        END AS match_result
    FROM line_groups AS l
    LEFT JOIN header_keys AS h
        ON ISNULL(h.branch_code, N'') = ISNULL(l.branch_code, N'')
       AND h.parent_item_number = l.parent_item_number
       AND h.blend_item_number = l.blend_item_number
       AND h.workflow_status = l.workflow_status
       AND h.revision_number = l.revision_number
    LEFT JOIN header_names AS hn
        ON ISNULL(hn.branch_code, N'') = ISNULL(l.branch_code, N'')
       AND hn.parent_item_number = l.parent_item_number
       AND hn.blend_item_number = l.blend_item_number
       AND hn.workflow_status = l.workflow_status
       AND hn.revision_number = l.revision_number
       AND hn.formula_name = l.formula_name
    LEFT JOIN status_ignored AS si
        ON ISNULL(si.branch_code, N'') = ISNULL(l.branch_code, N'')
       AND si.parent_item_number = l.parent_item_number
       AND si.blend_item_number = l.blend_item_number
       AND si.revision_number = l.revision_number
)
SELECT match_result, SUM(line_rows) AS line_rows,
       COUNT_BIG(*) AS key_and_name_groups
FROM classified
GROUP BY match_result;
GO

SELECT match_result, line_rows, key_and_name_groups FROM [form].[vw_formula_line_match_summary_123001] ORDER BY match_result;

