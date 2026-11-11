/*
    Minimal legacy issue views for review by the original project owner.

    Approved business rules:
      1. Header duplicates use this seven-column business key:
           FHMCU, FHPRNT, FHBLND, FHSTUS, FHRVNO, FHCUSN, FHUSER
         The row having the latest FHTRDJ is retained automatically. If two or
         more rows tie for that latest date, every tied row remains an issue.
      2. A Formula_Item row is an orphan when it has no Formula_Header match on:
           FMMCU  = FHMCU
           FMPRNT = FHPRNT
           FMBLND = FHBLND
           FMSTUS = FHSTUS
           FMRVNO = FHRVNO
      3. Rows with a null, empty, or whitespace-only parent OR blend are excluded
         from both owner-review views.

    Output intentionally contains only original legacy columns, with their
    original names and order. All reads are from the frozen PLM_DEV snapshot.
*/

USE [PLM_DEV];
GO

CREATE OR ALTER VIEW [form].[vw_formula_header_issues]
AS
WITH normalized AS
(
    SELECT
        header.*,
        NULLIF(LTRIM(RTRIM(header.[FHMCU])), N'') AS normalized_branch,
        NULLIF(LTRIM(RTRIM(header.[FHPRNT])), N'') AS normalized_parent,
        NULLIF(LTRIM(RTRIM(header.[FHBLND])), N'') AS normalized_blend,
        UPPER(COALESCE(NULLIF(LTRIM(RTRIM(header.[FHSTUS])), N''), N'UNKNOWN'))
            AS normalized_status,
        COALESCE(TRY_CONVERT(decimal(10, 4), header.[FHRVNO]), CONVERT(decimal(10, 4), 0))
            AS normalized_revision,
        UPPER(COALESCE(NULLIF(LTRIM(RTRIM(header.[FHCUSN])), N''), N'[BLANK]'))
            AS normalized_customer,
        UPPER(COALESCE(NULLIF(LTRIM(RTRIM(header.[FHUSER])), N''), N'[BLANK]'))
            AS normalized_entry_user
    FROM [PLM_DEV].[dbo].[Formula_Header] AS header
    WHERE NULLIF(LTRIM(RTRIM(header.[FHPRNT])), N'') IS NOT NULL
      AND NULLIF(LTRIM(RTRIM(header.[FHBLND])), N'') IS NOT NULL
),
ranked AS
(
    SELECT
        normalized.*,
        COUNT_BIG(*) OVER
        (
            PARTITION BY
                normalized_branch,
                normalized_parent,
                normalized_blend,
                normalized_status,
                normalized_revision,
                normalized_customer,
                normalized_entry_user
        ) AS duplicate_row_count,
        COUNT_BIG(*) OVER
        (
            PARTITION BY
                normalized_branch,
                normalized_parent,
                normalized_blend,
                normalized_status,
                normalized_revision,
                normalized_customer,
                normalized_entry_user,
                [FHTRDJ]
        ) AS same_date_row_count,
        DENSE_RANK() OVER
        (
            PARTITION BY
                normalized_branch,
                normalized_parent,
                normalized_blend,
                normalized_status,
                normalized_revision,
                normalized_customer,
                normalized_entry_user
            ORDER BY
                CASE WHEN [FHTRDJ] IS NULL THEN 1 ELSE 0 END,
                [FHTRDJ] DESC
        ) AS latest_date_rank
    FROM normalized
)
SELECT
    ranked.[FHMCU],
    ranked.[FHPRNT],
    ranked.[FHBLND],
    ranked.[FHNAME],
    ranked.[FHRVNO],
    ranked.[FHSTUS],
    ranked.[FHCUSN],
    ranked.[FHCUSP],
    ranked.[FHUSER],
    ranked.[FHUNTY],
    ranked.[FHSIZE],
    ranked.[FHTYPM],
    ranked.[FHFMCT],
    ranked.[FHCLOR],
    ranked.[FHDOSE],
    ranked.[FHSRVG],
    ranked.[FHDLYD],
    ranked.[FHHOBN],
    ranked.[FHRMM],
    ranked.[FHOVRA],
    ranked.[FHMTCP],
    ranked.[FHSLDS],
    ranked.[FHWGHT],
    ranked.[FHCWAX],
    ranked.[FHCHNG],
    ranked.[FHECDV],
    ranked.[FHTRDJ],
    ranked.[FHNOTE],
    ranked.[FHADDL]
FROM ranked
WHERE ranked.duplicate_row_count > 1
  AND ranked.latest_date_rank = 1
  AND ranked.same_date_row_count > 1;
GO

CREATE OR ALTER VIEW [form].[vw_formula_line_issues]
AS
WITH normalized_lines AS
(
    SELECT
        item.*,
        NULLIF(LTRIM(RTRIM(item.[FMMCU])), N'') AS normalized_branch,
        NULLIF(LTRIM(RTRIM(item.[FMPRNT])), N'') AS normalized_parent,
        NULLIF(LTRIM(RTRIM(item.[FMBLND])), N'') AS normalized_blend,
        UPPER(COALESCE(NULLIF(LTRIM(RTRIM(item.[FMSTUS])), N''), N'UNKNOWN'))
            AS normalized_status,
        COALESCE(TRY_CONVERT(decimal(10, 4), item.[FMRVNO]), CONVERT(decimal(10, 4), 0))
            AS normalized_revision
    FROM [PLM_DEV].[dbo].[Formula_Item] AS item
    WHERE NULLIF(LTRIM(RTRIM(item.[FMPRNT])), N'') IS NOT NULL
      AND NULLIF(LTRIM(RTRIM(item.[FMBLND])), N'') IS NOT NULL
),
normalized_headers AS
(
    SELECT DISTINCT
        NULLIF(LTRIM(RTRIM(header.[FHMCU])), N'') AS normalized_branch,
        NULLIF(LTRIM(RTRIM(header.[FHPRNT])), N'') AS normalized_parent,
        NULLIF(LTRIM(RTRIM(header.[FHBLND])), N'') AS normalized_blend,
        UPPER(COALESCE(NULLIF(LTRIM(RTRIM(header.[FHSTUS])), N''), N'UNKNOWN'))
            AS normalized_status,
        COALESCE(TRY_CONVERT(decimal(10, 4), header.[FHRVNO]), CONVERT(decimal(10, 4), 0))
            AS normalized_revision
    FROM [PLM_DEV].[dbo].[Formula_Header] AS header
    WHERE NULLIF(LTRIM(RTRIM(header.[FHPRNT])), N'') IS NOT NULL
      AND NULLIF(LTRIM(RTRIM(header.[FHBLND])), N'') IS NOT NULL
)
SELECT
    line.[FMRWNO],
    line.[FMMCU],
    line.[FMPRNT],
    line.[FMBLND],
    line.[FMCHLD],
    line.[FMRVNO],
    line.[FMSTUS],
    line.[FMDSCR],
    line.[FMTMRK],
    line.[FMVEND],
    line.[FMQUOT],
    line.[FMCOST],
    line.[FMNAME],
    line.[FMUSER],
    line.[FMPTNC],
    line.[FMPTUM],
    line.[FMTIVE],
    line.[FMOVRA],
    line.[FMGORY],
    line.[FMDLYD],
    line.[FMMGTB],
    line.[FMMGMO],
    line.[FMPRFM],
    line.[FMPCST],
    line.[FMPRNC],
    line.[FMPRNV],
    line.[FMNOTE]
FROM normalized_lines AS line
WHERE NOT EXISTS
(
    SELECT 1
    FROM normalized_headers AS header
    WHERE ISNULL(header.normalized_branch, N'') = ISNULL(line.normalized_branch, N'')
      AND header.normalized_parent = line.normalized_parent
      AND header.normalized_blend = line.normalized_blend
      AND header.normalized_status = line.normalized_status
      AND header.normalized_revision = line.normalized_revision
);
GO

/* Backward-compatible name retained for existing queries and reports. */
CREATE OR ALTER VIEW [form].[vw_formula_item_issues]
AS
SELECT
    line.[FMRWNO],
    line.[FMMCU],
    line.[FMPRNT],
    line.[FMBLND],
    line.[FMCHLD],
    line.[FMRVNO],
    line.[FMSTUS],
    line.[FMDSCR],
    line.[FMTMRK],
    line.[FMVEND],
    line.[FMQUOT],
    line.[FMCOST],
    line.[FMNAME],
    line.[FMUSER],
    line.[FMPTNC],
    line.[FMPTUM],
    line.[FMTIVE],
    line.[FMOVRA],
    line.[FMGORY],
    line.[FMDLYD],
    line.[FMMGTB],
    line.[FMMGMO],
    line.[FMPRFM],
    line.[FMPCST],
    line.[FMPRNC],
    line.[FMPRNV],
    line.[FMNOTE]
FROM [form].[vw_formula_line_issues] AS line;
GO

/*
    Clean owner-review queries:

    SELECT *
    FROM form.vw_formula_header_issues
    ORDER BY FHMCU, FHPRNT, FHBLND, FHSTUS, FHRVNO,
             FHCUSN, FHUSER, FHTRDJ DESC, FHNAME;

    SELECT *
    FROM form.vw_formula_line_issues
    ORDER BY FMMCU, FMPRNT, FMBLND, FMSTUS, FMRVNO, FMRWNO, FMCHLD;
*/
