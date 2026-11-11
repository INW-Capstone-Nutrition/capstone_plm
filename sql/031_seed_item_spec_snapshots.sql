USE [PLM_DEV];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() <> N'PLM_DEV'
    THROW 50000, 'Run this script only in PLM_DEV.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM mat.material)
        THROW 50001, 'Seed mat.material before item specs.', 1;

    IF EXISTS (SELECT 1 FROM form.formula_line WHERE item_spec_id IS NOT NULL)
        THROW 50002, 'Formula lines still reference item specs; reseed formulas first.', 1;

    DELETE FROM spec.item_regulatory_req;
    DELETE FROM spec.item_allergen;
    DELETE FROM spec.item_country;
    DELETE FROM spec.item_property;
    DELETE FROM spec.item_solvent;
    DELETE FROM spec.item_vendor_part;
    DELETE FROM spec.item_spec;
    DELETE FROM mat.item_jde_original;

    IF EXISTS (SELECT 1 FROM sys.identity_columns
               WHERE object_id = OBJECT_ID('spec.item_spec') AND last_value IS NOT NULL)
        DBCC CHECKIDENT ('spec.item_spec', RESEED, 0) WITH NO_INFOMSGS;
    IF EXISTS (SELECT 1 FROM sys.identity_columns
               WHERE object_id = OBJECT_ID('spec.item_regulatory_req') AND last_value IS NOT NULL)
        DBCC CHECKIDENT ('spec.item_regulatory_req', RESEED, 0) WITH NO_INFOMSGS;
    IF EXISTS (SELECT 1 FROM sys.identity_columns
               WHERE object_id = OBJECT_ID('spec.item_allergen') AND last_value IS NOT NULL)
        DBCC CHECKIDENT ('spec.item_allergen', RESEED, 0) WITH NO_INFOMSGS;
    IF EXISTS (SELECT 1 FROM sys.identity_columns
               WHERE object_id = OBJECT_ID('spec.item_country') AND last_value IS NOT NULL)
        DBCC CHECKIDENT ('spec.item_country', RESEED, 0) WITH NO_INFOMSGS;
    IF EXISTS (SELECT 1 FROM sys.identity_columns
               WHERE object_id = OBJECT_ID('spec.item_property') AND last_value IS NOT NULL)
        DBCC CHECKIDENT ('spec.item_property', RESEED, 0) WITH NO_INFOMSGS;
    IF EXISTS (SELECT 1 FROM sys.identity_columns
               WHERE object_id = OBJECT_ID('spec.item_solvent') AND last_value IS NOT NULL)
        DBCC CHECKIDENT ('spec.item_solvent', RESEED, 0) WITH NO_INFOMSGS;
    IF EXISTS (SELECT 1 FROM sys.identity_columns
               WHERE object_id = OBJECT_ID('spec.item_vendor_part') AND last_value IS NOT NULL)
        DBCC CHECKIDENT ('spec.item_vendor_part', RESEED, 0) WITH NO_INFOMSGS;
    IF EXISTS (SELECT 1 FROM sys.identity_columns
               WHERE object_id = OBJECT_ID('mat.item_jde_original') AND last_value IS NOT NULL)
        DBCC CHECKIDENT ('mat.item_jde_original', RESEED, 0) WITH NO_INFOMSGS;

    IF EXISTS (
        SELECT 1
        FROM (
            SELECT EXMCU AS branch_code, EXLITM AS item_number FROM dbo.Item_Extension
            UNION ALL SELECT RRMCU, RRLITM FROM dbo.Item_Regulatory_Requirement
            UNION ALL SELECT ALMCU, ALLITM FROM dbo.Item_Allergen
            UNION ALL SELECT CNMCU, CNLITM FROM dbo.Item_Country
            UNION ALL SELECT IPMCU, IPLITM FROM dbo.Item_Property
            UNION ALL SELECT ISMCU, ISLITM FROM dbo.Item_Solvent
            UNION ALL SELECT IVMCU, IVLITM FROM dbo.Item_Vendor_Part
            UNION ALL SELECT JDMCU, JDLITM FROM dbo.Item_JDE_Original
        ) AS source_keys
        WHERE NULLIF(TRIM(branch_code), '') IS NOT NULL
          AND NULLIF(TRIM(item_number), '') IS NOT NULL
          AND TRIM(branch_code) <> N'05'
          AND NOT EXISTS (
              SELECT 1 FROM mat.material AS m
              WHERE m.branch_code = TRIM(source_keys.branch_code)
                AND m.item_number = TRIM(source_keys.item_number)
          )
    )
        THROW 50003, 'A valid source branch/item is missing from mat.material.', 1;

    CREATE TABLE #spec_source (
        material_id int NOT NULL,
        source_branch_code nvarchar(12) NULL,
        source_item_number nvarchar(40) NULL,
        revision int NOT NULL,
        source_count bigint NOT NULL,
        PRIMARY KEY (material_id, revision)
    );

    INSERT INTO #spec_source (
        material_id, source_branch_code, source_item_number, revision, source_count
    )
    SELECT m.id, e.EXMCU, e.EXLITM,
           ROW_NUMBER() OVER (
               PARTITION BY m.id
               ORDER BY COALESCE(e.EXMDON, e.EXCRON) DESC,
                        CASE WHEN e.EXLITM = TRIM(e.EXLITM) THEN 0 ELSE 1 END,
                        e.EXLITM
           ),
           COUNT_BIG(*) OVER (PARTITION BY m.id)
    FROM dbo.Item_Extension AS e
    JOIN mat.material AS m
      ON m.branch_code = TRIM(e.EXMCU)
     AND m.item_number = TRIM(e.EXLITM);

    INSERT INTO #spec_source (material_id, revision, source_count)
    SELECT p.material_id, 1, 0
    FROM (
        SELECT m.id AS material_id
        FROM (
            SELECT RRMCU AS branch_code, RRLITM AS item_number
            FROM dbo.Item_Regulatory_Requirement
            UNION ALL SELECT ALMCU, ALLITM FROM dbo.Item_Allergen
            UNION ALL SELECT CNMCU, CNLITM FROM dbo.Item_Country
            UNION ALL SELECT IPMCU, IPLITM FROM dbo.Item_Property
            UNION ALL SELECT ISMCU, ISLITM FROM dbo.Item_Solvent
            UNION ALL SELECT IVMCU, IVLITM FROM dbo.Item_Vendor_Part
        ) AS child_keys
        JOIN mat.material AS m
          ON m.branch_code = TRIM(child_keys.branch_code)
         AND m.item_number = TRIM(child_keys.item_number)
        GROUP BY m.id
    ) AS p
    WHERE NOT EXISTS (
        SELECT 1 FROM #spec_source AS s WHERE s.material_id = p.material_id
    );

    INSERT INTO spec.item_spec (
        material_id, revision, review_status, allergen_status,
        appearance, color, item_type, physical_form, plm_item_status,
        item_class, icnt_code, major_rev, minor_rev, is_released,
        plant_type, plant_extract_ratio, reference_note,
        herbal_component_product_name, latin_name, trademark,
        analyte, potency, potency_uom, cas,
        minimum_capsule_wt, maximum_capsule_wt, average_capsule_wt,
        special_handling, special_storage, safety_information, other_information,
        created_at, created_by, modified_at, modified_by
    )
    SELECT s.material_id, s.revision,
           CASE WHEN s.source_count = 2
                     AND TRIM(s.source_branch_code) = N'10'
                     AND TRIM(s.source_item_number) = N'1046502'
                     AND EXISTS (
                         SELECT 1 FROM dbo.Item_Extension AS leaf
                         WHERE TRIM(leaf.EXMCU) = N'10'
                           AND TRIM(leaf.EXLITM) = N'1046502'
                           AND leaf.EXPLPT = N'Leaf'
                     )
                     AND EXISTS (
                         SELECT 1 FROM dbo.Item_Extension AS leaves
                         WHERE TRIM(leaves.EXMCU) = N'10'
                           AND TRIM(leaves.EXLITM) = N'1046502'
                           AND leaves.EXPLPT = N'Leaves'
                     ) THEN N'IMPORTED'
                WHEN s.source_count > 1 THEN N'IMPORT_CONFLICT'
                WHEN s.source_count = 0 THEN N'SOURCE_MISSING'
                ELSE N'IMPORTED' END,
           e.EXALRG, e.EXAPPE, e.EXCLOR, e.EXITY, e.EXPSYF, e.EXSTA,
           e.EXCLAS, e.EXICNT, e.EXMAJR, e.EXMNOR,
           CASE WHEN UPPER(TRIM(e.EXRLSD)) IN (N'YES', N'Y', N'1', N'TRUE') THEN 1
                WHEN UPPER(TRIM(e.EXRLSD)) IN (N'NO', N'N', N'0', N'FALSE') THEN 0
                ELSE NULL END,
           e.EXPLPT, e.EXPEXR, e.EXREF, e.EXHCPN, e.EXLATN, e.EXTMRK,
           e.EXNLYT, CONVERT(decimal(24,8), e.EXPTNC), e.EXPTUM, e.EXCAS,
           e.EXMNCP, e.EXMXCP, e.EXAVCP,
           e.EXSPLH, e.EXSPLS, e.EXSAFT, e.EXUTHR,
           e.EXCRON, e.EXCRBY, e.EXMDON, e.EXMDBY
    FROM #spec_source AS s
    LEFT JOIN dbo.Item_Extension AS e
      ON e.EXMCU = s.source_branch_code
     AND e.EXLITM = s.source_item_number;

    SELECT t.id AS item_spec_id, s.material_id, s.revision,
           s.source_branch_code, s.source_item_number
    INTO #spec_link
    FROM #spec_source AS s
    JOIN spec.item_spec AS t
      ON t.material_id = s.material_id AND t.revision = s.revision;

    -- Keep one copy only when every source value except its identity ID matches.
    -- BIN2 plus DATALENGTH distinguishes case and trailing spaces.
    SELECT source.*
    INTO #allergen_source
    FROM (
        SELECT a.*,
               ROW_NUMBER() OVER (
                   PARTITION BY
                    a.ALMCU COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(a.ALMCU),
                    a.ALLITM COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(a.ALLITM),
                    a.ALALRG COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(a.ALALRG),
                    a.ALPSNT COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(a.ALPSNT),
                    a.ALSALL COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(a.ALSALL),
                    a.ALCMTS COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(a.ALCMTS)
                   ORDER BY a.ALIDNT
               ) AS duplicate_rank
        FROM dbo.Item_Allergen AS a
        JOIN mat.material AS m
          ON m.branch_code = TRIM(a.ALMCU)
         AND m.item_number = TRIM(a.ALLITM)
    ) AS source
    WHERE source.duplicate_rank = 1;

    SELECT source.*
    INTO #country_source
    FROM (
        SELECT c.*,
               ROW_NUMBER() OVER (
                   PARTITION BY
                    c.CNMCU COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(c.CNMCU),
                    c.CNLITM COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(c.CNLITM),
                    c.CNCTR COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(c.CNCTR),
                    c.CNCTRT COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(c.CNCTRT),
                    c.CNCOTP COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(c.CNCOTP)
                   ORDER BY c.CNIDNT
               ) AS duplicate_rank
        FROM dbo.Item_Country AS c
        JOIN mat.material AS m
          ON m.branch_code = TRIM(c.CNMCU)
         AND m.item_number = TRIM(c.CNLITM)
    ) AS source
    WHERE source.duplicate_rank = 1;

    SELECT source.*
    INTO #property_source
    FROM (
        SELECT p.*,
               ROW_NUMBER() OVER (
                   PARTITION BY
                    p.IPMCU COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(p.IPMCU),
                    p.IPLITM COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(p.IPLITM),
                    p.IPSPCT COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(p.IPSPCT),
                    p.IPPTTY COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(p.IPPTTY),
                    p.IPPRPT COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(p.IPPRPT),
                    p.IPPPMN COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(p.IPPPMN),
                    p.IPPTRG COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(p.IPPTRG),
                    p.IPPPMX COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(p.IPPPMX),
                    p.IPUM COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(p.IPUM),
                    p.IPRZLT COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(p.IPRZLT),
                    p.IPFREQ COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(p.IPFREQ),
                    p.IPMEHD COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(p.IPMEHD),
                    p.IPSRPT COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(p.IPSRPT),
                    p.IPSCOA COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(p.IPSCOA),
                    p.IPSLAB COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(p.IPSLAB)
                   ORDER BY p.IPIDNT
               ) AS duplicate_rank
        FROM dbo.Item_Property AS p
        JOIN mat.material AS m
          ON m.branch_code = TRIM(p.IPMCU)
         AND m.item_number = TRIM(p.IPLITM)
    ) AS source
    WHERE source.duplicate_rank = 1;

    SELECT source.*
    INTO #solvent_source
    FROM (
        SELECT v.*,
               ROW_NUMBER() OVER (
                   PARTITION BY
                    v.ISMCU COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(v.ISMCU),
                    v.ISLITM COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(v.ISLITM),
                    v.ISRTIO COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(v.ISRTIO),
                    v.ISSLVT COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(v.ISSLVT),
                    v.ISSNME COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(v.ISSNME),
                    v.ISSLVN COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(v.ISSLVN)
                   ORDER BY v.ISIDNT
               ) AS duplicate_rank
        FROM dbo.Item_Solvent AS v
        JOIN mat.material AS m
          ON m.branch_code = TRIM(v.ISMCU)
         AND m.item_number = TRIM(v.ISLITM)
    ) AS source
    WHERE source.duplicate_rank = 1;

    SELECT source.*
    INTO #vendor_part_source
    FROM (
        SELECT v.*,
               ROW_NUMBER() OVER (
                   PARTITION BY
                    v.IVMCU COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(v.IVMCU),
                    v.IVLITM COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(v.IVLITM),
                    v.IVVNDN COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(v.IVVNDN),
                    v.IVPRNC COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(v.IVPRNC),
                    v.IVVPNO COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(v.IVVPNO),
                    v.IVMPNO COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(v.IVMPNO),
                    v.IVMPNM COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(v.IVMPNM),
                    v.IVMFGN COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(v.IVMFGN),
                    v.IVCTR COLLATE Latin1_General_100_BIN2,
                    DATALENGTH(v.IVCTR),
                    v.IVVEND
                   ORDER BY v.IVIDNT
               ) AS duplicate_rank
        FROM dbo.Item_Vendor_Part AS v
        JOIN mat.material AS m
          ON m.branch_code = TRIM(v.IVMCU)
         AND m.item_number = TRIM(v.IVLITM)
    ) AS source
    WHERE source.duplicate_rank = 1;


    SELECT link.item_spec_id, r.*
    INTO #reg_source
    FROM dbo.Item_Regulatory_Requirement AS r
    JOIN mat.material AS m
      ON m.branch_code = TRIM(r.RRMCU) AND m.item_number = TRIM(r.RRLITM)
    CROSS APPLY (
        SELECT TOP (1) l.item_spec_id
        FROM #spec_link AS l
        WHERE l.material_id = m.id
        ORDER BY CASE WHEN l.source_branch_code = r.RRMCU
                           AND l.source_item_number = r.RRLITM THEN 0 ELSE 1 END,
                 l.revision
    ) AS link;

    IF EXISTS (
        SELECT 1 FROM #reg_source
        GROUP BY item_spec_id HAVING COUNT_BIG(*) > 1
    )
        THROW 50004, 'Multiple regulatory rows resolve to one item spec.', 1;

    INSERT INTO spec.item_regulatory_req (
        item_spec_id, gmo_status, halal_status, kosher_status,
        usp_pest_status, preservative_status, gluten_status, bse_status,
        non_novel_status, gras_status, vegetarian_status, vegan_status,
        organic_status, wada_status, ndi_status, synthetic_status,
        nsf_value, gluten_free_certified_status, fragrance_status,
        preference_code, bioengineered_status
    )
    SELECT item_spec_id, RRGMO, RRHALA, RRKOSH, RRUSP, RRPRSV,
           RRGLTN, RRBSE, RRNNET, RRGRAS, RRVGTR, RRVEGN,
           RROGNC, RRWADA, RRNDI, RRSYNT, CONVERT(decimal(18,8), RRNSF),
           RRGFCO, RRFRIG, RRPREF, RRBIO
    FROM #reg_source;

    INSERT INTO spec.item_allergen (
        item_spec_id, allergen_name, present_status, specific_allergen, comments
    )
    SELECT link.item_spec_id, a.ALALRG, a.ALPSNT, a.ALSALL, a.ALCMTS
    FROM #allergen_source AS a
    JOIN mat.material AS m
      ON m.branch_code = TRIM(a.ALMCU) AND m.item_number = TRIM(a.ALLITM)
    CROSS APPLY (
        SELECT TOP (1) l.item_spec_id FROM #spec_link AS l
        WHERE l.material_id = m.id
        ORDER BY CASE WHEN l.source_branch_code = a.ALMCU
                           AND l.source_item_number = a.ALLITM THEN 0 ELSE 1 END,
                 l.revision
    ) AS link;

    INSERT INTO spec.item_country (
        item_spec_id, country_name, country_abbv, material_type
    )
    SELECT link.item_spec_id, c.CNCTR, c.CNCTRT, c.CNCOTP
    FROM #country_source AS c
    JOIN mat.material AS m
      ON m.branch_code = TRIM(c.CNMCU) AND m.item_number = TRIM(c.CNLITM)
    CROSS APPLY (
        SELECT TOP (1) l.item_spec_id FROM #spec_link AS l
        WHERE l.material_id = m.id
        ORDER BY CASE WHEN l.source_branch_code = c.CNMCU
                           AND l.source_item_number = c.CNLITM THEN 0 ELSE 1 END,
                 l.revision
    ) AS link;

    INSERT INTO spec.item_property (
        item_spec_id, specification_type, property_type, property_name,
        minimum_value, target_value, maximum_value, unit_of_measure,
        result_value, test_frequency, test_method,
        report_status, coa_status, lab_status
    )
    SELECT link.item_spec_id, p.IPSPCT, p.IPPTTY, p.IPPRPT,
           p.IPPPMN, p.IPPTRG, p.IPPPMX, p.IPUM, p.IPRZLT,
           p.IPFREQ, p.IPMEHD, p.IPSRPT, p.IPSCOA, p.IPSLAB
    FROM #property_source AS p
    JOIN mat.material AS m
      ON m.branch_code = TRIM(p.IPMCU) AND m.item_number = TRIM(p.IPLITM)
    CROSS APPLY (
        SELECT TOP (1) l.item_spec_id FROM #spec_link AS l
        WHERE l.material_id = m.id
        ORDER BY CASE WHEN l.source_branch_code = p.IPMCU
                           AND l.source_item_number = p.IPLITM THEN 0 ELSE 1 END,
                 l.revision
    ) AS link;

    INSERT INTO spec.item_solvent (
        item_spec_id, ratio, solvent_type, solvent_name, solvent_number
    )
    SELECT link.item_spec_id, v.ISRTIO, v.ISSLVT, v.ISSNME, v.ISSLVN
    FROM #solvent_source AS v
    JOIN mat.material AS m
      ON m.branch_code = TRIM(v.ISMCU) AND m.item_number = TRIM(v.ISLITM)
    CROSS APPLY (
        SELECT TOP (1) l.item_spec_id FROM #spec_link AS l
        WHERE l.material_id = m.id
        ORDER BY CASE WHEN l.source_branch_code = v.ISMCU
                           AND l.source_item_number = v.ISLITM THEN 0 ELSE 1 END,
                 l.revision
    ) AS link;

    INSERT INTO spec.item_vendor_part (
        item_spec_id, vendor_number, vendor_name, vendor_priority,
        vendor_part_number, manufacturer_part_number, manufacturer_part_name,
        manufacturer_name, country_name
    )
    SELECT link.item_spec_id, v.IVVEND, v.IVVNDN, v.IVPRNC,
           v.IVVPNO, v.IVMPNO, v.IVMPNM, v.IVMFGN, v.IVCTR
    FROM #vendor_part_source AS v
    JOIN mat.material AS m
      ON m.branch_code = TRIM(v.IVMCU) AND m.item_number = TRIM(v.IVLITM)
    CROSS APPLY (
        SELECT TOP (1) l.item_spec_id FROM #spec_link AS l
        WHERE l.material_id = m.id
        ORDER BY CASE WHEN l.source_branch_code = v.IVMCU
                           AND l.source_item_number = v.IVLITM THEN 0 ELSE 1 END,
                 l.revision
    ) AS link;

    INSERT INTO mat.item_jde_original (
        material_id, source_branch_code, source_item_number, source_julian_date,
        description_3, gl_posting_code, stocking_type, primary_uom,
        category_code, sld_value, ltlv_value, warr_value, unit_cost, lrgn_value
    )
    SELECT m.id, j.JDMCU, j.JDLITM, j.JDTRDJ,
           j.JDDSC3, j.JDGLPT, j.JDSTKT, j.JDUOM1,
           j.JDPRP2, j.JDSLD, j.JDLTLV, j.JDWARR,
           CONVERT(decimal(20,8), j.JDUNCS), j.JDLRGN
    FROM dbo.Item_JDE_Original AS j
    JOIN mat.material AS m
      ON m.branch_code = TRIM(j.JDMCU) AND m.item_number = TRIM(j.JDLITM);

    IF (SELECT COUNT_BIG(*) FROM spec.item_spec)
       <> (SELECT COUNT_BIG(*) FROM #spec_source)
        THROW 50005, 'Item spec count did not reconcile.', 1;
    IF (SELECT COUNT_BIG(*) FROM spec.item_regulatory_req)
       <> (SELECT COUNT_BIG(*) FROM dbo.Item_Regulatory_Requirement AS r
           JOIN mat.material AS m
             ON m.branch_code = TRIM(r.RRMCU) AND m.item_number = TRIM(r.RRLITM))
        THROW 50006, 'Regulatory count did not reconcile.', 1;
    IF (SELECT COUNT_BIG(*) FROM spec.item_allergen)
       <> (SELECT COUNT_BIG(*) FROM #allergen_source)
        THROW 50007, 'Allergen count did not reconcile.', 1;
    IF (SELECT COUNT_BIG(*) FROM spec.item_property)
       <> (SELECT COUNT_BIG(*) FROM #property_source)
        THROW 50008, 'Property count did not reconcile.', 1;
    IF (SELECT COUNT_BIG(*) FROM spec.item_solvent)
       <> (SELECT COUNT_BIG(*) FROM #solvent_source)
        THROW 50009, 'Solvent count did not reconcile.', 1;
    IF (SELECT COUNT_BIG(*) FROM mat.item_jde_original)
       <> (SELECT COUNT_BIG(*) FROM dbo.Item_JDE_Original AS j
           JOIN mat.material AS m
             ON m.branch_code = TRIM(j.JDMCU) AND m.item_number = TRIM(j.JDLITM))
        THROW 50010, 'JDE history count did not reconcile.', 1;
    IF (SELECT COUNT_BIG(*) FROM spec.item_country)
       <> (SELECT COUNT_BIG(*) FROM #country_source)
        THROW 50011, 'Country count did not reconcile.', 1;
    IF (SELECT COUNT_BIG(*) FROM spec.item_vendor_part)
       <> (SELECT COUNT_BIG(*) FROM #vendor_part_source)
        THROW 50012, 'Vendor part count did not reconcile.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT N'item_spec' AS target_table, COUNT_BIG(*) AS target_rows FROM spec.item_spec
UNION ALL SELECT N'item_regulatory_req', COUNT_BIG(*) FROM spec.item_regulatory_req
UNION ALL SELECT N'item_allergen', COUNT_BIG(*) FROM spec.item_allergen
UNION ALL SELECT N'item_country', COUNT_BIG(*) FROM spec.item_country
UNION ALL SELECT N'item_property', COUNT_BIG(*) FROM spec.item_property
UNION ALL SELECT N'item_solvent', COUNT_BIG(*) FROM spec.item_solvent
UNION ALL SELECT N'item_vendor_part', COUNT_BIG(*) FROM spec.item_vendor_part
UNION ALL SELECT N'item_jde_original', COUNT_BIG(*) FROM mat.item_jde_original;

SELECT review_status, COUNT_BIG(*) AS item_spec_rows
FROM spec.item_spec
GROUP BY review_status
ORDER BY review_status;

SELECT m.branch_code, m.item_number, s.id AS item_spec_id,
       s.revision, s.major_rev, s.plant_type, s.review_status
FROM spec.item_spec AS s
JOIN mat.material AS m ON m.id = s.material_id
WHERE m.branch_code = N'10' AND m.item_number = N'1046502'
ORDER BY s.revision;
