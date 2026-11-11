/*
  Compare the headers behind exact line-match conflicts before and after the
  123001 cutoff. One row per candidate header and conflicting line key/name.
  PLM_DEV only; neither source tables nor target headers are changed.
*/
USE [PLM_DEV];
GO

CREATE OR ALTER VIEW [form].[vw_formula_line_header_conflicts_123001]
AS
WITH lines AS (
    SELECT NULLIF(LTRIM(RTRIM(FMMCU)), N'') AS branch_code,
           NULLIF(LTRIM(RTRIM(FMPRNT)), N'') AS parent_item_number,
           NULLIF(LTRIM(RTRIM(FMBLND)), N'') AS blend_item_number,
           UPPER(COALESCE(NULLIF(LTRIM(RTRIM(FMSTUS)), N''), N'UNKNOWN')) AS workflow_status,
           COALESCE(TRY_CONVERT(decimal(10,4), FMRVNO), 0) AS revision_number,
           UPPER(NULLIF(LTRIM(RTRIM(FMNAME)), N'')) AS line_formula_name,
           COUNT_BIG(*) AS line_rows
    FROM [dbo].[Formula_Item]
    WHERE NULLIF(LTRIM(RTRIM(FMPRNT)), N'') IS NOT NULL
      AND NULLIF(LTRIM(RTRIM(FMBLND)), N'') IS NOT NULL
    GROUP BY NULLIF(LTRIM(RTRIM(FMMCU)), N''),
             NULLIF(LTRIM(RTRIM(FMPRNT)), N''),
             NULLIF(LTRIM(RTRIM(FMBLND)), N''),
             UPPER(COALESCE(NULLIF(LTRIM(RTRIM(FMSTUS)), N''), N'UNKNOWN')),
             COALESCE(TRY_CONVERT(decimal(10,4), FMRVNO), 0),
             UPPER(NULLIF(LTRIM(RTRIM(FMNAME)), N''))
), headers AS (
    SELECT id AS formula_header_id,branch_code,parent_item_number,blend_item_number,
           UPPER(COALESCE(NULLIF(LTRIM(RTRIM(workflow_status)), N''), N'UNKNOWN')) AS workflow_status,
           CONVERT(decimal(10,4),revision_number) AS revision_number,
           formula_name,UPPER(NULLIF(LTRIM(RTRIM(formula_name)), N'')) AS normalized_formula_name,
           customer_name,legacy_transaction_julian_date
    FROM [form].[formula_header]
), header_keys AS (
    SELECT branch_code,parent_item_number,blend_item_number,workflow_status,
           revision_number,COUNT_BIG(*) AS header_count
    FROM headers
    GROUP BY branch_code,parent_item_number,blend_item_number,workflow_status,revision_number
), name_keys AS (
    SELECT branch_code,parent_item_number,blend_item_number,workflow_status,
           revision_number,normalized_formula_name,COUNT_BIG(*) AS name_header_count
    FROM headers
    GROUP BY branch_code,parent_item_number,blend_item_number,workflow_status,
             revision_number,normalized_formula_name
), conflicts AS (
    SELECT l.*
    FROM lines AS l
    JOIN header_keys AS hk
      ON ISNULL(hk.branch_code,N'')=ISNULL(l.branch_code,N'')
     AND hk.parent_item_number=l.parent_item_number
     AND hk.blend_item_number=l.blend_item_number
     AND hk.workflow_status=l.workflow_status
     AND hk.revision_number=l.revision_number
    LEFT JOIN name_keys AS nk
      ON ISNULL(nk.branch_code,N'')=ISNULL(l.branch_code,N'')
     AND nk.parent_item_number=l.parent_item_number
     AND nk.blend_item_number=l.blend_item_number
     AND nk.workflow_status=l.workflow_status
     AND nk.revision_number=l.revision_number
     AND nk.normalized_formula_name=l.line_formula_name
    WHERE hk.header_count > 1 AND ISNULL(nk.name_header_count,0) <> 1
), candidates AS (
    SELECT c.line_rows,c.line_formula_name,h.formula_header_id,
           h.branch_code,h.parent_item_number,h.blend_item_number,
           h.workflow_status,h.revision_number,h.formula_name,h.customer_name,
           h.legacy_transaction_julian_date,
           CASE WHEN h.legacy_transaction_julian_date>=123001 THEN 1 ELSE 0 END
             AS passes_cutoff,
           CASE WHEN h.normalized_formula_name=c.line_formula_name THEN 1 ELSE 0 END
             AS name_matches_line
    FROM conflicts AS c
    JOIN headers AS h
      ON ISNULL(h.branch_code,N'')=ISNULL(c.branch_code,N'')
     AND h.parent_item_number=c.parent_item_number
     AND h.blend_item_number=c.blend_item_number
     AND h.workflow_status=c.workflow_status
     AND h.revision_number=c.revision_number
), counted AS (
    SELECT candidates.*,
           SUM(passes_cutoff) OVER (
             PARTITION BY branch_code,parent_item_number,blend_item_number,
                          workflow_status,revision_number,line_formula_name
           ) AS headers_after_cutoff,
           SUM(CASE WHEN passes_cutoff=1 AND name_matches_line=1 THEN 1 ELSE 0 END)
             OVER (PARTITION BY branch_code,parent_item_number,blend_item_number,
                                workflow_status,revision_number,line_formula_name)
             AS matching_names_after_cutoff
    FROM candidates
)
SELECT line_rows,branch_code,parent_item_number,blend_item_number,
       workflow_status,revision_number,line_formula_name,
       formula_header_id,formula_name,customer_name,legacy_transaction_julian_date,
       passes_cutoff,headers_after_cutoff,
       CONVERT(bit,CASE WHEN headers_after_cutoff>1 AND matching_names_after_cutoff<>1
                        THEN 1 ELSE 0 END) AS still_ambiguous_after_cutoff
FROM counted;
GO

SELECT line_rows,branch_code,parent_item_number,blend_item_number,
       workflow_status,revision_number,line_formula_name,
       formula_header_id,formula_name,customer_name,legacy_transaction_julian_date,
       passes_cutoff,headers_after_cutoff,still_ambiguous_after_cutoff
FROM [form].[vw_formula_line_header_conflicts_123001]
ORDER BY parent_item_number,blend_item_number,workflow_status,revision_number,
         line_formula_name,formula_header_id;
