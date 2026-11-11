USE [PLM_DEV];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() <> N'PLM_DEV'
    THROW 50000, 'Run this script only in PLM_DEV.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    TRUNCATE TABLE [dbo].[Item_Allergen];
    TRUNCATE TABLE [dbo].[Item_Country];
    TRUNCATE TABLE [dbo].[Item_Property];
    TRUNCATE TABLE [dbo].[Item_Solvent];
    TRUNCATE TABLE [dbo].[Item_Vendor_Part];
    TRUNCATE TABLE [dbo].[Item_Regulatory_Requirement];
    TRUNCATE TABLE [dbo].[Item_JDE_Original];
    TRUNCATE TABLE [dbo].[Item_Extension];

    INSERT INTO [dbo].[Item_Extension] (
        [EXMCU], [EXLITM], [EXALRG], [EXAPPE], [EXCLOR],
        [EXITY], [EXPSYF], [EXSTA], [EXCLAS], [EXCRON],
        [EXCRBY], [EXMDON], [EXMDBY], [EXICNT], [EXMAJR],
        [EXMNOR], [EXRLSD], [EXPLPT], [EXPEXR], [EXREF],
        [EXHCPN], [EXLATN], [EXTMRK], [EXNLYT], [EXPTNC],
        [EXPTUM], [EXCAS], [EXMNCP], [EXMXCP], [EXAVCP],
        [EXSPLH], [EXSPLS], [EXSAFT], [EXUTHR]
    )
    SELECT
        [EXMCU], [EXLITM], [EXALRG], [EXAPPE], [EXCLOR],
        [EXITY], [EXPSYF], [EXSTA], [EXCLAS], [EXCRON],
        [EXCRBY], [EXMDON], [EXMDBY], [EXICNT], [EXMAJR],
        [EXMNOR], [EXRLSD], [EXPLPT], [EXPEXR], [EXREF],
        [EXHCPN], [EXLATN], [EXTMRK], [EXNLYT], [EXPTNC],
        [EXPTUM], [EXCAS], [EXMNCP], [EXMXCP], [EXAVCP],
        [EXSPLH], [EXSPLS], [EXSAFT], [EXUTHR]
    FROM [PLM].[dbo].[Item_Extension];

    INSERT INTO [dbo].[Item_Regulatory_Requirement] (
        [RRMCU], [RRLITM], [RRGMO], [RRHALA], [RRKOSH],
        [RRUSP], [RRPRSV], [RRGLTN], [RRBSE], [RRNNET],
        [RRGRAS], [RRVGTR], [RRVEGN], [RROGNC], [RRWADA],
        [RRNDI], [RRSYNT], [RRNSF], [RRGFCO], [RRFRIG],
        [RRPREF], [RRBIO]
    )
    SELECT
        [RRMCU], [RRLITM], [RRGMO], [RRHALA], [RRKOSH],
        [RRUSP], [RRPRSV], [RRGLTN], [RRBSE], [RRNNET],
        [RRGRAS], [RRVGTR], [RRVEGN], [RROGNC], [RRWADA],
        [RRNDI], [RRSYNT], [RRNSF], [RRGFCO], [RRFRIG],
        [RRPREF], [RRBIO]
    FROM [PLM].[dbo].[Item_Regulatory_Requirement];

    SET IDENTITY_INSERT [dbo].[Item_Allergen] ON;
    INSERT INTO [dbo].[Item_Allergen] (
        [ALIDNT], [ALMCU], [ALLITM], [ALALRG], [ALPSNT],
        [ALSALL], [ALCMTS]
    )
    SELECT
        [ALIDNT], [ALMCU], [ALLITM], [ALALRG], [ALPSNT],
        [ALSALL], [ALCMTS]
    FROM [PLM].[dbo].[Item_Allergen];
    SET IDENTITY_INSERT [dbo].[Item_Allergen] OFF;

    SET IDENTITY_INSERT [dbo].[Item_Country] ON;
    INSERT INTO [dbo].[Item_Country] (
        [CNIDNT], [CNMCU], [CNLITM], [CNCTR], [CNCTRT],
        [CNCOTP]
    )
    SELECT
        [CNIDNT], [CNMCU], [CNLITM], [CNCTR], [CNCTRT],
        [CNCOTP]
    FROM [PLM].[dbo].[Item_Country];
    SET IDENTITY_INSERT [dbo].[Item_Country] OFF;

    SET IDENTITY_INSERT [dbo].[Item_Property] ON;
    INSERT INTO [dbo].[Item_Property] (
        [IPIDNT], [IPMCU], [IPLITM], [IPSPCT], [IPPTTY],
        [IPPRPT], [IPPPMN], [IPPTRG], [IPPPMX], [IPUM],
        [IPRZLT], [IPFREQ], [IPMEHD], [IPSRPT], [IPSCOA],
        [IPSLAB]
    )
    SELECT
        [IPIDNT], [IPMCU], [IPLITM], [IPSPCT], [IPPTTY],
        [IPPRPT], [IPPPMN], [IPPTRG], [IPPPMX], [IPUM],
        [IPRZLT], [IPFREQ], [IPMEHD], [IPSRPT], [IPSCOA],
        [IPSLAB]
    FROM [PLM].[dbo].[Item_Property];
    SET IDENTITY_INSERT [dbo].[Item_Property] OFF;

    SET IDENTITY_INSERT [dbo].[Item_Solvent] ON;
    INSERT INTO [dbo].[Item_Solvent] (
        [ISIDNT], [ISMCU], [ISLITM], [ISRTIO], [ISSLVT],
        [ISSNME], [ISSLVN]
    )
    SELECT
        [ISIDNT], [ISMCU], [ISLITM], [ISRTIO], [ISSLVT],
        [ISSNME], [ISSLVN]
    FROM [PLM].[dbo].[Item_Solvent];
    SET IDENTITY_INSERT [dbo].[Item_Solvent] OFF;

    SET IDENTITY_INSERT [dbo].[Item_Vendor_Part] ON;
    INSERT INTO [dbo].[Item_Vendor_Part] (
        [IVIDNT], [IVMCU], [IVLITM], [IVVEND], [IVVNDN],
        [IVPRNC], [IVVPNO], [IVMPNO], [IVMPNM], [IVMFGN],
        [IVCTR]
    )
    SELECT
        [IVIDNT], [IVMCU], [IVLITM], [IVVEND], [IVVNDN],
        [IVPRNC], [IVVPNO], [IVMPNO], [IVMPNM], [IVMFGN],
        [IVCTR]
    FROM [PLM].[dbo].[Item_Vendor_Part];
    SET IDENTITY_INSERT [dbo].[Item_Vendor_Part] OFF;

    INSERT INTO [dbo].[Item_JDE_Original] (
        [JDMCU], [JDLITM], [JDTRDJ], [JDDSC3], [JDGLPT],
        [JDSTKT], [JDUOM1], [JDPRP2], [JDSLD], [JDLTLV],
        [JDWARR], [JDUNCS], [JDLRGN]
    )
    SELECT
        [JDMCU], [JDLITM], [JDTRDJ], [JDDSC3], [JDGLPT],
        [JDSTKT], [JDUOM1], [JDPRP2], [JDSLD], [JDLTLV],
        [JDWARR], [JDUNCS], [JDLRGN]
    FROM [PLM].[dbo].[Item_JDE_Original];

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    SET IDENTITY_INSERT [dbo].[Item_Allergen] OFF;
    SET IDENTITY_INSERT [dbo].[Item_Country] OFF;
    SET IDENTITY_INSERT [dbo].[Item_Property] OFF;
    SET IDENTITY_INSERT [dbo].[Item_Solvent] OFF;
    SET IDENTITY_INSERT [dbo].[Item_Vendor_Part] OFF;

    THROW;
END CATCH;

SELECT N'Item_Extension' AS table_name,
       (SELECT COUNT_BIG(*) FROM [PLM].[dbo].[Item_Extension]) AS plm_rows,
       (SELECT COUNT_BIG(*) FROM [dbo].[Item_Extension]) AS plm_dev_rows
UNION ALL
SELECT N'Item_Regulatory_Requirement' AS table_name,
       (SELECT COUNT_BIG(*) FROM [PLM].[dbo].[Item_Regulatory_Requirement]) AS plm_rows,
       (SELECT COUNT_BIG(*) FROM [dbo].[Item_Regulatory_Requirement]) AS plm_dev_rows
UNION ALL
SELECT N'Item_Allergen' AS table_name,
       (SELECT COUNT_BIG(*) FROM [PLM].[dbo].[Item_Allergen]) AS plm_rows,
       (SELECT COUNT_BIG(*) FROM [dbo].[Item_Allergen]) AS plm_dev_rows
UNION ALL
SELECT N'Item_Country' AS table_name,
       (SELECT COUNT_BIG(*) FROM [PLM].[dbo].[Item_Country]) AS plm_rows,
       (SELECT COUNT_BIG(*) FROM [dbo].[Item_Country]) AS plm_dev_rows
UNION ALL
SELECT N'Item_Property' AS table_name,
       (SELECT COUNT_BIG(*) FROM [PLM].[dbo].[Item_Property]) AS plm_rows,
       (SELECT COUNT_BIG(*) FROM [dbo].[Item_Property]) AS plm_dev_rows
UNION ALL
SELECT N'Item_Solvent' AS table_name,
       (SELECT COUNT_BIG(*) FROM [PLM].[dbo].[Item_Solvent]) AS plm_rows,
       (SELECT COUNT_BIG(*) FROM [dbo].[Item_Solvent]) AS plm_dev_rows
UNION ALL
SELECT N'Item_Vendor_Part' AS table_name,
       (SELECT COUNT_BIG(*) FROM [PLM].[dbo].[Item_Vendor_Part]) AS plm_rows,
       (SELECT COUNT_BIG(*) FROM [dbo].[Item_Vendor_Part]) AS plm_dev_rows
UNION ALL
SELECT N'Item_JDE_Original' AS table_name,
       (SELECT COUNT_BIG(*) FROM [PLM].[dbo].[Item_JDE_Original]) AS plm_rows,
       (SELECT COUNT_BIG(*) FROM [dbo].[Item_JDE_Original]) AS plm_dev_rows;
