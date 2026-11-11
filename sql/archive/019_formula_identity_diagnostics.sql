USE [PLM_DEV];
GO
SET NOCOUNT ON;

SELECT 'issue_view_rows' AS metric, COUNT_BIG(*) AS n FROM form.vw_formula_header_issues
UNION ALL SELECT 'issue_view_distinct_full_rows', COUNT_BIG(*) FROM (SELECT DISTINCT * FROM form.vw_formula_header_issues) AS d
UNION ALL SELECT 'issue_five_part_groups', COUNT_BIG(*) FROM (SELECT FHMCU,FHPRNT,FHBLND,FHSTUS,FHRVNO FROM form.vw_formula_header_issues GROUP BY FHMCU,FHPRNT,FHBLND,FHSTUS,FHRVNO) AS d
UNION ALL SELECT 'issue_seven_part_date_groups', COUNT_BIG(*) FROM (SELECT FHMCU,FHPRNT,FHBLND,FHSTUS,FHRVNO,FHCUSN,FHUSER,FHTRDJ FROM form.vw_formula_header_issues GROUP BY FHMCU,FHPRNT,FHBLND,FHSTUS,FHRVNO,FHCUSN,FHUSER,FHTRDJ) AS d;

SELECT FHMCU,FHPRNT,FHBLND,FHSTUS,FHRVNO,FHCUSN,FHUSER,FHTRDJ,
       COUNT_BIG(*) AS issue_rows, COUNT(DISTINCT FHNAME) AS names,
       COUNT(DISTINCT FHSIZE) AS sizes, COUNT(DISTINCT FHUNTY) AS units,
       MIN(FHNAME) AS first_name,MAX(FHNAME) AS last_name
FROM form.vw_formula_header_issues
GROUP BY FHMCU,FHPRNT,FHBLND,FHSTUS,FHRVNO,FHCUSN,FHUSER,FHTRDJ
ORDER BY issue_rows DESC,FHPRNT,FHBLND;

SELECT s.name AS schema_name,t.name AS table_name,c.column_id,c.name AS column_name,
       ty.name AS data_type,c.max_length,c.is_nullable,c.is_identity
FROM sys.tables AS t JOIN sys.schemas AS s ON s.schema_id=t.schema_id
JOIN sys.columns AS c ON c.object_id=t.object_id
JOIN sys.types AS ty ON ty.user_type_id=c.user_type_id
WHERE s.name='form' AND t.name IN ('formula','formula_header','formula_line','formula_review_issue')
ORDER BY t.name,c.column_id;

SELECT fk.name AS fk_name,OBJECT_SCHEMA_NAME(fk.parent_object_id) AS child_schema,
       OBJECT_NAME(fk.parent_object_id) AS child_table,
       OBJECT_SCHEMA_NAME(fk.referenced_object_id) AS parent_schema,
       OBJECT_NAME(fk.referenced_object_id) AS parent_table
FROM sys.foreign_keys AS fk
WHERE fk.referenced_object_id IN (OBJECT_ID('form.formula'),OBJECT_ID('form.formula_header'))
ORDER BY parent_table,child_table;

SELECT 'target_review_issues' AS metric, COUNT_BIG(*) AS n FROM form.formula_review_issue
UNION ALL SELECT 'target_formula_lines',COUNT_BIG(*) FROM form.formula_line
UNION ALL SELECT 'eligible_source_headers',COUNT_BIG(*) FROM dbo.Formula_Header WHERE NULLIF(LTRIM(RTRIM(FHPRNT)),'') IS NOT NULL AND NULLIF(LTRIM(RTRIM(FHBLND)),'') IS NOT NULL
UNION ALL SELECT 'eligible_source_lines',COUNT_BIG(*) FROM dbo.Formula_Item WHERE NULLIF(LTRIM(RTRIM(FMPRNT)),'') IS NOT NULL AND NULLIF(LTRIM(RTRIM(FMBLND)),'') IS NOT NULL;

SELECT review_status,issue_code,COUNT_BIG(*) AS n
FROM form.formula_review_issue GROUP BY review_status,issue_code ORDER BY n DESC;

WITH s AS (
 SELECT NULLIF(LTRIM(RTRIM(FHMCU)),'') AS branch_code,NULLIF(LTRIM(RTRIM(FHPRNT)),'') AS parent_item_number,
 NULLIF(LTRIM(RTRIM(FHBLND)),'') AS blend_item_number,
 UPPER(COALESCE(NULLIF(LTRIM(RTRIM(FHSTUS)),''),'UNKNOWN')) AS workflow_status,
 COALESCE(TRY_CONVERT(decimal(10,4),FHRVNO),0) AS revision_number,COUNT_BIG(*) AS n
 FROM dbo.Formula_Header
 WHERE NULLIF(LTRIM(RTRIM(FHPRNT)),'') IS NOT NULL AND NULLIF(LTRIM(RTRIM(FHBLND)),'') IS NOT NULL
 GROUP BY NULLIF(LTRIM(RTRIM(FHMCU)),''),NULLIF(LTRIM(RTRIM(FHPRNT)),''),NULLIF(LTRIM(RTRIM(FHBLND)),''),
 UPPER(COALESCE(NULLIF(LTRIM(RTRIM(FHSTUS)),''),'UNKNOWN')),COALESCE(TRY_CONVERT(decimal(10,4),FHRVNO),0)
), t AS (
 SELECT branch_code,parent_item_number,blend_item_number,UPPER(workflow_status) AS workflow_status,
 CONVERT(decimal(10,4),revision_number) AS revision_number,COUNT_BIG(*) AS n
 FROM form.formula_header
 WHERE parent_item_number IS NOT NULL AND blend_item_number IS NOT NULL
 GROUP BY branch_code,parent_item_number,blend_item_number,UPPER(workflow_status),CONVERT(decimal(10,4),revision_number)
)
SELECT SUM(CASE WHEN s.n IS NULL THEN 1 ELSE 0 END) AS target_only_groups,
 SUM(CASE WHEN t.n IS NULL THEN 1 ELSE 0 END) AS source_only_groups,
 SUM(CASE WHEN s.n<>t.n THEN 1 ELSE 0 END) AS differing_count_groups,
 SUM(CASE WHEN s.n>t.n THEN s.n-t.n ELSE 0 END) AS missing_target_rows,
 SUM(CASE WHEN t.n>s.n THEN t.n-s.n ELSE 0 END) AS extra_target_rows
FROM s FULL OUTER JOIN t ON ISNULL(s.branch_code,'')=ISNULL(t.branch_code,'')
 AND s.parent_item_number=t.parent_item_number AND s.blend_item_number=t.blend_item_number
 AND s.workflow_status=t.workflow_status AND s.revision_number=t.revision_number;

SELECT TOP (20) h.formula_header_id,h.formula_id,h.branch_code,h.parent_item_number,h.blend_item_number,
 h.workflow_status,h.revision_number,h.formula_name,h.customer_name,h.revision_author,h.legacy_transaction_julian_date,
 h.legacy_duplicate_sequence
FROM form.formula_header AS h
JOIN form.vw_formula_header_issues AS i
 ON h.branch_code=NULLIF(LTRIM(RTRIM(i.FHMCU)),'')
 AND h.parent_item_number=NULLIF(LTRIM(RTRIM(i.FHPRNT)),'')
 AND h.blend_item_number=NULLIF(LTRIM(RTRIM(i.FHBLND)),'')
 AND UPPER(h.workflow_status)=UPPER(i.FHSTUS)
 AND h.revision_number=TRY_CONVERT(decimal(16,8),i.FHRVNO)
ORDER BY h.formula_header_id;

SELECT 'eligible_rows' AS metric,COUNT_BIG(*) AS n FROM dbo.Formula_Header WHERE NULLIF(LTRIM(RTRIM(FHPRNT)),'') IS NOT NULL AND NULLIF(LTRIM(RTRIM(FHBLND)),'') IS NOT NULL
UNION ALL SELECT 'eligible_distinct_full_rows',COUNT_BIG(*) FROM (SELECT DISTINCT * FROM dbo.Formula_Header WHERE NULLIF(LTRIM(RTRIM(FHPRNT)),'') IS NOT NULL AND NULLIF(LTRIM(RTRIM(FHBLND)),'') IS NOT NULL) AS d
UNION ALL SELECT 'eligible_five_key_groups',COUNT_BIG(*) FROM (SELECT FHMCU,FHPRNT,FHBLND,FHSTUS,FHRVNO FROM dbo.Formula_Header WHERE NULLIF(LTRIM(RTRIM(FHPRNT)),'') IS NOT NULL AND NULLIF(LTRIM(RTRIM(FHBLND)),'') IS NOT NULL GROUP BY FHMCU,FHPRNT,FHBLND,FHSTUS,FHRVNO) AS d
UNION ALL SELECT 'target_five_key_groups',COUNT_BIG(*) FROM (SELECT branch_code,parent_item_number,blend_item_number,workflow_status,revision_number FROM form.formula_header WHERE NULLIF(LTRIM(RTRIM(parent_item_number)),'') IS NOT NULL AND NULLIF(LTRIM(RTRIM(blend_item_number)),'') IS NOT NULL GROUP BY branch_code,parent_item_number,blend_item_number,workflow_status,revision_number) AS d;

SELECT TOP (12) s.FHMCU,s.FHPRNT,s.FHBLND,s.FHSTUS,s.FHRVNO,s.FHNAME,s.FHCUSN,s.FHTRDJ
FROM dbo.Formula_Header AS s
WHERE NULLIF(LTRIM(RTRIM(s.FHPRNT)),'') IS NOT NULL AND NULLIF(LTRIM(RTRIM(s.FHBLND)),'') IS NOT NULL
AND NOT EXISTS (SELECT 1 FROM form.formula_header AS t WHERE ISNULL(t.branch_code,'')=ISNULL(NULLIF(LTRIM(RTRIM(s.FHMCU)),''),'')
 AND t.parent_item_number=NULLIF(LTRIM(RTRIM(s.FHPRNT)),'') AND t.blend_item_number=NULLIF(LTRIM(RTRIM(s.FHBLND)),'')
 AND UPPER(t.workflow_status)=UPPER(COALESCE(NULLIF(LTRIM(RTRIM(s.FHSTUS)),''),'Unknown'))
 AND t.revision_number=COALESCE(TRY_CONVERT(decimal(16,8),s.FHRVNO),0))
ORDER BY s.FHPRNT;

SELECT FHMCU,FHPRNT,FHBLND,FHSTUS,FHRVNO,COUNT_BIG(*) AS n,
 COUNT(DISTINCT FHNAME) AS names,COUNT(DISTINCT FHCUSN) AS customers,
 COUNT(DISTINCT FHTRDJ) AS dates,MIN(FHTRDJ) AS oldest,MAX(FHTRDJ) AS newest
FROM dbo.Formula_Header
WHERE NULLIF(LTRIM(RTRIM(FHPRNT)),'') IS NOT NULL AND NULLIF(LTRIM(RTRIM(FHBLND)),'') IS NOT NULL
GROUP BY FHMCU,FHPRNT,FHBLND,FHSTUS,FHRVNO HAVING COUNT_BIG(*)>1
ORDER BY n DESC,FHPRNT;
