/*
    Read-only diagnostics for migrating:

        PLM_DEV.dbo.Formula_Item static snapshot
            -> PLM_DEV.form.formula_line

    Header resolution order:
        1. branch + parent + blend + status + decimal revision
        2. when step 1 is ambiguous, add normalized FMNAME/FHNAME
        3. when step 1 finds no header, show status-ignored recovery candidates

    Formula name is a tie-breaker, not a required part of every match. Legacy names
    can be blank or disagree even when the five-part key has exactly one header.

    Header-resolution, formula-name, and duplicate-line-number diagnostics are
    separate columns. These views never insert or update data.
*/

USE [PLM_DEV];
GO

CREATE OR ALTER VIEW [form].[vw_formula_line_seed_diagnostic]
AS
WITH SourceLine AS (
    SELECT
        item.[FMRWNO] AS legacy_line_number,
        item.[FMMCU] AS legacy_branch_code,
        item.[FMPRNT] AS legacy_parent_item_number,
        item.[FMBLND] AS legacy_blend_item_number,
        item.[FMCHLD] AS legacy_material_item_number,
        item.[FMRVNO] AS legacy_revision_number,
        item.[FMSTUS] AS legacy_workflow_status,
        item.[FMDSCR] AS legacy_material_description,
        item.[FMTMRK] AS legacy_trademark,
        item.[FMVEND] AS legacy_vendor_name,
        item.[FMQUOT] AS legacy_quoted_cost,
        item.[FMCOST] AS legacy_selected_cost,
        item.[FMNAME] AS legacy_formula_name,
        item.[FMUSER] AS legacy_entered_by,
        item.[FMPTNC] AS legacy_potency,
        item.[FMPTUM] AS legacy_potency_uom,
        item.[FMTIVE] AS legacy_active_percent,
        item.[FMOVRA] AS legacy_overage_percent,
        item.[FMGORY] AS legacy_material_category,
        item.[FMDLYD] AS legacy_daily_dose_percent,
        item.[FMMGTB] AS legacy_mg_per_capsule_percent,
        item.[FMMGMO] AS legacy_mg_per_capsule_with_overage,
        item.[FMPRFM] AS legacy_formula_percent,
        item.[FMPCST] AS legacy_cost_percent,
        item.[FMPRNC] AS legacy_total_cost_flag,
        item.[FMPRNV] AS legacy_total_formula_flag,
        item.[FMNOTE] AS legacy_notes,
        NULLIF(LTRIM(RTRIM(item.[FMMCU])), N'') AS normalized_branch_code,
        NULLIF(LTRIM(RTRIM(item.[FMPRNT])), N'') AS normalized_parent_item_number,
        NULLIF(LTRIM(RTRIM(item.[FMBLND])), N'') AS normalized_blend_item_number,
        NULLIF(LTRIM(RTRIM(item.[FMCHLD])), N'') AS normalized_material_item_number,
        UPPER(NULLIF(LTRIM(RTRIM(item.[FMSTUS])), N''))
            AS normalized_workflow_status,
        UPPER(NULLIF(LTRIM(RTRIM(item.[FMNAME])), N''))
            AS normalized_formula_name,
        TRY_CONVERT(decimal(10, 4), item.[FMRVNO]) AS normalized_revision_number
    FROM [PLM_DEV].[dbo].[Formula_Item] AS item
),
SourceLineNumberGroup AS (
    SELECT
        normalized_branch_code,
        normalized_parent_item_number,
        normalized_blend_item_number,
        normalized_workflow_status,
        normalized_revision_number,
        legacy_line_number,
        COUNT_BIG(*) AS duplicate_line_number_count,
        COUNT(DISTINCT normalized_material_item_number) AS distinct_material_count
    FROM SourceLine
    GROUP BY
        normalized_branch_code,
        normalized_parent_item_number,
        normalized_blend_item_number,
        normalized_workflow_status,
        normalized_revision_number,
        legacy_line_number
),
NormalizedHeader AS (
    SELECT
        header.id AS formula_header_id,
        header.formula_id,
        NULLIF(LTRIM(RTRIM(header.branch_code)), N'') AS branch_code,
        NULLIF(LTRIM(RTRIM(header.parent_item_number)), N'') AS parent_item_number,
        NULLIF(LTRIM(RTRIM(header.blend_item_number)), N'') AS blend_item_number,
        UPPER(NULLIF(LTRIM(RTRIM(header.workflow_status)), N''))
            AS normalized_workflow_status,
        UPPER(NULLIF(LTRIM(RTRIM(header.formula_name)), N''))
            AS normalized_formula_name,
        header.revision_number
    FROM [form].[formula_header] AS header
),
ExactHeaderCandidate AS (
    SELECT
        branch_code,
        parent_item_number,
        blend_item_number,
        normalized_workflow_status,
        revision_number,
        COUNT_BIG(*) AS exact_header_count,
        MIN(formula_header_id) AS minimum_formula_header_id,
        MIN(formula_id) AS minimum_formula_id,
        STRING_AGG(CONVERT(nvarchar(max), formula_header_id), N',')
            WITHIN GROUP (ORDER BY formula_header_id) AS exact_formula_header_ids,
        STRING_AGG(CONVERT(nvarchar(max), COALESCE(normalized_formula_name, N'[BLANK]')), N' | ')
            WITHIN GROUP (ORDER BY formula_header_id) AS exact_candidate_formula_names
    FROM NormalizedHeader
    GROUP BY
        branch_code,
        parent_item_number,
        blend_item_number,
        normalized_workflow_status,
        revision_number
),
ExactNameHeaderCandidate AS (
    SELECT
        branch_code,
        parent_item_number,
        blend_item_number,
        normalized_workflow_status,
        revision_number,
        normalized_formula_name,
        COUNT_BIG(*) AS exact_name_header_count,
        MIN(formula_header_id) AS minimum_formula_header_id,
        MIN(formula_id) AS minimum_formula_id,
        STRING_AGG(CONVERT(nvarchar(max), formula_header_id), N',')
            WITHIN GROUP (ORDER BY formula_header_id)
            AS exact_name_formula_header_ids
    FROM NormalizedHeader
    GROUP BY
        branch_code,
        parent_item_number,
        blend_item_number,
        normalized_workflow_status,
        revision_number,
        normalized_formula_name
),
StatusIgnoredHeaderCandidate AS (
    SELECT
        branch_code,
        parent_item_number,
        blend_item_number,
        revision_number,
        COUNT_BIG(*) AS status_ignored_header_count,
        MIN(formula_header_id) AS minimum_formula_header_id,
        MIN(formula_id) AS minimum_formula_id,
        STRING_AGG(CONVERT(nvarchar(max), formula_header_id), N',')
            WITHIN GROUP (ORDER BY formula_header_id)
            AS status_ignored_formula_header_ids,
        STRING_AGG(
            CONVERT(nvarchar(max), COALESCE(normalized_workflow_status, N'[BLANK]')),
            N','
        ) WITHIN GROUP (ORDER BY formula_header_id) AS candidate_workflow_statuses
    FROM NormalizedHeader
    GROUP BY branch_code, parent_item_number, blend_item_number, revision_number
),
StatusIgnoredNameHeaderCandidate AS (
    SELECT
        branch_code,
        parent_item_number,
        blend_item_number,
        revision_number,
        normalized_formula_name,
        COUNT_BIG(*) AS status_ignored_name_header_count,
        MIN(formula_header_id) AS minimum_formula_header_id,
        MIN(formula_id) AS minimum_formula_id,
        STRING_AGG(CONVERT(nvarchar(max), formula_header_id), N',')
            WITHIN GROUP (ORDER BY formula_header_id)
            AS status_ignored_name_formula_header_ids
    FROM NormalizedHeader
    GROUP BY
        branch_code,
        parent_item_number,
        blend_item_number,
        revision_number,
        normalized_formula_name
),
Classified AS (
    SELECT
        source_line.*,
        COALESCE(exact_match.exact_header_count, 0) AS exact_header_count,
        COALESCE(exact_name_match.exact_name_header_count, 0)
            AS exact_name_header_count,
        COALESCE(loose_match.status_ignored_header_count, 0)
            AS status_ignored_header_count,
        COALESCE(loose_name_match.status_ignored_name_header_count, 0)
            AS status_ignored_name_header_count,
        CASE
            WHEN exact_match.exact_header_count = 1
                THEN exact_match.minimum_formula_header_id
            WHEN exact_match.exact_header_count > 1
             AND exact_name_match.exact_name_header_count = 1
                THEN exact_name_match.minimum_formula_header_id
            WHEN exact_match.exact_header_count IS NULL
             AND loose_name_match.status_ignored_name_header_count = 1
                THEN loose_name_match.minimum_formula_header_id
            WHEN exact_match.exact_header_count IS NULL
             AND loose_match.status_ignored_header_count = 1
                THEN loose_match.minimum_formula_header_id
            ELSE NULL
        END AS suggested_formula_header_id,
        CASE
            WHEN exact_match.exact_header_count = 1
                THEN exact_match.minimum_formula_id
            WHEN exact_match.exact_header_count > 1
             AND exact_name_match.exact_name_header_count = 1
                THEN exact_name_match.minimum_formula_id
            WHEN exact_match.exact_header_count IS NULL
             AND loose_name_match.status_ignored_name_header_count = 1
                THEN loose_name_match.minimum_formula_id
            WHEN exact_match.exact_header_count IS NULL
             AND loose_match.status_ignored_header_count = 1
                THEN loose_match.minimum_formula_id
            ELSE NULL
        END AS suggested_formula_id,
        exact_match.exact_formula_header_ids,
        exact_match.exact_candidate_formula_names,
        exact_name_match.exact_name_formula_header_ids,
        loose_match.status_ignored_formula_header_ids,
        loose_match.candidate_workflow_statuses,
        loose_name_match.status_ignored_name_formula_header_ids,
        duplicate_group.duplicate_line_number_count,
        duplicate_group.distinct_material_count,
        ROW_NUMBER() OVER (
            PARTITION BY
                source_line.normalized_branch_code,
                source_line.normalized_parent_item_number,
                source_line.normalized_blend_item_number,
                source_line.normalized_workflow_status,
                source_line.normalized_revision_number,
                source_line.legacy_line_number
            ORDER BY
                source_line.normalized_material_item_number,
                source_line.legacy_material_description,
                source_line.legacy_vendor_name,
                source_line.legacy_entered_by
        ) AS legacy_duplicate_sequence
    FROM SourceLine AS source_line
    INNER JOIN SourceLineNumberGroup AS duplicate_group
        ON ISNULL(duplicate_group.normalized_branch_code, N'')
            = ISNULL(source_line.normalized_branch_code, N'')
       AND ISNULL(duplicate_group.normalized_parent_item_number, N'')
            = ISNULL(source_line.normalized_parent_item_number, N'')
       AND ISNULL(duplicate_group.normalized_blend_item_number, N'')
            = ISNULL(source_line.normalized_blend_item_number, N'')
       AND ISNULL(duplicate_group.normalized_workflow_status, N'')
            = ISNULL(source_line.normalized_workflow_status, N'')
       AND ISNULL(duplicate_group.normalized_revision_number, -999999)
            = ISNULL(source_line.normalized_revision_number, -999999)
       AND duplicate_group.legacy_line_number = source_line.legacy_line_number
    LEFT JOIN ExactHeaderCandidate AS exact_match
        ON ISNULL(exact_match.branch_code, N'')
            = ISNULL(source_line.normalized_branch_code, N'')
       AND ISNULL(exact_match.parent_item_number, N'')
            = ISNULL(source_line.normalized_parent_item_number, N'')
       AND ISNULL(exact_match.blend_item_number, N'')
            = ISNULL(source_line.normalized_blend_item_number, N'')
       AND ISNULL(exact_match.normalized_workflow_status, N'')
            = ISNULL(source_line.normalized_workflow_status, N'')
       AND ISNULL(exact_match.revision_number, -999999)
            = ISNULL(source_line.normalized_revision_number, -999999)
    LEFT JOIN ExactNameHeaderCandidate AS exact_name_match
        ON ISNULL(exact_name_match.branch_code, N'')
            = ISNULL(source_line.normalized_branch_code, N'')
       AND ISNULL(exact_name_match.parent_item_number, N'')
            = ISNULL(source_line.normalized_parent_item_number, N'')
       AND ISNULL(exact_name_match.blend_item_number, N'')
            = ISNULL(source_line.normalized_blend_item_number, N'')
       AND ISNULL(exact_name_match.normalized_workflow_status, N'')
            = ISNULL(source_line.normalized_workflow_status, N'')
       AND ISNULL(exact_name_match.revision_number, -999999)
            = ISNULL(source_line.normalized_revision_number, -999999)
       AND ISNULL(exact_name_match.normalized_formula_name, N'')
            = ISNULL(source_line.normalized_formula_name, N'')
    LEFT JOIN StatusIgnoredHeaderCandidate AS loose_match
        ON ISNULL(loose_match.branch_code, N'')
            = ISNULL(source_line.normalized_branch_code, N'')
       AND ISNULL(loose_match.parent_item_number, N'')
            = ISNULL(source_line.normalized_parent_item_number, N'')
       AND ISNULL(loose_match.blend_item_number, N'')
            = ISNULL(source_line.normalized_blend_item_number, N'')
       AND ISNULL(loose_match.revision_number, -999999)
            = ISNULL(source_line.normalized_revision_number, -999999)
    LEFT JOIN StatusIgnoredNameHeaderCandidate AS loose_name_match
        ON ISNULL(loose_name_match.branch_code, N'')
            = ISNULL(source_line.normalized_branch_code, N'')
       AND ISNULL(loose_name_match.parent_item_number, N'')
            = ISNULL(source_line.normalized_parent_item_number, N'')
       AND ISNULL(loose_name_match.blend_item_number, N'')
            = ISNULL(source_line.normalized_blend_item_number, N'')
       AND ISNULL(loose_name_match.revision_number, -999999)
            = ISNULL(source_line.normalized_revision_number, -999999)
       AND ISNULL(loose_name_match.normalized_formula_name, N'')
            = ISNULL(source_line.normalized_formula_name, N'')
),
Resolved AS (
    SELECT
        classified.*,
        CASE
            WHEN exact_header_count = 1 THEN N'EXACT_UNIQUE'
            WHEN exact_header_count > 1 AND exact_name_header_count = 1
                THEN N'EXACT_NAME_UNIQUE'
            WHEN exact_header_count > 1 THEN N'EXACT_AMBIGUOUS'
            WHEN status_ignored_name_header_count = 1
                THEN N'STATUS_ONLY_NAME_UNIQUE'
            WHEN status_ignored_header_count = 1 THEN N'STATUS_ONLY_UNIQUE'
            WHEN status_ignored_header_count > 1 THEN N'STATUS_IGNORED_AMBIGUOUS'
            ELSE N'NO_HEADER_MATCH'
        END AS match_classification,
        CASE
            WHEN exact_header_count > 1 AND exact_name_header_count = 1
                THEN N'LINE_HEADER_DISAMBIGUATED_BY_NAME'
            WHEN exact_header_count > 1 THEN N'LINE_MULTIPLE_EXACT_HEADERS'
            WHEN exact_header_count = 0 AND status_ignored_name_header_count = 1
                THEN N'LINE_STATUS_MISMATCH_NAME_MATCH'
            WHEN exact_header_count = 0 AND status_ignored_header_count = 1
                THEN N'LINE_STATUS_MISMATCH'
            WHEN exact_header_count = 0 AND status_ignored_header_count > 1
                THEN N'LINE_MULTIPLE_STATUS_IGNORED_HEADERS'
            WHEN exact_header_count = 0 AND status_ignored_header_count = 0
                THEN N'LINE_NO_HEADER_MATCH'
            ELSE NULL
        END AS match_issue_code,
        CASE
            WHEN normalized_formula_name IS NULL THEN N'LINE_FORMULA_NAME_MISSING'
            WHEN exact_header_count = 1 AND exact_name_header_count = 0
                THEN N'LINE_FORMULA_NAME_MISMATCH'
            ELSE NULL
        END AS formula_name_issue_code,
        CASE
            WHEN duplicate_line_number_count > 1 AND distinct_material_count > 1
                THEN N'DUPLICATE_LINE_NUMBER_DIFFERENT_MATERIAL'
            WHEN duplicate_line_number_count > 1
                THEN N'DUPLICATE_LINE_NUMBER_SAME_MATERIAL'
            ELSE NULL
        END AS line_number_issue_code
    FROM Classified AS classified
)
SELECT
    resolved.*,
    CONVERT(bit, CASE WHEN suggested_formula_header_id IS NULL THEN 1 ELSE 0 END)
        AS requires_header_resolution,
    CONVERT(bit, CASE WHEN line_number_issue_code IS NOT NULL THEN 1 ELSE 0 END)
        AS has_line_number_issue,
    CONVERT(bit, CASE WHEN formula_name_issue_code IS NOT NULL THEN 1 ELSE 0 END)
        AS has_formula_name_warning,
    CONVERT(
        bit,
        CASE
            WHEN suggested_formula_header_id IS NULL
              OR line_number_issue_code IS NOT NULL THEN 1
            ELSE 0
        END
    ) AS needs_review
FROM Resolved AS resolved;
GO

CREATE OR ALTER VIEW [form].[vw_formula_line_seed_unmatched]
AS
SELECT *
FROM [form].[vw_formula_line_seed_diagnostic]
WHERE requires_header_resolution = 1;
GO

CREATE OR ALTER VIEW [form].[vw_formula_line_seed_ambiguous_header]
AS
SELECT *
FROM [form].[vw_formula_line_seed_diagnostic]
WHERE requires_header_resolution = 1
  AND (exact_header_count > 1 OR status_ignored_header_count > 1);
GO

CREATE OR ALTER VIEW [form].[vw_formula_line_seed_duplicate_number]
AS
SELECT *
FROM [form].[vw_formula_line_seed_diagnostic]
WHERE has_line_number_issue = 1;
GO

CREATE OR ALTER VIEW [form].[vw_formula_line_seed_match_summary]
AS
SELECT
    match_classification,
    COUNT_BIG(*) AS source_line_rows,
    SUM(CASE WHEN requires_header_resolution = 1 THEN CONVERT(bigint, 1) ELSE 0 END)
        AS header_resolution_rows,
    SUM(CASE WHEN has_line_number_issue = 1 THEN CONVERT(bigint, 1) ELSE 0 END)
        AS line_number_review_rows,
    SUM(CASE WHEN has_formula_name_warning = 1 THEN CONVERT(bigint, 1) ELSE 0 END)
        AS formula_name_warning_rows,
    SUM(CASE WHEN needs_review = 1 THEN CONVERT(bigint, 1) ELSE 0 END)
        AS review_rows
FROM [form].[vw_formula_line_seed_diagnostic]
GROUP BY match_classification;
GO

/*
    Review queries:

    SELECT *
    FROM [form].[vw_formula_line_seed_match_summary]
    ORDER BY match_classification;

    SELECT *
    FROM [form].[vw_formula_line_seed_unmatched]
    ORDER BY
        match_classification,
        normalized_branch_code,
        normalized_parent_item_number,
        normalized_blend_item_number,
        normalized_revision_number,
        legacy_line_number;

    SELECT *
    FROM [form].[vw_formula_line_seed_ambiguous_header]
    ORDER BY
        match_classification,
        normalized_branch_code,
        normalized_parent_item_number,
        normalized_blend_item_number,
        normalized_revision_number,
        legacy_line_number;

    SELECT *
    FROM [form].[vw_formula_line_seed_duplicate_number]
    ORDER BY
        normalized_branch_code,
        normalized_parent_item_number,
        normalized_blend_item_number,
        normalized_workflow_status,
        normalized_revision_number,
        legacy_line_number,
        legacy_duplicate_sequence;
*/
