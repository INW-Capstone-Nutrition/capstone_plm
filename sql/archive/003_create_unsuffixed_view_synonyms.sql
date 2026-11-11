/*
    Create stable, unsuffixed synonyms for environment-suffixed source views.

    Run this script once with data_source_prod as the current database and once with
    data_source_crp as the current database. It infers `_prod` or `_crp` from the
    current database name.

    Examples:
      jde.vw_f4101_item_master_prod -> jde.vw_f4101_item_master
      jde.vw_f4101_item_master_crp  -> jde.vw_f4101_item_master

    Safety:
      - @Apply = 0 only prints the generated DDL.
      - @Apply = 1 applies it transactionally.
      - Existing synonyms with the target names are refreshed.
      - A table, view, function, or other non-synonym at a target name causes the
        script to stop instead of overwriting it.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Apply bit = 0; -- Review with 0, then change to 1 to apply.
DECLARE @SourceSuffixOverride sysname = NULL;
-- For PLM_DEV containing PROD-named views, set @SourceSuffixOverride = N'_prod'.

DECLARE @SourceSuffix sysname = COALESCE
(
    @SourceSuffixOverride,
    CASE
        WHEN LOWER(DB_NAME()) LIKE N'%[_]prod' THEN N'_prod'
        WHEN LOWER(DB_NAME()) LIKE N'%[_]crp'  THEN N'_crp'
        ELSE NULL
    END
);

IF @SourceSuffix IS NULL
BEGIN
    THROW 51000,
        'Cannot infer the view suffix. Run in data_source_prod or data_source_crp.',
        1;
END;

CREATE TABLE #view_synonym_map
(
    source_schema sysname NOT NULL,
    source_view sysname NOT NULL,
    synonym_schema sysname NOT NULL,
    synonym_name sysname NOT NULL,
    PRIMARY KEY (synonym_schema, synonym_name)
);

INSERT INTO #view_synonym_map
(
    source_schema,
    source_view,
    synonym_schema,
    synonym_name
)
SELECT
    s.name,
    v.name,
    s.name,
    LEFT(v.name, LEN(v.name) - LEN(@SourceSuffix))
FROM sys.views AS v
JOIN sys.schemas AS s
    ON s.schema_id = v.schema_id
WHERE RIGHT(LOWER(v.name), LEN(@SourceSuffix)) = @SourceSuffix;

IF NOT EXISTS (SELECT 1 FROM #view_synonym_map)
BEGIN
    DECLARE @NoViewsMessage nvarchar(2048) =
        N'No views ending in ' + QUOTENAME(@SourceSuffix, '''')
        + N' were found in ' + QUOTENAME(DB_NAME()) + N'.';
    THROW 51001, @NoViewsMessage, 1;
END;

/* Stop if an unsuffixed target is already occupied by anything except a synonym. */
IF EXISTS
(
    SELECT 1
    FROM #view_synonym_map AS m
    JOIN sys.schemas AS s
        ON s.name = m.synonym_schema
    JOIN sys.objects AS o
        ON  o.schema_id = s.schema_id
        AND o.name = m.synonym_name
    WHERE o.type <> 'SN'
)
BEGIN
    SELECT
        m.synonym_schema,
        m.synonym_name,
        o.type_desc AS conflicting_object_type
    FROM #view_synonym_map AS m
    JOIN sys.schemas AS s
        ON s.name = m.synonym_schema
    JOIN sys.objects AS o
        ON  o.schema_id = s.schema_id
        AND o.name = m.synonym_name
    WHERE o.type <> 'SN'
    ORDER BY m.synonym_schema, m.synonym_name;

    THROW 51002,
        'One or more unsuffixed names are occupied by non-synonym objects.',
        1;
END;

CREATE TABLE #commands
(
    command_order int IDENTITY(1,1) NOT NULL PRIMARY KEY,
    command_text nvarchar(max) NOT NULL
);

/* Refresh only synonyms managed by this suffix mapping. */
INSERT INTO #commands (command_text)
SELECT
    N'DROP SYNONYM '
    + QUOTENAME(m.synonym_schema) + N'.' + QUOTENAME(m.synonym_name) + N';'
FROM #view_synonym_map AS m
JOIN sys.schemas AS s
    ON s.name = m.synonym_schema
JOIN sys.synonyms AS sy
    ON  sy.schema_id = s.schema_id
    AND sy.name = m.synonym_name;

INSERT INTO #commands (command_text)
SELECT
    N'CREATE SYNONYM '
    + QUOTENAME(m.synonym_schema) + N'.' + QUOTENAME(m.synonym_name)
    + N' FOR '
    + QUOTENAME(DB_NAME()) + N'.'
    + QUOTENAME(m.source_schema) + N'.' + QUOTENAME(m.source_view) + N';'
FROM #view_synonym_map AS m;

IF @Apply = 0
BEGIN
    SELECT
        command_order,
        command_text
    FROM #commands
    ORDER BY command_order;

    SELECT
        source_object = QUOTENAME(DB_NAME()) + N'.'
            + QUOTENAME(source_schema) + N'.' + QUOTENAME(source_view),
        synonym_object = QUOTENAME(DB_NAME()) + N'.'
            + QUOTENAME(synonym_schema) + N'.' + QUOTENAME(synonym_name)
    FROM #view_synonym_map
    ORDER BY synonym_schema, synonym_name;

    RETURN;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @CommandNumber int = 1;
    DECLARE @CommandCount int = (SELECT COUNT(*) FROM #commands);
    DECLARE @Command nvarchar(max);

    WHILE @CommandNumber <= @CommandCount
    BEGIN
        SELECT @Command = command_text
        FROM #commands
        WHERE command_order = @CommandNumber;

        EXEC sys.sp_executesql @Command;
        SET @CommandNumber += 1;
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;

/* Post-deployment verification. */
SELECT
    synonym_object = QUOTENAME(SCHEMA_NAME(sy.schema_id)) + N'.' + QUOTENAME(sy.name),
    sy.base_object_name
FROM sys.synonyms AS sy
JOIN #view_synonym_map AS m
    ON  m.synonym_schema = SCHEMA_NAME(sy.schema_id)
    AND m.synonym_name = sy.name
ORDER BY synonym_object;
