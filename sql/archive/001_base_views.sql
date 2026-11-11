/*
    PLM base views
    ==============

    Sources reviewed:
      - plm_tables.sql (32 PLM tables)
      - plm_storedprocs.sql (44 procedures)
      - plm_sql_jobs.sql (6 SQL Agent jobs)
      - plum_main.srw (direct application references)

    Scope:
      - Thin, single-table views in [app] are the base contracts for future CRUD.
      - Joined/aggregated views in [reporting] and [integration] are read models.
      - This script intentionally creates no tables, foreign keys, unique constraints,
        indexes, triggers, permissions, or business-rule calculations.

    Important:
      Formula_Header and Formula_Item have no declared key.  The current application
      treats (branch, parent, blend, revision, status) as the formula-revision key and
      adds line_number for a formula line.  That is preserved here as a mapping only;
      it is not asserted to be unique.
*/

USE [PLM];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF SCHEMA_ID(N'app') IS NULL
    EXEC(N'CREATE SCHEMA [app] AUTHORIZATION [dbo];');
GO
IF SCHEMA_ID(N'reporting') IS NULL
    EXEC(N'CREATE SCHEMA [reporting] AUTHORIZATION [dbo];');
GO
IF SCHEMA_ID(N'integration') IS NULL
    EXEC(N'CREATE SCHEMA [integration] AUTHORIZATION [dbo];');
GO

/* --------------------------------------------------------------------------
   Updatable base views

   These are deliberately one-table projections with aliases only.  SQL Server can
   route ordinary INSERT/UPDATE/DELETE statements through them, subject to the base
   table's nullability/identity rules.  Application services must still validate the
   logical key, workflow, authorization, and concurrency.
   -------------------------------------------------------------------------- */

CREATE OR ALTER VIEW [app].[vw_formula_header]
AS
SELECT
    FHMCU  AS branch_code,
    FHPRNT AS parent_item_number,
    FHBLND AS blend_item_number,
    FHNAME AS formula_name,
    FHRVNO AS revision_number,
    FHSTUS AS workflow_status,
    FHCUSN AS customer_number,
    FHCUSP AS customer_part_number,
    FHUSER AS entered_by,
    FHUNTY AS unit_type,
    FHSIZE AS size_description,
    FHTYPM AS material_description,
    FHFMCT AS formula_category,
    FHCLOR AS color_description,
    FHDOSE AS units_per_daily_dose,
    FHSRVG AS servings,
    FHDLYD AS daily_doses,
    FHHOBN AS hob_number,
    FHRMM  AS raw_material_markup_percent,
    FHOVRA AS manufacturing_overage_percent,
    FHMTCP AS capsule_item_number,
    FHSLDS AS coating_solids_percent,
    FHWGHT AS coating_weight_gain_percent,
    FHCWAX AS coating_wax_percent,
    FHCHNG AS change_code,
    FHECDV AS change_number,
    FHTRDJ AS original_transaction_julian_date,
    FHNOTE AS notes,
    FHADDL AS additional_information
FROM [dbo].[Formula_Header];
GO

CREATE OR ALTER VIEW [app].[vw_formula_line]
AS
SELECT
    FMRWNO AS line_number,
    FMMCU  AS branch_code,
    FMPRNT AS parent_item_number,
    FMBLND AS blend_item_number,
    FMCHLD AS material_item_number,
    FMRVNO AS revision_number,
    FMSTUS AS workflow_status,
    FMDSCR AS material_description,
    FMTMRK AS trademark,
    FMVEND AS vendor_name,
    FMQUOT AS quoted_cost,
    FMCOST AS material_cost,
    FMNAME AS formula_name,
    FMUSER AS entered_by,
    FMPTNC AS potency,
    FMPTUM AS potency_unit,
    FMTIVE AS active_amount,
    FMOVRA AS line_overage_percent,
    FMGORY AS material_category,
    FMDLYD AS calculated_daily_dose_mg,
    FMMGTB AS calculated_mg_per_unit,
    FMMGMO AS calculated_mg_per_unit_with_overage,
    FMPRFM AS calculated_formula_percent,
    FMPCST AS calculated_cost_percent,
    FMPRNC AS print_cost_flag,
    FMPRNV AS print_vendor_flag,
    FMNOTE AS notes
FROM [dbo].[Formula_Item];
GO

CREATE OR ALTER VIEW [app].[vw_formula_certification]
AS
SELECT
    FCMCU  AS branch_code,
    FCPRNT AS parent_item_number,
    FCBLND AS blend_item_number,
    FCRVNO AS revision_number,
    FCSTUS AS workflow_status,
    FCCERT AS certification_code,
    FCDATE AS certification_julian_date,
    FCNOTE AS notes
FROM [dbo].[Formula_Certification];
GO

CREATE OR ALTER VIEW [app].[vw_certification_type]
AS
SELECT
    Cert_ID   AS certification_code,
    Cert_Name AS certification_name,
    NOTE      AS notes
FROM [dbo].[Formula_Certification_Builder];
GO

CREATE OR ALTER VIEW [app].[vw_user_group]
AS
SELECT
    FGUSER AS user_name,
    FGGRP  AS group_code,
    FGINDV AS individual_permission_code,
    FGMCU  AS branch_code
FROM [dbo].[Formulation_Group];
GO

CREATE OR ALTER VIEW [app].[vw_item_allergen]
AS
SELECT
    ALIDNT AS allergen_id,
    ALMCU  AS branch_code,
    ALLITM AS item_number,
    ALALRG AS allergen_name,
    ALPSNT AS present_status,
    ALSALL AS source_allergen_text,
    ALCMTS AS comments
FROM [dbo].[Item_Allergen];
GO

CREATE OR ALTER VIEW [app].[vw_item_country]
AS
SELECT
    CNIDNT AS country_id,
    CNMCU  AS branch_code,
    CNLITM AS item_number,
    CNCTR  AS country_name,
    CNCTRT AS country_detail,
    CNCOTP AS country_type
FROM [dbo].[Item_Country];
GO

CREATE OR ALTER VIEW [app].[vw_item_extension]
AS
SELECT
    EXMCU  AS branch_code,
    EXLITM AS item_number,
    EXALRG AS allergen_flag,
    EXAPPE AS appearance,
    EXCLOR AS color,
    EXITY  AS item_type,
    EXPSYF AS physical_form,
    EXSTA  AS item_status,
    EXCLAS AS classification,
    EXCRON AS created_at,
    EXCRBY AS created_by,
    EXMDON AS modified_at,
    EXMDBY AS modified_by,
    EXICNT AS legacy_icnt_code,
    EXMAJR AS major_category,
    EXMNOR AS minor_category,
    EXRLSD AS released_flag,
    EXPLPT AS legacy_plpt_value,
    EXPEXR AS legacy_pexr_value,
    EXREF  AS reference_code,
    EXHCPN AS legacy_hcpn_code,
    EXLATN AS latin_name,
    EXTMRK AS trademark,
    EXNLYT AS legacy_nlyt_value,
    EXPTNC AS potency,
    EXPTUM AS potency_unit,
    EXCAS  AS cas_number,
    EXMNCP AS minimum_capsule_value,
    EXMXCP AS maximum_capsule_value,
    EXAVCP AS average_capsule_value,
    EXSPLH AS handling_information,
    EXSPLS AS storage_information,
    EXSAFT AS safety_information,
    EXUTHR AS other_information
FROM [dbo].[Item_Extension];
GO

CREATE OR ALTER VIEW [app].[vw_item_property]
AS
SELECT
    IPIDNT AS property_id,
    IPMCU  AS branch_code,
    IPLITM AS item_number,
    IPSPCT AS specification_type,
    IPPTTY AS property_type,
    IPPRPT AS property_name,
    IPPPMN AS minimum_value,
    IPPTRG AS target_value,
    IPPPMX AS maximum_value,
    IPUM   AS unit_of_measure,
    IPRZLT AS result_value,
    IPFREQ AS test_frequency,
    IPMEHD AS test_method,
    IPSRPT AS report_text,
    IPSCOA AS certificate_of_analysis_text,
    IPSLAB AS label_text
FROM [dbo].[Item_Property];
GO

CREATE OR ALTER VIEW [app].[vw_item_regulatory_requirement]
AS
SELECT
    RRMCU  AS branch_code,
    RRLITM AS item_number,
    RRGMO  AS gmo_status,
    RRHALA AS halal_status,
    RRKOSH AS kosher_status,
    RRUSP  AS usp_status,
    RRPRSV AS preservative_status,
    RRGLTN AS gluten_status,
    RRBSE  AS bse_status,
    RRNNET AS non_novel_status,
    RRGRAS AS gras_status,
    RRVGTR AS vegetarian_status,
    RRVEGN AS vegan_status,
    RROGNC AS organic_status,
    RRWADA AS wada_status,
    RRNDI  AS ndi_status,
    RRSYNT AS synthetic_status,
    RRNSF  AS nsf_value,
    RRGFCO AS gluten_free_certified_status,
    RRFRIG AS fragrance_status,
    RRPREF AS preference_code,
    RRBIO  AS bioengineered_status
FROM [dbo].[Item_Regulatory_Requirement];
GO

CREATE OR ALTER VIEW [app].[vw_item_solvent]
AS
SELECT
    ISIDNT AS solvent_id,
    ISMCU  AS branch_code,
    ISLITM AS item_number,
    ISRTIO AS ratio,
    ISSLVT AS solvent_type,
    ISSNME AS solvent_name,
    ISSLVN AS solvent_number
FROM [dbo].[Item_Solvent];
GO

CREATE OR ALTER VIEW [app].[vw_item_vendor_part]
AS
SELECT
    IVIDNT AS vendor_part_id,
    IVMCU  AS branch_code,
    IVLITM AS item_number,
    IVVEND AS vendor_number,
    IVVNDN AS vendor_name,
    IVPRNC AS vendor_priority,
    IVVPNO AS vendor_part_number,
    IVMPNO AS manufacturer_part_number,
    IVMPNM AS manufacturer_part_name,
    IVMFGN AS manufacturer_name,
    IVCTR  AS country_name
FROM [dbo].[Item_Vendor_Part];
GO

CREATE OR ALTER VIEW [app].[vw_optimal_batch_size]
AS
SELECT
    ID              AS optimal_batch_size_id,
    CustomerName    AS customer_name,
    CustomerNum     AS customer_number,
    BottleNum       AS bottle_item_number,
    ItemNum         AS item_number,
    UnCoatedTablet  AS uncoated_tablet_item_number,
    BlendNum        AS blend_item_number,
    BulkDensity     AS bulk_density,
    HobNum          AS hob_number,
    Capsule         AS capsule_item_number,
    TargetWt        AS target_weight,
    PackQty         AS pack_quantity,
    Scrap           AS scrap_percent,
    Category        AS category,
    Branch          AS branch_code
FROM [dbo].[Optimal_Batch_Size];
GO

CREATE OR ALTER VIEW [app].[vw_empty_capsule_weight]
AS
SELECT
    ItemNum                AS item_number,
    Description_Combined   AS description_combined,
    AvgWt                  AS average_weight,
    TOLERANCE              AS tolerance,
    [Description 1]        AS description_1,
    [Description 2]        AS description_2,
    Size                   AS capsule_size,
    UOM                    AS unit_of_measure,
    Vendor                 AS vendor_name,
    [Vend #]               AS vendor_number
FROM [dbo].[Empty_Capsule_Weight];
GO

/* --------------------------------------------------------------------------
   Stable read projections extracted from repeated stored-procedure semantics
   -------------------------------------------------------------------------- */

CREATE OR ALTER VIEW [reporting].[vw_formula_revision_line]
AS
SELECT
    h.FHMCU  AS branch_code,
    h.FHPRNT AS parent_item_number,
    h.FHBLND AS blend_item_number,
    h.FHRVNO AS revision_number,
    h.FHSTUS AS workflow_status,
    h.FHNAME AS formula_name,
    h.FHCUSN AS customer_number,
    h.FHCUSP AS customer_part_number,
    h.FHUSER AS formula_entered_by,
    h.FHUNTY AS unit_type,
    h.FHSIZE AS size_description,
    h.FHTYPM AS material_description,
    h.FHFMCT AS formula_category,
    h.FHCLOR AS color_description,
    h.FHDOSE AS units_per_daily_dose,
    h.FHSRVG AS servings,
    h.FHDLYD AS daily_doses,
    h.FHHOBN AS hob_number,
    h.FHRMM  AS raw_material_markup_percent,
    h.FHOVRA AS manufacturing_overage_percent,
    h.FHMTCP AS capsule_item_number,
    h.FHSLDS AS coating_solids_percent,
    h.FHWGHT AS coating_weight_gain_percent,
    h.FHCWAX AS coating_wax_percent,
    h.FHCHNG AS change_code,
    h.FHECDV AS change_number,
    h.FHTRDJ AS original_transaction_julian_date,
    h.FHNOTE AS formula_notes,
    h.FHADDL AS formula_additional_information,
    l.FMRWNO AS line_number,
    l.FMCHLD AS material_item_number,
    l.FMDSCR AS material_description_line,
    l.FMTMRK AS trademark,
    l.FMVEND AS vendor_name,
    l.FMQUOT AS quoted_cost,
    l.FMCOST AS material_cost,
    l.FMUSER AS line_entered_by,
    l.FMPTNC AS potency,
    l.FMPTUM AS potency_unit,
    l.FMTIVE AS active_amount,
    l.FMOVRA AS line_overage_percent,
    l.FMGORY AS material_category,
    l.FMDLYD AS calculated_daily_dose_mg,
    l.FMMGTB AS calculated_mg_per_unit,
    l.FMMGMO AS calculated_mg_per_unit_with_overage,
    l.FMPRFM AS calculated_formula_percent,
    l.FMPCST AS calculated_cost_percent,
    l.FMPRNC AS print_cost_flag,
    l.FMPRNV AS print_vendor_flag,
    l.FMNOTE AS line_notes
FROM [dbo].[Formula_Header] AS h
LEFT JOIN [dbo].[Formula_Item] AS l
    ON  l.FMMCU  = h.FHMCU
    AND l.FMPRNT = h.FHPRNT
    AND l.FMBLND = h.FHBLND
    AND l.FMRVNO = h.FHRVNO
    AND l.FMSTUS = h.FHSTUS;
GO

CREATE OR ALTER VIEW [reporting].[vw_formula_revision_summary]
AS
SELECT
    h.FHMCU  AS branch_code,
    h.FHPRNT AS parent_item_number,
    h.FHBLND AS blend_item_number,
    h.FHRVNO AS revision_number,
    h.FHSTUS AS workflow_status,
    h.FHNAME AS formula_name,
    h.FHCUSN AS customer_number,
    h.FHUNTY AS unit_type,
    h.FHTRDJ AS original_transaction_julian_date,
    COUNT(l.FMRWNO) AS line_count,
    SUM(l.FMDLYD) AS stored_total_daily_dose_mg,
    SUM(l.FMMGTB) AS stored_total_mg_per_unit,
    SUM(l.FMMGMO) AS stored_total_mg_per_unit_with_overage,
    SUM(l.FMPRFM) AS stored_total_formula_percent,
    SUM(l.FMCOST * (l.FMPRFM / 100.0)) AS stored_weighted_formula_cost
FROM [dbo].[Formula_Header] AS h
LEFT JOIN [dbo].[Formula_Item] AS l
    ON  l.FMMCU  = h.FHMCU
    AND l.FMPRNT = h.FHPRNT
    AND l.FMBLND = h.FHBLND
    AND l.FMRVNO = h.FHRVNO
    AND l.FMSTUS = h.FHSTUS
GROUP BY
    h.FHMCU,
    h.FHPRNT,
    h.FHBLND,
    h.FHRVNO,
    h.FHSTUS,
    h.FHNAME,
    h.FHCUSN,
    h.FHUNTY,
    h.FHTRDJ;
GO

CREATE OR ALTER VIEW [reporting].[vw_formula_certification]
AS
SELECT
    c.FCMCU  AS branch_code,
    c.FCPRNT AS parent_item_number,
    c.FCBLND AS blend_item_number,
    c.FCRVNO AS revision_number,
    c.FCSTUS AS workflow_status,
    h.FHNAME AS formula_name,
    h.FHCUSN AS customer_number,
    c.FCCERT AS certification_code,
    t.Cert_Name AS certification_name,
    c.FCDATE AS certification_julian_date,
    c.FCNOTE AS certification_notes,
    t.NOTE AS certification_type_notes
FROM [dbo].[Formula_Certification] AS c
LEFT JOIN [dbo].[Formula_Header] AS h
    ON  h.FHMCU  = c.FCMCU
    AND h.FHPRNT = c.FCPRNT
    AND h.FHBLND = c.FCBLND
    AND h.FHRVNO = c.FCRVNO
    AND h.FHSTUS = c.FCSTUS
LEFT JOIN [dbo].[Formula_Certification_Builder] AS t
    ON t.Cert_ID = c.FCCERT;
GO

/* The three assistant tables are job-owned snapshots, not CRUD entities. */
CREATE OR ALTER VIEW [reporting].[vw_material_catalog_snapshot]
AS
SELECT
    CAST(N'Formulation_Assistant' AS nvarchar(40)) AS snapshot_source,
    IB_item_number AS item_number,
    EX_item_number AS extension_item_number,
    prefer AS preference_code,
    IB_branch AS branch_code,
    EX_branch AS extension_branch_code,
    last_in_cost AS selected_cost,
    potency,
    potency_UOM AS potency_unit,
    item_status,
    stocking_type,
    tier_level,
    vendor_name AS jde_vendor_name,
    quantity_available,
    total_last_12_months AS usage_last_12_months,
    trademark,
    item_description_1,
    item_description_2,
    primary_UOM AS primary_unit,
    purch_UOM AS purchasing_unit,
    last_in_cost_v2 AS normalized_cost,
    Category AS category,
    PLM_Vendor1 AS primary_plm_vendor,
    PLM_Vendor2 AS secondary_plm_vendor,
    PLM_Vendor_UNK AS unclassified_plm_vendor,
    Allergen AS allergen_flag,
    Item_Description AS item_description
FROM [dbo].[Formulation_Assistant]
UNION ALL
SELECT
    CAST(N'Formulation_Assistant_BP05' AS nvarchar(40)),
    IB_item_number, EX_item_number, prefer, IB_branch, EX_branch,
    last_in_cost, potency, potency_UOM, item_status, stocking_type,
    tier_level, vendor_name, quantity_available, total_last_12_months,
    trademark, item_description_1, item_description_2, primary_UOM,
    purch_UOM, last_in_cost_v2, Category, PLM_Vendor1, PLM_Vendor2,
    PLM_Vendor_UNK, Allergen, Item_Description
FROM [dbo].[Formulation_Assistant_BP05]
UNION ALL
SELECT
    CAST(N'Formulation_Assistant_BP15' AS nvarchar(40)),
    IB_item_number, EX_item_number, prefer, IB_branch, EX_branch,
    last_in_cost, potency, potency_UOM, item_status, stocking_type,
    tier_level, vendor_name, quantity_available, total_last_12_months,
    trademark, item_description_1, item_description_2, primary_UOM,
    purch_UOM, last_in_cost_v2, Category, PLM_Vendor1, PLM_Vendor2,
    PLM_Vendor_UNK, Allergen, CAST(NULL AS nvarchar(60))
FROM [dbo].[Formulation_Assistant_BP15];
GO

/* --------------------------------------------------------------------------
   ERP integration base views

   Only fields consumed by the supplied PLM procedures are exposed.  These are
   read-only application contracts over the JDE production replica.  They replace
   direct use of dbo friendly objects, PRODDTA physical objects, and the older
   RptData F4101/F4102 copies in new application code.
   -------------------------------------------------------------------------- */

/* F0101 - Address Book Master */
CREATE OR ALTER VIEW [integration].[vw_jde_address_book_f0101]
AS
SELECT
    ABAN8  AS address_number,
    ABALPH AS alpha_name
FROM [JDE_Prod_Replica].[dbo].[Address_Book_F0101];
GO

/* F3002 - Bill of Material Master */
CREATE OR ALTER VIEW [integration].[vw_jde_bill_of_material_f3002]
AS
SELECT
    IXKITL AS parent_item_number,
    IXLITM AS component_item_number,
    IXMMCU AS branch_code,
    IXTBM  AS bill_type
FROM [JDE_Prod_Replica].[dbo].[Bill_Of_Material_F3002];
GO

/* F3111 - Work Order Parts List */
CREATE OR ALTER VIEW [integration].[vw_jde_work_order_parts_f3111]
AS
SELECT
    WMCPIL AS component_item_number,
    WMMCU  AS branch_code,
    WMTRDJ AS transaction_julian_date,
    WMUORG AS order_quantity_raw,
    WMDCT  AS document_type
FROM [JDE_Prod_Replica].[dbo].[WO_Parts_List_F3111];
GO

/* F4101 - Item Master */
CREATE OR ALTER VIEW [integration].[vw_jde_item_master_f4101]
AS
SELECT
    IMITM  AS short_item_number,
    IMLITM AS item_number,
    IMDSC1 AS description_1,
    IMDSC2 AS description_2,
    IMDSGP AS dispatch_group,
    IMUOM1 AS primary_unit,
    IMUOM3 AS purchasing_unit,
    IMPRP2 AS item_category,
    IMSLD  AS shelf_life_days,
    IMLTLV AS lead_time_level
FROM [JDE_Prod_Replica].[dbo].[Item_Master_F4101];
GO

/* F4102 - Item Branch */
CREATE OR ALTER VIEW [integration].[vw_jde_item_branch_f4102]
AS
SELECT
    IBITM  AS short_item_number,
    IBLITM AS item_number,
    IBMCU  AS branch_code,
    IBSTKT AS stocking_type,
    IBGLPT AS gl_category,
    IBSRP4 AS tier_level,
    IBPRP4 AS branch_category,
    IBPRP2 AS purchasing_category,
    IBVEND AS vendor_number,
    IBSLD  AS branch_shelf_life_days,
    IBLTLV AS branch_lead_time_level,
    IBWARR AS branch_tier_code
FROM [JDE_Prod_Replica].[dbo].[Item_Branch_F4102];
GO

/* F41021 - Item Location */
CREATE OR ALTER VIEW [integration].[vw_jde_item_location_f41021]
AS
SELECT
    LIITM AS short_item_number,
    LIMCU AS branch_code,
    LIPQOH AS quantity_on_hand_raw,
    LIQTO1 AS quantity_in_inspection_raw,
    LILOTS AS lot_status
FROM [JDE_Prod_Replica].[dbo].[Item_Location_F41021];
GO

/* F4105 - Item Cost Ledger */
CREATE OR ALTER VIEW [integration].[vw_jde_cost_ledger_f4105]
AS
SELECT
    COLITM AS item_number,
    COMCU  AS branch_code,
    COLEDG AS cost_method,
    COUNCS AS unit_cost_raw,
    COUNCS * 0.0001 AS unit_cost
FROM [JDE_Prod_Replica].[dbo].[Cost_Ledger_F4105];
GO

/* F4801 - Work Order Master */
CREATE OR ALTER VIEW [integration].[vw_jde_work_order_master_f4801]
AS
SELECT
    WALITM AS item_number,
    WASTRT AS planned_start_julian_date
FROM [JDE_Prod_Replica].[dbo].[Work_Order_Master_F4801];
GO

/* --------------------------------------------------------------------------
   ERP integration composed views

   These centralize repeated joins/aggregations.  Each ledger cost remains separate;
   the application or an approved finance policy must decide which cost wins.
   -------------------------------------------------------------------------- */

CREATE OR ALTER VIEW [integration].[vw_jde_item_branch_cost]
AS
WITH cost AS
(
    SELECT
        LTRIM(RTRIM(branch_code)) AS branch_code,
        item_number,
        MAX(CASE WHEN cost_method = '01' THEN unit_cost END) AS last_cost,
        MAX(CASE WHEN cost_method = '05' THEN unit_cost END) AS future_cost,
        MAX(CASE WHEN cost_method = '07' THEN unit_cost END) AS standard_cost,
        MAX(CASE WHEN cost_method = '21' THEN unit_cost END) AS plm_cost
    FROM [integration].[vw_jde_cost_ledger_f4105]
    WHERE cost_method IN ('01', '05', '07', '21')
    GROUP BY LTRIM(RTRIM(branch_code)), item_number
)
SELECT
    LTRIM(RTRIM(ib.branch_code)) AS branch_code,
    ib.item_number,
    ib.short_item_number,
    LTRIM(RTRIM(im.description_1)) AS description_1,
    LTRIM(RTRIM(im.description_2)) AS description_2,
    CASE
        WHEN LTRIM(RTRIM(im.description_2)) IN ('', '.')
            THEN LTRIM(RTRIM(im.description_1))
        ELSE LTRIM(RTRIM(im.description_1)) + N' ' + LTRIM(RTRIM(im.description_2))
    END AS item_description,
    ib.stocking_type,
    ib.gl_category,
    ib.tier_level,
    ib.branch_category,
    ib.purchasing_category,
    im.item_category,
    im.primary_unit,
    im.purchasing_unit,
    im.shelf_life_days,
    im.lead_time_level,
    ib.branch_shelf_life_days,
    ib.branch_lead_time_level,
    ib.branch_tier_code,
    ib.vendor_number,
    ab.alpha_name AS vendor_name,
    cost.standard_cost,
    cost.last_cost,
    cost.future_cost,
    cost.plm_cost
FROM [integration].[vw_jde_item_branch_f4102] AS ib
JOIN [integration].[vw_jde_item_master_f4101] AS im
    ON im.short_item_number = ib.short_item_number
LEFT JOIN [integration].[vw_jde_address_book_f0101] AS ab
    ON ab.address_number = ib.vendor_number
LEFT JOIN cost
    ON  cost.branch_code = LTRIM(RTRIM(ib.branch_code))
    AND cost.item_number = ib.item_number;
GO

CREATE OR ALTER VIEW [integration].[vw_jde_inventory_balance]
AS
SELECT
    LTRIM(RTRIM(branch_code)) AS branch_code,
    short_item_number,
    SUM(quantity_on_hand_raw) * 0.001 AS quantity_on_hand,
    SUM(quantity_in_inspection_raw) * 0.001 AS quantity_in_inspection
FROM [integration].[vw_jde_item_location_f41021]
WHERE lot_status NOT IN ('A', 'E', 'R', 'P', 'S')
GROUP BY LTRIM(RTRIM(branch_code)), short_item_number;
GO

/*
    Excluded intentionally:
      - Formula/Header backup tables: archival copies, not application contracts.
      - Formula_Item_Cost, Formula_Wt_and_Cost, Raw_Material_Cost: job-owned history/cache.
      - Formulation_Assistant* as CRUD sources: job-owned snapshots; unified above for read.
      - Item_JDE_Original: legacy source snapshot; preserve but do not expose for writes.
      - pbcat*: PowerBuilder metadata, not domain data.

    Before enabling writes:
      1. Profile duplicates for every logical key documented in the ERD.
      2. Confirm the unresolved Item_Extension abbreviations with domain owners.
      3. Restrict the [app] views to API service accounts and enforce authorization in API.
      4. Add optimistic concurrency to the eventual target schema.
*/
