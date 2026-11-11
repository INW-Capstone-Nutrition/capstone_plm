/*
    SIMPLE OWNER-REVIEW VIEWS FOR THE LEGACY FORMULA HEADER PROBLEM

    Business explanation:
      - dbo.Formula_Header has no primary key.
      - dbo.Formula_Item has no FormulaHeaderId foreign key.
      - The only available relationship is the legacy natural key:
            branch + parent + blend + status + revision
      - When that key occurs more than once, a Formula_Item row cannot identify
        which physical Formula_Header row it originally belonged to.
      - Formula name can resolve some groups, but it is mutable, sometimes blank,
        and does not make every group unique.

    These are read-only PLM_DEV views. They do not update either database.
*/

USE [PLM_DEV];
GO

CREATE OR ALTER VIEW [form].[vw_formula_header_owner_summary]
AS
WITH LineProblemGroup AS (
    SELECT
        match_classification,
        normalized_branch_code,
        normalized_parent_item_number,
        normalized_blend_item_number,
        normalized_workflow_status,
        normalized_revision_number,
        normalized_formula_name,
        COUNT_BIG(*) AS affected_line_rows
    FROM [form].[vw_formula_line_seed_diagnostic]
    WHERE requires_header_resolution = 1
    GROUP BY
        match_classification,
        normalized_branch_code,
        normalized_parent_item_number,
        normalized_blend_item_number,
        normalized_workflow_status,
        normalized_revision_number,
        normalized_formula_name
), LineProblemSummary AS (
    SELECT
        match_classification,
        COUNT_BIG(*) AS affected_key_groups,
        SUM(affected_line_rows) AS affected_rows
    FROM LineProblemGroup
    GROUP BY match_classification
)
SELECT
    CONVERT(int, 10) AS display_order,
    CONVERT(nvarchar(50), N'HEADER_FIVE_PART_KEY_DUPLICATE') AS issue_code,
    COUNT_BIG(*) AS affected_key_groups,
    COALESCE(SUM(profile.header_row_count), 0) AS affected_rows,
    CONVERT(nvarchar(500),
        N'Branch + parent + blend + status + revision matches more than one Formula_Header row.'
    ) AS plain_english_problem,
    CONVERT(nvarchar(500),
        N'The source has no primary key, so these rows cannot be referenced individually.'
    ) AS why_it_happened
FROM [form].[vw_legacy_formula_header_key_profile] AS profile
WHERE profile.five_part_key_is_ambiguous = 1

UNION ALL

SELECT
    20,
    N'HEADER_NAME_RESOLVES_DUPLICATE',
    COUNT_BIG(*),
    COALESCE(SUM(profile.header_row_count), 0),
    N'Adding formula name makes every row in these duplicate key groups unique.',
    N'Formula name is usable as a tie-breaker for these groups, but should not replace a real primary key.'
FROM [form].[vw_legacy_formula_header_key_profile] AS profile
WHERE profile.five_part_key_is_ambiguous = 1
  AND profile.formula_name_fully_disambiguates = 1

UNION ALL

SELECT
    30,
    N'HEADER_STILL_DUPLICATE_WITH_NAME',
    COUNT_BIG(*),
    (
        SELECT COUNT_BIG(*)
        FROM [form].[vw_legacy_formula_header_ambiguity] AS detail
        WHERE detail.six_part_match_count > 1
    ),
    N'Even branch + parent + blend + status + revision + formula name still matches multiple headers.',
    N'The legacy data does not contain enough identity information to select one header automatically.'
FROM [form].[vw_legacy_formula_header_key_profile] AS profile
WHERE profile.five_part_key_is_ambiguous = 1
  AND profile.remains_ambiguous_after_name = 1

UNION ALL

SELECT
    40,
    N'HEADER_DUPLICATE_VOID_OR_DELETE',
    COUNT_BIG(*),
    COALESCE(SUM(profile.header_row_count), 0),
    N'These duplicate groups already have a legacy status of VOID, VOIDED, or DELETE.',
    N'They can remain preserved for audit while the normalized formula is classified as voided.'
FROM [form].[vw_legacy_formula_header_key_profile] AS profile
WHERE profile.five_part_key_is_ambiguous = 1
  AND profile.has_void_or_delete_status = 1

UNION ALL

SELECT
    50,
    N'HEADER_INCOMPLETE_IDENTITY',
    COUNT_BIG(*),
    COALESCE(SUM(profile.header_row_count), 0),
    N'One or more identity fields are blank: branch, parent, blend, or formula name.',
    N'Missing source values prevent a complete natural-key relationship.'
FROM [form].[vw_legacy_formula_header_key_profile] AS profile
WHERE profile.five_part_key_is_ambiguous = 1
  AND profile.has_incomplete_identity_data = 1
  AND profile.has_void_or_delete_status = 0

UNION ALL

SELECT
    60,
    N'LINE_MULTIPLE_EXACT_HEADERS',
    COALESCE(summary.affected_key_groups, 0),
    COALESCE(summary.affected_rows, 0),
    N'Formula_Item lines still match multiple headers after using formula name as a tie-breaker.',
    N'The line table has no FormulaHeaderId foreign key identifying its original header.'
FROM LineProblemSummary AS summary
WHERE summary.match_classification = N'EXACT_AMBIGUOUS'

UNION ALL

SELECT
    70,
    N'LINE_NO_HEADER_MATCH',
    COALESCE(summary.affected_key_groups, 0),
    COALESCE(summary.affected_rows, 0),
    N'Formula_Item lines do not match any header using branch, parent, blend, status, and revision.',
    N'The header may be missing, or one or more relationship values were changed independently.'
FROM LineProblemSummary AS summary
WHERE summary.match_classification = N'NO_HEADER_MATCH'

UNION ALL

SELECT
    80,
    N'LINE_MULTIPLE_HEADERS_IF_STATUS_IGNORED',
    COALESCE(summary.affected_key_groups, 0),
    COALESCE(summary.affected_rows, 0),
    N'No exact-status header exists, and ignoring status produces multiple possible headers.',
    N'Status does not agree and there is still no unique header identifier to recover the relationship.'
FROM LineProblemSummary AS summary
WHERE summary.match_classification = N'STATUS_IGNORED_AMBIGUOUS';
GO

CREATE OR ALTER VIEW [form].[vw_formula_header_owner_duplicate_groups]
AS
SELECT
    profile.normalized_branch_code AS branch_code,
    profile.normalized_parent_item_number AS parent_item_number,
    profile.normalized_blend_item_number AS blend_item_number,
    profile.normalized_workflow_status AS workflow_status,
    profile.normalized_revision_number AS revision_number,
    profile.header_row_count,
    profile.formula_name_variant_count,
    profile.candidate_formula_names,
    profile.largest_six_part_match_count,
    profile.formula_name_fully_disambiguates,
    profile.remains_ambiguous_after_name,
    profile.has_void_or_delete_status,
    profile.has_incomplete_identity_data,
    CASE
        WHEN profile.has_void_or_delete_status = 1
            THEN N'LEGACY_VOID_OR_DELETE'
        WHEN profile.has_incomplete_identity_data = 1
            THEN N'INCOMPLETE_IDENTITY'
        WHEN profile.formula_name_fully_disambiguates = 1
            THEN N'NAME_SEPARATES_HEADERS'
        ELSE N'STILL_AMBIGUOUS_WITH_NAME'
    END AS owner_review_category,
    CASE
        WHEN profile.has_void_or_delete_status = 1
            THEN N'Confirm these records should remain audit-only and voided.'
        WHEN profile.has_incomplete_identity_data = 1
            THEN N'Identify the missing branch, parent, blend, or formula name if possible.'
        WHEN profile.formula_name_fully_disambiguates = 1
            THEN N'Confirm the different formula names represent different headers/formulas.'
        ELSE N'Identify which header is valid, or confirm that all duplicate rows must be retained.'
    END AS owner_question,
    CONCAT(
        N'The five-part Formula_Item relationship key matches ',
        profile.header_row_count,
        N' Formula_Header rows.'
    ) AS problem_explanation
FROM [form].[vw_legacy_formula_header_key_profile] AS profile
WHERE profile.five_part_key_is_ambiguous = 1;
GO

CREATE OR ALTER VIEW [form].[vw_formula_header_owner_duplicate_rows]
AS
SELECT
    groups.owner_review_category,
    groups.owner_question,
    detail.five_part_duplicate_sequence AS displayed_duplicate_number,
    detail.five_part_match_count AS headers_with_same_five_part_key,
    detail.six_part_match_count AS headers_with_same_key_and_name,
    detail.normalized_branch_code AS branch_code,
    detail.normalized_parent_item_number AS parent_item_number,
    detail.normalized_blend_item_number AS blend_item_number,
    detail.normalized_workflow_status AS workflow_status,
    detail.normalized_revision_number AS revision_number,
    detail.normalized_formula_name AS formula_name,
    detail.[FHCUSN] AS customer_name,
    detail.[FHCUSP] AS customer_part_number,
    detail.[FHUSER] AS legacy_user,
    detail.[FHTRDJ] AS legacy_transaction_julian_date,
    detail.[FHNOTE] AS legacy_note,
    detail.[FHADDL] AS additional_information,
    groups.candidate_formula_names,
    groups.problem_explanation
FROM [form].[vw_legacy_formula_header_ambiguity] AS detail
INNER JOIN [form].[vw_formula_header_owner_duplicate_groups] AS groups
    ON ISNULL(groups.branch_code, N'') = ISNULL(detail.normalized_branch_code, N'')
   AND ISNULL(groups.parent_item_number, N'')
        = ISNULL(detail.normalized_parent_item_number, N'')
   AND ISNULL(groups.blend_item_number, N'')
        = ISNULL(detail.normalized_blend_item_number, N'')
   AND groups.workflow_status = detail.normalized_workflow_status
   AND groups.revision_number = detail.normalized_revision_number;
GO

CREATE OR ALTER VIEW [form].[vw_formula_header_owner_line_link_problems]
AS
SELECT
    diagnostic.match_classification,
    diagnostic.normalized_branch_code AS branch_code,
    diagnostic.normalized_parent_item_number AS parent_item_number,
    diagnostic.normalized_blend_item_number AS blend_item_number,
    diagnostic.normalized_workflow_status AS line_workflow_status,
    diagnostic.normalized_revision_number AS revision_number,
    diagnostic.normalized_formula_name AS line_formula_name,
    COUNT_BIG(*) AS affected_formula_item_rows,
    COUNT(DISTINCT diagnostic.normalized_material_item_number)
        AS affected_material_count,
    MIN(diagnostic.legacy_line_number) AS first_line_number,
    MAX(diagnostic.legacy_line_number) AS last_line_number,
    MAX(diagnostic.exact_formula_header_ids) AS exact_candidate_header_ids,
    MAX(diagnostic.exact_candidate_formula_names) AS exact_candidate_formula_names,
    MAX(diagnostic.status_ignored_formula_header_ids)
        AS status_ignored_candidate_header_ids,
    MAX(diagnostic.candidate_workflow_statuses) AS candidate_workflow_statuses,
    CASE
        WHEN diagnostic.match_classification = N'EXACT_AMBIGUOUS'
            THEN N'Which of the matching Formula_Header rows owns these ingredient lines?'
        WHEN diagnostic.match_classification = N'NO_HEADER_MATCH'
            THEN N'Is the Formula_Header missing, or were its relationship values changed?'
        WHEN diagnostic.match_classification = N'STATUS_IGNORED_AMBIGUOUS'
            THEN N'Which workflow status and Formula_Header should own these ingredient lines?'
        ELSE N'Review the candidate Formula_Header relationship.'
    END AS owner_question
FROM [form].[vw_formula_line_seed_diagnostic] AS diagnostic
WHERE diagnostic.requires_header_resolution = 1
GROUP BY
    diagnostic.match_classification,
    diagnostic.normalized_branch_code,
    diagnostic.normalized_parent_item_number,
    diagnostic.normalized_blend_item_number,
    diagnostic.normalized_workflow_status,
    diagnostic.normalized_revision_number,
    diagnostic.normalized_formula_name;
GO

/*
    Presentation queries:

    SELECT *
    FROM form.vw_formula_header_owner_summary
    ORDER BY display_order;

    SELECT *
    FROM form.vw_formula_header_owner_duplicate_groups
    ORDER BY owner_review_category, branch_code, parent_item_number,
             blend_item_number, revision_number;

    SELECT *
    FROM form.vw_formula_header_owner_duplicate_rows
    ORDER BY owner_review_category, branch_code, parent_item_number,
             blend_item_number, revision_number, displayed_duplicate_number;

    SELECT *
    FROM form.vw_formula_header_owner_line_link_problems
    ORDER BY match_classification, affected_formula_item_rows DESC,
             branch_code, parent_item_number, blend_item_number, revision_number;
*/
