/*
  PLM_DEV only. Actual source line rows needing a header decision, with one
  result row per candidate header. Source lines without candidates remain one
  row with NULL header columns. Lines lacking a branch are excluded. No PLM
  or line-table writes.
*/
USE [PLM_DEV];
GO

CREATE OR ALTER VIEW [form].[vw_formula_line_match_review]
AS
WITH h AS (
    SELECT NULLIF(LTRIM(RTRIM(branch_code)), N'') AS branch_code,
           NULLIF(LTRIM(RTRIM(parent_item_number)), N'') AS parent_item_number,
           NULLIF(LTRIM(RTRIM(blend_item_number)), N'') AS blend_item_number,
           UPPER(COALESCE(NULLIF(LTRIM(RTRIM(workflow_status)), N''), N'UNKNOWN')) AS workflow_status,
           CONVERT(decimal(10, 4), revision_number) AS revision_number,
           UPPER(NULLIF(LTRIM(RTRIM(formula_name)), N'')) AS formula_name,
           id AS formula_header_id
    FROM [form].[formula_header]
), exact_key AS (
    SELECT branch_code,parent_item_number,blend_item_number,workflow_status,revision_number,
           COUNT_BIG(*) AS header_count,
           STRING_AGG(CONVERT(nvarchar(max),formula_header_id), N',')
             WITHIN GROUP (ORDER BY formula_header_id) AS candidate_header_ids
    FROM h GROUP BY branch_code,parent_item_number,blend_item_number,workflow_status,revision_number
), exact_name AS (
    SELECT branch_code,parent_item_number,blend_item_number,workflow_status,revision_number,
           formula_name,COUNT_BIG(*) AS header_count
    FROM h GROUP BY branch_code,parent_item_number,blend_item_number,workflow_status,revision_number,formula_name
), status_ignored AS (
    SELECT branch_code,parent_item_number,blend_item_number,revision_number,
           COUNT_BIG(*) AS header_count,
           STRING_AGG(CONVERT(nvarchar(max),formula_header_id), N',')
             WITHIN GROUP (ORDER BY formula_header_id) AS candidate_header_ids,
           STRING_AGG(CONVERT(nvarchar(max),workflow_status), N',')
             WITHIN GROUP (ORDER BY formula_header_id) AS candidate_statuses
    FROM h GROUP BY branch_code,parent_item_number,blend_item_number,revision_number
), lines AS (
    SELECT item.FMRWNO,item.FMMCU,item.FMPRNT,item.FMBLND,item.FMCHLD,
           item.FMRVNO,item.FMSTUS,item.FMNAME,item.FMDSCR,
           NULLIF(LTRIM(RTRIM(item.FMMCU)), N'') AS branch_code,
           NULLIF(LTRIM(RTRIM(item.FMPRNT)), N'') AS parent_item_number,
           NULLIF(LTRIM(RTRIM(item.FMBLND)), N'') AS blend_item_number,
           UPPER(COALESCE(NULLIF(LTRIM(RTRIM(item.FMSTUS)), N''), N'UNKNOWN')) AS workflow_status,
           COALESCE(TRY_CONVERT(decimal(10, 4), item.FMRVNO), 0) AS revision_number,
           UPPER(NULLIF(LTRIM(RTRIM(item.FMNAME)), N'')) AS formula_name
    FROM [dbo].[Formula_Item] AS item
    WHERE NULLIF(LTRIM(RTRIM(item.FMMCU)), N'') IS NOT NULL
      AND NULLIF(LTRIM(RTRIM(item.FMPRNT)), N'') IS NOT NULL
      AND NULLIF(LTRIM(RTRIM(item.FMBLND)), N'') IS NOT NULL
), classified AS (
    SELECT l.*,
           CASE WHEN ek.header_count > 1 THEN ek.candidate_header_ids
                ELSE si.candidate_header_ids END AS candidate_header_ids,
           CASE WHEN ek.header_count > 1 THEN l.FMSTUS
                ELSE si.candidate_statuses END AS candidate_statuses,
           CASE WHEN ek.header_count > 1 AND ISNULL(en.header_count, 0) <> 1
                    THEN N'EXACT_KEY_AMBIGUOUS'
                WHEN ek.header_count IS NULL AND si.header_count = 1
                    THEN N'STATUS_DIFF_ONE_CANDIDATE'
                WHEN ek.header_count IS NULL AND si.header_count > 1
                    THEN N'STATUS_DIFF_MULTIPLE_CANDIDATES'
                WHEN ek.header_count IS NULL THEN N'NO_HEADER_CANDIDATE'
                ELSE NULL END AS match_result
    FROM lines AS l
    LEFT JOIN exact_key AS ek
      ON ISNULL(ek.branch_code,N'')=ISNULL(l.branch_code,N'')
     AND ek.parent_item_number=l.parent_item_number AND ek.blend_item_number=l.blend_item_number
     AND ek.workflow_status=l.workflow_status AND ek.revision_number=l.revision_number
    LEFT JOIN exact_name AS en
      ON ISNULL(en.branch_code,N'')=ISNULL(l.branch_code,N'')
     AND en.parent_item_number=l.parent_item_number AND en.blend_item_number=l.blend_item_number
     AND en.workflow_status=l.workflow_status AND en.revision_number=l.revision_number
     AND en.formula_name=l.formula_name
    LEFT JOIN status_ignored AS si
      ON ISNULL(si.branch_code,N'')=ISNULL(l.branch_code,N'')
     AND si.parent_item_number=l.parent_item_number AND si.blend_item_number=l.blend_item_number
     AND si.revision_number=l.revision_number
)
SELECT match_result,FMMCU,FMPRNT,FMBLND,FMSTUS,FMRVNO,FMNAME,
       FMRWNO,FMCHLD,FMDSCR,candidate_header_ids,candidate_statuses,
       candidate.id AS candidate_formula_header_id,
       candidate.branch_code AS header_branch_code,
       candidate.parent_item_number AS header_parent_item_number,
       candidate.blend_item_number AS header_blend_item_number,
       candidate.workflow_status AS header_workflow_status,
       candidate.revision_number AS header_revision_number,
       candidate.formula_name AS header_formula_name,
       candidate.customer_name AS header_customer_name,
       candidate.unit_type AS header_unit_type,
       candidate.size AS header_size,
       candidate.material_type AS header_material_type,
       candidate.legacy_transaction_julian_date AS header_julian_date,
       candidate.*
FROM classified AS line
LEFT JOIN [form].[formula_header] AS candidate
  ON line.match_result IN (
       N'EXACT_KEY_AMBIGUOUS',
       N'STATUS_DIFF_ONE_CANDIDATE',
       N'STATUS_DIFF_MULTIPLE_CANDIDATES'
     )
 AND ISNULL(NULLIF(LTRIM(RTRIM(candidate.branch_code)),N''),N'')
     = ISNULL(line.branch_code,N'')
 AND NULLIF(LTRIM(RTRIM(candidate.parent_item_number)),N'')=line.parent_item_number
 AND NULLIF(LTRIM(RTRIM(candidate.blend_item_number)),N'')=line.blend_item_number
 AND CONVERT(decimal(10,4),candidate.revision_number)=line.revision_number
 AND (
       line.match_result<>N'EXACT_KEY_AMBIGUOUS'
       OR UPPER(COALESCE(NULLIF(LTRIM(RTRIM(candidate.workflow_status)),N''),N'UNKNOWN'))
          =line.workflow_status
     )
WHERE line.match_result IS NOT NULL;
GO

SELECT match_result,COUNT_BIG(*) AS joined_rows
FROM [form].[vw_formula_line_match_review]
GROUP BY match_result ORDER BY match_result;

SELECT TOP (20) match_result,FMMCU,FMPRNT,FMBLND,FMSTUS,FMRVNO,FMNAME,
       FMRWNO,FMCHLD,candidate_header_ids,candidate_statuses,
       candidate_formula_header_id,header_formula_name,header_customer_name,header_julian_date
FROM [form].[vw_formula_line_match_review]
ORDER BY CASE match_result
    WHEN N'EXACT_KEY_AMBIGUOUS' THEN 1
    WHEN N'STATUS_DIFF_MULTIPLE_CANDIDATES' THEN 2
    WHEN N'STATUS_DIFF_ONE_CANDIDATE' THEN 3
    ELSE 4 END,
    FMPRNT,FMBLND,FMRWNO;
