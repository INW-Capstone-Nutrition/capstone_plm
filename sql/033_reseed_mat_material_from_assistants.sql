USE [PLM_DEV];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() <> N'PLM_DEV'
    THROW 50000, 'Run this script only in PLM_DEV.', 1;

-- Include Item-only keys outside test branch 05 so item specs retain parents.
DECLARE @include_item_only bit = 1;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.Formulation_Assistant_BP05', N'U') IS NULL
       OR OBJECT_ID(N'dbo.Formulation_Assistant_BP15', N'U') IS NULL
        THROW 50001, 'Snapshot BP05 and BP15 into PLM_DEV before reseeding.', 1;

    IF EXISTS (SELECT 1 FROM form.formula_line WHERE material_id IS NOT NULL)
       OR EXISTS (SELECT 1 FROM form.formula_line WHERE item_spec_id IS NOT NULL)
        THROW 50002, 'Formula lines still reference material or item specs; reseed formulas first.', 1;

    -- Clear PLM_DEV children before changing material identity values. The
    -- Alembic schema already owns their PK, FK and composite UNIQUE contracts.
    DELETE FROM spec.item_regulatory_req;
    DELETE FROM spec.item_allergen;
    DELETE FROM spec.item_country;
    DELETE FROM spec.item_property;
    DELETE FROM spec.item_solvent;
    DELETE FROM spec.item_vendor_part;
    DELETE FROM spec.item_spec;
    DELETE FROM mat.item_jde_original;
    DELETE FROM mat.formulation_assistant;

    ;WITH assistant_rows AS (
        SELECT COALESCE(NULLIF(TRIM(IB_branch), ''), NULLIF(TRIM(EX_branch), ''))
                   AS branch_code,
               COALESCE(NULLIF(TRIM(IB_item_number), ''),
                        NULLIF(TRIM(EX_item_number), '')) AS item_number,
               COALESCE(NULLIF(TRIM(Item_Description), ''),
                        NULLIF(TRIM(item_description_1), ''),
                        NULLIF(TRIM(item_description_2), '')) AS description,
               NULLIF(TRIM(Category), '') AS category,
               NULLIF(TRIM(primary_UOM), '') AS base_uom,
               NULLIF(TRIM(stocking_type), '') AS stocking_type,
               NULLIF(TRIM(tier_level), '') AS tier_level
        FROM dbo.Formulation_Assistant
        UNION ALL
        SELECT COALESCE(NULLIF(TRIM(IB_branch), ''), NULLIF(TRIM(EX_branch), '')),
               COALESCE(NULLIF(TRIM(IB_item_number), ''),
                        NULLIF(TRIM(EX_item_number), '')),
               COALESCE(NULLIF(TRIM(Item_Description), ''),
                        NULLIF(TRIM(item_description_1), ''),
                        NULLIF(TRIM(item_description_2), '')),
               NULLIF(TRIM(Category), ''), NULLIF(TRIM(primary_UOM), ''),
               NULLIF(TRIM(stocking_type), ''), NULLIF(TRIM(tier_level), '')
        FROM dbo.Formulation_Assistant_BP05
        UNION ALL
        SELECT COALESCE(NULLIF(TRIM(IB_branch), ''), NULLIF(TRIM(EX_branch), '')),
               COALESCE(NULLIF(TRIM(IB_item_number), ''),
                        NULLIF(TRIM(EX_item_number), '')),
               COALESCE(NULLIF(TRIM(item_description_1), ''),
                        NULLIF(TRIM(item_description_2), '')),
               NULLIF(TRIM(Category), ''), NULLIF(TRIM(primary_UOM), ''),
               NULLIF(TRIM(stocking_type), ''), NULLIF(TRIM(tier_level), '')
        FROM dbo.Formulation_Assistant_BP15
    )
    SELECT branch_code, item_number,
           MAX(description) AS description,
           MAX(category) AS category,
           MAX(base_uom) AS base_uom,
           MAX(stocking_type) AS stocking_type,
           MAX(tier_level) AS tier_level,
           COUNT(DISTINCT description) AS description_variants,
           COUNT(DISTINCT category) AS category_variants,
           COUNT(DISTINCT base_uom) AS uom_variants,
           COUNT(DISTINCT stocking_type) AS stocking_type_variants,
           COUNT(DISTINCT tier_level) AS tier_variants
    INTO #assistant_material
    FROM assistant_rows
    WHERE branch_code IS NOT NULL AND item_number IS NOT NULL
    GROUP BY branch_code, item_number;

    IF NOT EXISTS (SELECT 1 FROM #assistant_material)
        THROW 50003, 'The three assistant snapshots contain no usable keys.', 1;
    IF EXISTS (
        SELECT 1 FROM #assistant_material
        WHERE description_variants > 1 OR category_variants > 1
           OR uom_variants > 1 OR stocking_type_variants > 1 OR tier_variants > 1
    )
        THROW 50004, 'Assistant rows disagree on material attributes for a key.', 1;

    ;WITH item_keys AS (
        SELECT EXMCU AS branch_code, EXLITM AS item_number, 1 AS source_rank
        FROM dbo.Item_Extension
        UNION ALL SELECT RRMCU, RRLITM, 1 FROM dbo.Item_Regulatory_Requirement
        UNION ALL SELECT ALMCU, ALLITM, 1 FROM dbo.Item_Allergen
        UNION ALL SELECT CNMCU, CNLITM, 1 FROM dbo.Item_Country
        UNION ALL SELECT IPMCU, IPLITM, 1 FROM dbo.Item_Property
        UNION ALL SELECT ISMCU, ISLITM, 1 FROM dbo.Item_Solvent
        UNION ALL SELECT IVMCU, IVLITM, 1 FROM dbo.Item_Vendor_Part
        UNION ALL SELECT JDMCU, JDLITM, 2 FROM dbo.Item_JDE_Original
    )
    SELECT TRIM(branch_code) AS branch_code,
           TRIM(item_number) AS item_number,
           MIN(source_rank) AS source_rank
    INTO #item_material
    FROM item_keys
    WHERE NULLIF(TRIM(branch_code), '') IS NOT NULL
      AND NULLIF(TRIM(item_number), '') IS NOT NULL
    GROUP BY TRIM(branch_code), TRIM(item_number);

    DELETE FROM mat.material;

    IF EXISTS (SELECT 1 FROM sys.identity_columns
               WHERE object_id = OBJECT_ID('mat.material') AND last_value IS NOT NULL)
        DBCC CHECKIDENT ('mat.material', RESEED, 0) WITH NO_INFOMSGS;

    INSERT INTO mat.material (
        branch_code, item_number, description, category, base_uom,
        stocking_type, tier_level, source_system
    )
    SELECT branch_code, item_number, description, category, base_uom,
           stocking_type, tier_level, N'ASSISTANT'
    FROM #assistant_material;

    IF @include_item_only = 1
    BEGIN
        ;WITH latest_jde AS (
            SELECT TRIM(JDMCU) AS branch_code, TRIM(JDLITM) AS item_number,
                   NULLIF(TRIM(JDUOM1), '') AS base_uom,
                   NULLIF(TRIM(JDSTKT), '') AS stocking_type,
                   ROW_NUMBER() OVER (
                       PARTITION BY TRIM(JDMCU), TRIM(JDLITM)
                       ORDER BY JDTRDJ DESC
                   ) AS row_number
            FROM dbo.Item_JDE_Original
        )
        INSERT INTO mat.material (
            branch_code, item_number, base_uom, stocking_type, source_system
        )
        SELECT i.branch_code, i.item_number,
               j.base_uom, j.stocking_type,
               CASE WHEN i.source_rank = 1 THEN N'PLM' ELSE N'JDE' END
        FROM #item_material AS i
        LEFT JOIN latest_jde AS j
          ON j.branch_code = i.branch_code
         AND j.item_number = i.item_number AND j.row_number = 1
        WHERE i.branch_code <> N'05'
          AND NOT EXISTS (
            SELECT 1 FROM mat.material AS m
            WHERE m.branch_code = i.branch_code AND m.item_number = i.item_number
        );

        IF EXISTS (
            SELECT 1 FROM #item_material AS i
            WHERE i.branch_code <> N'05'
              AND NOT EXISTS (
                SELECT 1 FROM mat.material AS m
                WHERE m.branch_code = i.branch_code AND m.item_number = i.item_number
            )
        )
            THROW 50005, 'An Item snapshot key is missing from mat.material.', 1;
    END;

    IF (SELECT COUNT_BIG(*) FROM mat.material WHERE source_system = N'ASSISTANT')
       <> (SELECT COUNT_BIG(*) FROM #assistant_material)
        THROW 50006, 'Assistant material count did not reconcile.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT source_system, COUNT_BIG(*) AS material_rows,
       MIN(id) AS first_id, MAX(id) AS last_id
FROM mat.material
GROUP BY source_system
ORDER BY source_system;
