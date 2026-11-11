/*
    Read-only review of the legacy formula identity and lifecycle rules.

    Legacy header-to-line composite key:
        FHMCU + FHPRNT + FHBLND + FHSTUS + FHRVNO

    This key identifies one legacy revision row for Formula_Item matching. It is
    not the new form.formula primary key and it is not proof that Development and
    Active records belong to the same lifetime formula.

    Proposed flags:
        is_active = 1 only when FHSTUS is Active or Copy.

        is_production = 0 when FHPRNT is blank, or its space-insensitive uppercase
        value begins P-, B-, or AG1, or FHSTUS is Development, Review, or Quote.
        All other combinations currently evaluate to is_production = 1 so they are
        visible for review below.

    No permanent objects or data are changed by this script.
*/

USE [PLM_DEV];
GO

SET NOCOUNT ON;

DROP TABLE IF EXISTS #FormulaReview;

;WITH normalized AS (
    SELECT
        NULLIF(LTRIM(RTRIM([FHMCU])), N'') AS branch_code,
        NULLIF(LTRIM(RTRIM([FHPRNT])), N'') AS parent_item_number,
        NULLIF(LTRIM(RTRIM([FHBLND])), N'') AS blend_item_number,
        COALESCE(NULLIF(LTRIM(RTRIM([FHNAME])), N''), N'Unnamed legacy formula')
            AS formula_name,
        COALESCE(TRY_CONVERT(decimal(10, 4), [FHRVNO]), CONVERT(decimal(10, 4), 0))
            AS revision_number,
        UPPER(COALESCE(NULLIF(LTRIM(RTRIM([FHSTUS])), N''), N'UNKNOWN'))
            AS normalized_status,
        UPPER(REPLACE(COALESCE(LTRIM(RTRIM([FHPRNT])), N''), N' ', N''))
            AS compact_parent
    FROM [dbo].[Formula_Header]
)
SELECT
    *,
    CONVERT(
        bit,
        CASE WHEN normalized_status IN (N'ACTIVE', N'COPY') THEN 1 ELSE 0 END
    ) AS proposed_is_active,
    CONVERT(
        bit,
        CASE
            WHEN parent_item_number IS NULL THEN 0
            WHEN compact_parent LIKE N'P-%' THEN 0
            WHEN compact_parent LIKE N'B-%' THEN 0
            WHEN compact_parent LIKE N'AG1%' THEN 0
            WHEN normalized_status IN (N'DEVELOPMENT', N'REVIEW', N'QUOTE') THEN 0
            ELSE 1
        END
    ) AS proposed_is_production,
    CASE
        WHEN parent_item_number IS NULL THEN N'BLANK_PARENT'
        WHEN compact_parent LIKE N'P-%' THEN N'P_PREFIX'
        WHEN compact_parent LIKE N'B-%' THEN N'B_PREFIX'
        WHEN compact_parent LIKE N'AG1%' THEN N'AG1_PREFIX'
        WHEN normalized_status IN (N'DEVELOPMENT', N'REVIEW', N'QUOTE')
            THEN N'NON_PRODUCTION_STATUS'
        ELSE N'PRODUCTION_CANDIDATE'
    END AS production_rule
INTO #FormulaReview
FROM normalized;

/* 1. Status inventory and proposed flag counts. */
SELECT TOP (250)
    normalized_status,
    proposed_is_active,
    proposed_is_production,
    production_rule,
    COUNT_BIG(*) AS header_count
FROM #FormulaReview
GROUP BY
    normalized_status,
    proposed_is_active,
    proposed_is_production,
    production_rule
ORDER BY normalized_status, production_rule;

/* 2. Overall cross-tab: useful for catching unexpected combinations. */
SELECT
    proposed_is_active,
    proposed_is_production,
    COUNT_BIG(*) AS header_count
FROM #FormulaReview
GROUP BY proposed_is_active, proposed_is_production
ORDER BY proposed_is_active DESC, proposed_is_production DESC;

/* 3. Sample classified rows. Adjust TOP or WHERE clauses as needed. */
SELECT TOP (250)
    branch_code,
    parent_item_number,
    blend_item_number,
    formula_name,
    revision_number,
    normalized_status,
    proposed_is_active,
    proposed_is_production,
    production_rule
FROM #FormulaReview
ORDER BY
    proposed_is_production,
    normalized_status,
    branch_code,
    parent_item_number,
    revision_number DESC;

/* 4. Every provisional-prefix record for focused inspection. */
SELECT
    production_rule,
    normalized_status,
    COUNT_BIG(*) AS header_count
FROM #FormulaReview
WHERE production_rule IN (N'P_PREFIX', N'B_PREFIX', N'AG1_PREFIX')
GROUP BY production_rule, normalized_status
ORDER BY production_rule, normalized_status;

/* 5. Potentially surprising states that deserve business review. */
SELECT TOP (250)
    branch_code,
    parent_item_number,
    blend_item_number,
    formula_name,
    revision_number,
    normalized_status,
    proposed_is_active,
    proposed_is_production,
    production_rule
FROM #FormulaReview
WHERE (proposed_is_active = 1 AND proposed_is_production = 0)
   OR (proposed_is_active = 0 AND proposed_is_production = 1)
ORDER BY normalized_status, parent_item_number, revision_number DESC;

/*
    6. Duplicate legacy revision keys.
    This result must be empty before migration because one Formula_Item row would
    otherwise be unable to resolve to exactly one Formula_Header row.
*/
SELECT TOP (250)
    branch_code,
    parent_item_number,
    blend_item_number,
    normalized_status,
    revision_number,
    COUNT_BIG(*) AS duplicate_count,
    MIN(formula_name) AS first_formula_name,
    MAX(formula_name) AS last_formula_name
FROM #FormulaReview
GROUP BY
    branch_code,
    parent_item_number,
    blend_item_number,
    normalized_status,
    revision_number
HAVING COUNT_BIG(*) > 1
ORDER BY duplicate_count DESC, branch_code, parent_item_number, blend_item_number;

/* 7. Header-match outcome for every Formula_Item row. */
;WITH item_match AS (
    SELECT
        item.[FMRWNO],
        item.[FMMCU],
        item.[FMPRNT],
        item.[FMBLND],
        item.[FMCHLD],
        item.[FMRVNO],
        item.[FMSTUS],
        item.[FMNAME],
        matches.match_count
    FROM [dbo].[Formula_Item] AS item
    CROSS APPLY (
        SELECT COUNT_BIG(*) AS match_count
        FROM #FormulaReview AS header
        WHERE header.branch_code = NULLIF(LTRIM(RTRIM(item.[FMMCU])), N'')
          AND header.parent_item_number = NULLIF(LTRIM(RTRIM(item.[FMPRNT])), N'')
          AND header.blend_item_number = NULLIF(LTRIM(RTRIM(item.[FMBLND])), N'')
          AND header.normalized_status = UPPER(
                COALESCE(NULLIF(LTRIM(RTRIM(item.[FMSTUS])), N''), N'UNKNOWN')
          )
          AND header.revision_number = COALESCE(
                TRY_CONVERT(decimal(10, 4), item.[FMRVNO]),
                CONVERT(decimal(10, 4), 0)
          )
    ) AS matches
)
SELECT
    CASE
        WHEN match_count = 0 THEN N'ORPHAN'
        WHEN match_count = 1 THEN N'MATCHED'
        ELSE N'AMBIGUOUS'
    END AS match_result,
    COUNT_BIG(*) AS line_count
FROM item_match
GROUP BY
    CASE
        WHEN match_count = 0 THEN N'ORPHAN'
        WHEN match_count = 1 THEN N'MATCHED'
        ELSE N'AMBIGUOUS'
    END
ORDER BY match_result;

/* 8. Details for orphaned or ambiguous Formula_Item rows. This should be empty. */
;WITH item_match AS (
    SELECT
        item.*,
        matches.match_count
    FROM [dbo].[Formula_Item] AS item
    CROSS APPLY (
        SELECT COUNT_BIG(*) AS match_count
        FROM #FormulaReview AS header
        WHERE header.branch_code = NULLIF(LTRIM(RTRIM(item.[FMMCU])), N'')
          AND header.parent_item_number = NULLIF(LTRIM(RTRIM(item.[FMPRNT])), N'')
          AND header.blend_item_number = NULLIF(LTRIM(RTRIM(item.[FMBLND])), N'')
          AND header.normalized_status = UPPER(
                COALESCE(NULLIF(LTRIM(RTRIM(item.[FMSTUS])), N''), N'UNKNOWN')
          )
          AND header.revision_number = COALESCE(
                TRY_CONVERT(decimal(10, 4), item.[FMRVNO]),
                CONVERT(decimal(10, 4), 0)
          )
    ) AS matches
)
SELECT TOP (250) *
FROM item_match
WHERE match_count <> 1
ORDER BY match_count DESC, [FMMCU], [FMPRNT], [FMBLND], [FMRVNO], [FMRWNO];

/*
    9. Current conservative formula-family grouping.
    Active/Archive rows with real parent and blend values group by branch + parent
    + blend. All other header rows remain one formula per revision row.
*/
;WITH grouping_preview AS (
    SELECT
        *,
        CASE
            WHEN normalized_status IN (N'ACTIVE', N'ARCHIVE', N'ARCHIVED')
                AND parent_item_number IS NOT NULL
                AND blend_item_number IS NOT NULL
                THEN CONCAT(
                    N'ACTIVE|', branch_code, N'|', parent_item_number, N'|', blend_item_number
                )
            ELSE CONCAT(
                N'ROW|', branch_code, N'|', parent_item_number, N'|', blend_item_number,
                N'|', normalized_status, N'|', revision_number
            )
        END AS proposed_formula_group
    FROM #FormulaReview
)
SELECT TOP (250)
    proposed_formula_group,
    COUNT_BIG(*) AS revision_count,
    MIN(revision_number) AS first_revision,
    MAX(revision_number) AS last_revision,
    MIN(normalized_status) AS first_status_alphabetically,
    MAX(normalized_status) AS last_status_alphabetically,
    MIN(formula_name) AS first_name_alphabetically,
    MAX(formula_name) AS last_name_alphabetically
FROM grouping_preview
GROUP BY proposed_formula_group
HAVING COUNT_BIG(*) > 1
ORDER BY revision_count DESC, proposed_formula_group;

/*
    10. Copy records that share branch + parent + blend with Active/Archive rows.
    Review this result before deciding whether Copy belongs in the grouped history.
*/
SELECT TOP (250)
    copy_row.branch_code,
    copy_row.parent_item_number,
    copy_row.blend_item_number,
    copy_row.formula_name AS copy_formula_name,
    copy_row.revision_number AS copy_revision_number,
    history.normalized_status AS matching_history_status,
    history.formula_name AS matching_history_name,
    history.revision_number AS matching_history_revision
FROM #FormulaReview AS copy_row
INNER JOIN #FormulaReview AS history
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

DROP TABLE IF EXISTS #FormulaReview;
GO
