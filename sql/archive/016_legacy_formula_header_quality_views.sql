/*
    LEGACY FORMULA HEADER QUALITY VIEWS

    All views analyze the frozen PLM_DEV.dbo.Formula_Header snapshot. They do not
    read PLM and do not update is_voided or any other target value.
*/

USE [PLM_DEV];
GO

CREATE OR ALTER VIEW [form].[vw_legacy_formula_header_normalized]
AS
SELECT
    header.*,
    NULLIF(LTRIM(RTRIM(header.[FHMCU])), N'') AS normalized_branch_code,
    NULLIF(LTRIM(RTRIM(header.[FHPRNT])), N'') AS normalized_parent_item_number,
    NULLIF(LTRIM(RTRIM(header.[FHBLND])), N'') AS normalized_blend_item_number,
    NULLIF(LTRIM(RTRIM(header.[FHNAME])), N'') AS normalized_formula_name,
    UPPER(COALESCE(NULLIF(LTRIM(RTRIM(header.[FHSTUS])), N''), N'UNKNOWN'))
        AS normalized_workflow_status,
    COALESCE(
        TRY_CONVERT(decimal(10, 4), header.[FHRVNO]),
        CONVERT(decimal(10, 4), 0)
    ) AS normalized_revision_number,
    CONVERT(
        bit,
        CASE
            WHEN UPPER(COALESCE(NULLIF(LTRIM(RTRIM(header.[FHSTUS])), N''), N'UNKNOWN'))
                IN (N'DELETE', N'VOID', N'VOIDED') THEN 1
            ELSE 0
        END
    ) AS has_void_or_delete_status,
    CONVERT(
        bit,
        CASE
            WHEN NULLIF(LTRIM(RTRIM(header.[FHMCU])), N'') IS NULL
              OR NULLIF(LTRIM(RTRIM(header.[FHPRNT])), N'') IS NULL
              OR NULLIF(LTRIM(RTRIM(header.[FHBLND])), N'') IS NULL
              OR NULLIF(LTRIM(RTRIM(header.[FHNAME])), N'') IS NULL
                THEN 1
            ELSE 0
        END
    ) AS has_incomplete_identity_data
FROM [PLM_DEV].[dbo].[Formula_Header] AS header;
GO

CREATE OR ALTER VIEW [form].[vw_legacy_formula_header_key_profile]
AS
WITH FivePart AS (
    SELECT
        normalized_branch_code,
        normalized_parent_item_number,
        normalized_blend_item_number,
        normalized_workflow_status,
        normalized_revision_number,
        COUNT_BIG(*) AS header_row_count,
        MAX(CONVERT(int, has_void_or_delete_status)) AS has_void_or_delete_status,
        MAX(CONVERT(int, has_incomplete_identity_data)) AS has_incomplete_identity_data
    FROM [form].[vw_legacy_formula_header_normalized]
    GROUP BY
        normalized_branch_code,
        normalized_parent_item_number,
        normalized_blend_item_number,
        normalized_workflow_status,
        normalized_revision_number
), SixPart AS (
    SELECT
        normalized_branch_code,
        normalized_parent_item_number,
        normalized_blend_item_number,
        normalized_workflow_status,
        normalized_revision_number,
        COALESCE(normalized_formula_name, N'[BLANK]') AS normalized_formula_name,
        COUNT_BIG(*) AS six_part_row_count
    FROM [form].[vw_legacy_formula_header_normalized]
    GROUP BY
        normalized_branch_code,
        normalized_parent_item_number,
        normalized_blend_item_number,
        normalized_workflow_status,
        normalized_revision_number,
        COALESCE(normalized_formula_name, N'[BLANK]')
), SixPartSummary AS (
    SELECT
        normalized_branch_code,
        normalized_parent_item_number,
        normalized_blend_item_number,
        normalized_workflow_status,
        normalized_revision_number,
        COUNT_BIG(*) AS formula_name_variant_count,
        MAX(six_part_row_count) AS largest_six_part_match_count,
        SUM(CASE WHEN six_part_row_count > 1 THEN 1 ELSE 0 END)
            AS ambiguous_six_part_name_groups,
        STRING_AGG(CONVERT(nvarchar(max), normalized_formula_name), N' | ')
            WITHIN GROUP (ORDER BY normalized_formula_name) AS candidate_formula_names
    FROM SixPart
    GROUP BY
        normalized_branch_code,
        normalized_parent_item_number,
        normalized_blend_item_number,
        normalized_workflow_status,
        normalized_revision_number
)
SELECT
    five.normalized_branch_code,
    five.normalized_parent_item_number,
    five.normalized_blend_item_number,
    five.normalized_workflow_status,
    five.normalized_revision_number,
    five.header_row_count,
    six.formula_name_variant_count,
    six.largest_six_part_match_count,
    six.ambiguous_six_part_name_groups,
    six.candidate_formula_names,
    CONVERT(bit, CASE WHEN five.header_row_count > 1 THEN 1 ELSE 0 END)
        AS five_part_key_is_ambiguous,
    CONVERT(
        bit,
        CASE
            WHEN five.header_row_count > 1
             AND six.largest_six_part_match_count = 1 THEN 1
            ELSE 0
        END
    ) AS formula_name_fully_disambiguates,
    CONVERT(bit, CASE WHEN six.largest_six_part_match_count > 1 THEN 1 ELSE 0 END)
        AS remains_ambiguous_after_name,
    CONVERT(bit, five.has_void_or_delete_status) AS has_void_or_delete_status,
    CONVERT(bit, five.has_incomplete_identity_data) AS has_incomplete_identity_data,
    CONVERT(bit, five.has_void_or_delete_status) AS recommended_formula_is_voided,
    CASE
        WHEN five.header_row_count = 1 THEN N'UNIQUE'
        WHEN five.has_void_or_delete_status = 1 THEN N'SOURCE_VOID_OR_DELETE'
        WHEN five.has_incomplete_identity_data = 1 THEN N'INCOMPLETE_IDENTITY_REVIEW'
        WHEN six.largest_six_part_match_count = 1 THEN N'USE_NAME_TO_DISAMBIGUATE'
        ELSE N'AMBIGUOUS_MANUAL_REVIEW'
    END AS recommended_disposition
FROM FivePart AS five
INNER JOIN SixPartSummary AS six
    ON ISNULL(six.normalized_branch_code, N'')
        = ISNULL(five.normalized_branch_code, N'')
   AND ISNULL(six.normalized_parent_item_number, N'')
        = ISNULL(five.normalized_parent_item_number, N'')
   AND ISNULL(six.normalized_blend_item_number, N'')
        = ISNULL(five.normalized_blend_item_number, N'')
   AND six.normalized_workflow_status = five.normalized_workflow_status
   AND six.normalized_revision_number = five.normalized_revision_number;
GO

CREATE OR ALTER VIEW [form].[vw_legacy_formula_header_ambiguity]
AS
WITH Detail AS (
    SELECT
        normalized.*,
        COUNT_BIG(*) OVER (
            PARTITION BY
                normalized_branch_code,
                normalized_parent_item_number,
                normalized_blend_item_number,
                normalized_workflow_status,
                normalized_revision_number
        ) AS five_part_match_count,
        COUNT_BIG(*) OVER (
            PARTITION BY
                normalized_branch_code,
                normalized_parent_item_number,
                normalized_blend_item_number,
                normalized_workflow_status,
                normalized_revision_number,
                normalized_formula_name
        ) AS six_part_match_count,
        ROW_NUMBER() OVER (
            PARTITION BY
                normalized_branch_code,
                normalized_parent_item_number,
                normalized_blend_item_number,
                normalized_workflow_status,
                normalized_revision_number
            ORDER BY
                COALESCE(normalized_formula_name, N''),
                COALESCE([FHCUSN], N''),
                COALESCE([FHCUSP], N''),
                COALESCE([FHUSER], N''),
                COALESCE([FHTRDJ], 0)
        ) AS five_part_duplicate_sequence
    FROM [form].[vw_legacy_formula_header_normalized] AS normalized
)
SELECT
    detail.*,
    profile.formula_name_variant_count,
    profile.candidate_formula_names,
    profile.formula_name_fully_disambiguates,
    profile.remains_ambiguous_after_name,
    profile.recommended_formula_is_voided,
    profile.recommended_disposition
FROM Detail AS detail
INNER JOIN [form].[vw_legacy_formula_header_key_profile] AS profile
    ON ISNULL(profile.normalized_branch_code, N'')
        = ISNULL(detail.normalized_branch_code, N'')
   AND ISNULL(profile.normalized_parent_item_number, N'')
        = ISNULL(detail.normalized_parent_item_number, N'')
   AND ISNULL(profile.normalized_blend_item_number, N'')
        = ISNULL(detail.normalized_blend_item_number, N'')
   AND profile.normalized_workflow_status = detail.normalized_workflow_status
   AND profile.normalized_revision_number = detail.normalized_revision_number
WHERE detail.five_part_match_count > 1;
GO

CREATE OR ALTER VIEW [form].[vw_legacy_formula_header_issue_summary]
AS
SELECT
    recommended_disposition,
    normalized_workflow_status,
    COUNT_BIG(*) AS key_group_count,
    SUM(header_row_count) AS source_header_row_count,
    SUM(CASE WHEN remains_ambiguous_after_name = 1 THEN 1 ELSE 0 END)
        AS groups_still_ambiguous_after_name
FROM [form].[vw_legacy_formula_header_key_profile]
WHERE five_part_key_is_ambiguous = 1
GROUP BY recommended_disposition, normalized_workflow_status;
GO

/* Suggested review order. */
SELECT *
FROM [form].[vw_legacy_formula_header_issue_summary]
ORDER BY recommended_disposition, normalized_workflow_status;

SELECT *
FROM [form].[vw_legacy_formula_header_ambiguity]
ORDER BY
    recommended_formula_is_voided DESC,
    recommended_disposition,
    normalized_branch_code,
    normalized_parent_item_number,
    normalized_blend_item_number,
    normalized_revision_number,
    five_part_duplicate_sequence;
GO
