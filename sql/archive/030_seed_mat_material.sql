USE [PLM_DEV];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() <> N'PLM_DEV'
    THROW 50000, 'Run this script only in PLM_DEV.', 1;

IF EXISTS (SELECT 1 FROM mat.material WHERE source_system = N'ASSISTANT')
    THROW 50001, 'Assistant reseed is in use; do not run the old Item-only seed.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    ;WITH source_keys AS (
        SELECT EXMCU AS branch_code, EXLITM AS item_number, 1 AS source_rank
        FROM dbo.Item_Extension
        UNION ALL SELECT RRMCU, RRLITM, 1 FROM dbo.Item_Regulatory_Requirement
        UNION ALL SELECT ALMCU, ALLITM, 1 FROM dbo.Item_Allergen
        UNION ALL SELECT CNMCU, CNLITM, 1 FROM dbo.Item_Country
        UNION ALL SELECT IPMCU, IPLITM, 1 FROM dbo.Item_Property
        UNION ALL SELECT ISMCU, ISLITM, 1 FROM dbo.Item_Solvent
        UNION ALL SELECT IVMCU, IVLITM, 1 FROM dbo.Item_Vendor_Part
        UNION ALL SELECT JDMCU, JDLITM, 2 FROM dbo.Item_JDE_Original
    ),
    material_keys AS (
        SELECT TRIM(branch_code) AS branch_code,
               TRIM(item_number) AS item_number,
               MIN(source_rank) AS source_rank
        FROM source_keys
        WHERE NULLIF(TRIM(branch_code), '') IS NOT NULL
          AND NULLIF(TRIM(item_number), '') IS NOT NULL
        GROUP BY TRIM(branch_code), TRIM(item_number)
    ),
    latest_jde AS (
        SELECT TRIM(JDMCU) AS branch_code,
               TRIM(JDLITM) AS item_number,
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
    SELECT k.branch_code,
           k.item_number,
           j.base_uom,
           j.stocking_type,
           CASE WHEN k.source_rank = 1 THEN N'PLM' ELSE N'JDE' END
    FROM material_keys AS k
    LEFT JOIN latest_jde AS j
      ON j.branch_code = k.branch_code
     AND j.item_number = k.item_number
     AND j.row_number = 1
    WHERE NOT EXISTS (
        SELECT 1
        FROM mat.material AS m WITH (UPDLOCK, HOLDLOCK)
        WHERE m.branch_code = k.branch_code
          AND m.item_number = k.item_number
    );

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT COUNT_BIG(*) AS material_rows
FROM mat.material;
