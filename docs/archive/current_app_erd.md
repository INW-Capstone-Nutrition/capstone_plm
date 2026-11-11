# Current PLM application ERD

This ERD is reconstructed from the current 32-table PLM DDL, 44 stored procedures,
six SQL Agent jobs, and the supplied PowerBuilder main window. It describes the
current structure; it does not add foreign keys or indexes.

Relationship lines are **logical/inferred relationships**, not constraints present
in SQL Server. `PK` marks only primary keys that actually exist in the supplied DDL.
Several tables have no declared key. In particular, the application repeatedly joins
formula headers, lines, and certifications on `(branch, parent, blend, revision,
status)`, but uniqueness is not enforced.

The diagrams are split by concern so Mermaid can render them legibly. Together they
cover all 32 PLM tables. External JDE objects are shown separately because their DDL
was not supplied.

## 1. Formula, certification, administration, and operating reference data

```mermaid
erDiagram
    Formula_Header {
        nvarchar FHMCU
        nvarchar FHPRNT
        nvarchar FHBLND
        nvarchar FHNAME
        real FHRVNO
        nvarchar FHSTUS
        nvarchar FHCUSN
        nvarchar FHCUSP
        nvarchar FHUSER
        nvarchar FHUNTY
        nvarchar FHSIZE
        nvarchar FHTYPM
        nvarchar FHFMCT
        nvarchar FHCLOR
        int FHDOSE
        int FHSRVG
        int FHDLYD
        nvarchar FHHOBN
        real FHRMM
        real FHOVRA
        nvarchar FHMTCP
        real FHSLDS
        real FHWGHT
        real FHCWAX
        nvarchar FHCHNG
        nvarchar FHECDV
        bigint FHTRDJ
        nvarchar_max FHNOTE
        nvarchar FHADDL
    }

    Formula_Item {
        int FMRWNO
        nvarchar FMMCU
        nvarchar FMPRNT
        nvarchar FMBLND
        nvarchar FMCHLD
        real FMRVNO
        nvarchar FMSTUS
        nvarchar FMDSCR
        nvarchar FMTMRK
        nvarchar FMVEND
        real FMQUOT
        real FMCOST
        nvarchar FMNAME
        nvarchar FMUSER
        real FMPTNC
        nvarchar FMPTUM
        real FMTIVE
        real FMOVRA
        nvarchar FMGORY
        real FMDLYD
        real FMMGTB
        real FMMGMO
        real FMPRFM
        real FMPCST
        nvarchar FMPRNC
        nvarchar FMPRNV
        nvarchar FMNOTE
    }

    Formula_Certification {
        nvarchar FCMCU
        nvarchar FCPRNT
        nvarchar FCBLND
        real FCRVNO
        nvarchar FCSTUS
        nvarchar FCCERT
        int FCDATE
        nvarchar FCNOTE
    }

    Formula_Certification_Builder {
        nvarchar Cert_ID
        nvarchar Cert_Name
        varchar NOTE
    }

    Formulation_Group {
        nvarchar FGUSER PK
        nvarchar FGGRP PK
        nvarchar FGINDV
        nvarchar FGMCU
    }

    Optimal_Batch_Size {
        int ID PK
        varchar CustomerName
        varchar CustomerNum
        varchar BottleNum
        varchar ItemNum
        varchar UnCoatedTablet
        varchar BlendNum
        float BulkDensity
        varchar HobNum
        varchar Capsule
        float TargetWt
        int PackQty
        float Scrap
        varchar Category
        varchar Branch
    }

    Empty_Capsule_Weight {
        nvarchar ItemNum
        nvarchar Description_Combined
        float AvgWt
        nvarchar TOLERANCE
        nvarchar Description_1
        nvarchar Description_2
        nvarchar Size
        nvarchar UOM
        nvarchar Vendor
        float Vend_Number
    }

    Formula_Header ||--o{ Formula_Item : "logical revision key"
    Formula_Header ||--o{ Formula_Certification : "logical revision key"
    Formula_Certification_Builder ||--o{ Formula_Certification : "certification code"
    Formula_Header }o--o{ Optimal_Batch_Size : "branch and blend/item mapping"
    Formula_Header }o--o{ Empty_Capsule_Weight : "capsule item FHMTCP"
```

## 2. Material specifications

`Item_Extension` is the branch/item root used by the application. The one-to-many
tables use identity primary keys, while regulatory requirements use the branch/item
pair as their actual primary key. The other relationship columns are not declared as
foreign keys.

```mermaid
erDiagram
    Item_Extension {
        nvarchar EXMCU PK
        nvarchar EXLITM PK
        nvarchar EXALRG
        nvarchar EXAPPE
        nvarchar EXCLOR
        nvarchar EXITY
        nvarchar EXPSYF
        nvarchar EXSTA
        nvarchar EXCLAS
        datetime EXCRON
        nvarchar EXCRBY
        datetime EXMDON
        nvarchar EXMDBY
        nvarchar EXICNT
        nvarchar EXMAJR
        nvarchar EXMNOR
        nvarchar EXRLSD
        nvarchar EXPLPT
        nvarchar EXPEXR
        nvarchar EXREF
        nvarchar EXHCPN
        nvarchar EXLATN
        nvarchar EXTMRK
        nvarchar EXNLYT
        float EXPTNC
        nvarchar EXPTUM
        nvarchar EXCAS
        int EXMNCP
        int EXMXCP
        int EXAVCP
        nvarchar EXSPLH
        nvarchar EXSPLS
        nvarchar EXSAFT
        nvarchar EXUTHR
    }

    Item_Allergen {
        int ALIDNT PK
        nvarchar ALMCU
        nvarchar ALLITM
        nvarchar ALALRG
        nvarchar ALPSNT
        nvarchar ALSALL
        nvarchar ALCMTS
    }

    Item_Country {
        int CNIDNT PK
        nvarchar CNMCU
        nvarchar CNLITM
        nvarchar CNCTR
        nvarchar CNCTRT
        nvarchar CNCOTP
    }

    Item_Property {
        int IPIDNT PK
        nvarchar IPMCU
        nvarchar IPLITM
        nvarchar IPSPCT
        nvarchar IPPTTY
        nvarchar IPPRPT
        nvarchar IPPPMN
        nvarchar IPPTRG
        nvarchar IPPPMX
        nvarchar IPUM
        nvarchar IPRZLT
        nvarchar IPFREQ
        nvarchar IPMEHD
        nvarchar IPSRPT
        nvarchar IPSCOA
        nvarchar IPSLAB
    }

    Item_Regulatory_Requirement {
        nvarchar RRMCU PK
        nvarchar RRLITM PK
        nvarchar RRGMO
        nvarchar RRHALA
        nvarchar RRKOSH
        nvarchar RRUSP
        nvarchar RRPRSV
        nvarchar RRGLTN
        nvarchar RRBSE
        nvarchar RRNNET
        nvarchar RRGRAS
        nvarchar RRVGTR
        nvarchar RRVEGN
        nvarchar RROGNC
        nvarchar RRWADA
        nvarchar RRNDI
        nvarchar RRSYNT
        real RRNSF
        nvarchar RRGFCO
        nvarchar RRFRIG
        nvarchar RRPREF
        nvarchar RRBIO
    }

    Item_Solvent {
        int ISIDNT PK
        nvarchar ISMCU
        nvarchar ISLITM
        nvarchar ISRTIO
        nvarchar ISSLVT
        nvarchar ISSNME
        nvarchar ISSLVN
    }

    Item_Vendor_Part {
        int IVIDNT PK
        nvarchar IVMCU
        nvarchar IVLITM
        int IVVEND
        nvarchar IVVNDN
        nvarchar IVPRNC
        nvarchar IVVPNO
        nvarchar IVMPNO
        nvarchar IVMPNM
        nvarchar IVMFGN
        nvarchar IVCTR
    }

    Item_JDE_Original {
        nvarchar JDMCU PK
        nvarchar JDLITM PK
        bigint JDTRDJ PK
        nvarchar JDDSC3
        nvarchar JDGLPT
        nvarchar JDSTKT
        nvarchar JDUOM1
        nvarchar JDPRP2
        int JDSLD
        int JDLTLV
        nvarchar JDWARR
        real JDUNCS
        nvarchar JDLRGN
    }

    Formula_Item }o--o{ Item_Extension : "branch and material item"
    Item_Extension ||--o{ Item_Allergen : "branch and item"
    Item_Extension ||--o{ Item_Country : "branch and item"
    Item_Extension ||--o{ Item_Property : "branch and item"
    Item_Extension ||--o| Item_Regulatory_Requirement : "branch and item"
    Item_Extension ||--o{ Item_Solvent : "branch and item"
    Item_Extension ||--o{ Item_Vendor_Part : "branch and item"
    Item_Extension ||--o{ Item_JDE_Original : "branch and item snapshots"
```

## 3. Job-owned caches, history, and backups

These tables are populated by daily procedures/jobs or are dated backup copies. They
are not proposed as CRUD resources. `Proc_Formulation_Assistant_BP35` currently writes
to `Formulation_Assistant_BP15`; the diagram records the physical tables, not an
invented BP35 table.

```mermaid
erDiagram
    Formula_Item_Cost {
        int RunDate PK
        nvarchar Item_Num PK
        real Item_Cost
    }

    Formula_Wt_and_Cost {
        int RunDate PK
        varchar Branch PK
        varchar Parent PK
        varchar Blend PK
        real Total_Daily_Dose_mg_Wt
        real Total_mg_Unit_Wt
        real Total_mg_Unit_Wt_MO
        real TotalFormula
        int Raw_Materials
        real Formula_Cost
        int Last_Active_Date
    }

    Raw_Material_Cost {
        varchar Branch
        varchar ItemNum
        real Std_Cost
        real Last_Cost
        real Future_Cost
        real PLM_Cost
    }

    Formulation_Assistant {
        nvarchar IB_item_number
        nvarchar EX_item_number
        nvarchar prefer
        nvarchar IB_branch
        nvarchar EX_branch
        float last_in_cost
        float potency
        nvarchar potency_UOM
        nvarchar item_status
        nvarchar stocking_type
        nvarchar tier_level
        nvarchar vendor_name
        float quantity_available
        float total_last_12_months
        nvarchar trademark
        nvarchar item_description_1
        nvarchar item_description_2
        nvarchar primary_UOM
        nvarchar purch_UOM
        float last_in_cost_v2
        varchar Category
        nvarchar PLM_Vendor1
        nvarchar PLM_Vendor2
        nvarchar PLM_Vendor_UNK
        nvarchar Allergen
        nvarchar Item_Description
    }

    Formulation_Assistant_BP05 {
        nvarchar IB_item_number
        nvarchar EX_item_number
        nvarchar prefer
        nvarchar IB_branch
        nvarchar EX_branch
        float last_in_cost
        float potency
        nvarchar potency_UOM
        nvarchar item_status
        nvarchar stocking_type
        nvarchar tier_level
        nvarchar vendor_name
        float quantity_available
        float total_last_12_months
        nvarchar trademark
        nvarchar item_description_1
        nvarchar item_description_2
        nvarchar primary_UOM
        nvarchar purch_UOM
        float last_in_cost_v2
        varchar Category
        nvarchar PLM_Vendor1
        nvarchar PLM_Vendor2
        nvarchar PLM_Vendor_UNK
        nvarchar Allergen
        nvarchar Item_Description
    }

    Formulation_Assistant_BP15 {
        nvarchar IB_item_number
        nvarchar EX_item_number
        nvarchar prefer
        nvarchar IB_branch
        nvarchar EX_branch
        float last_in_cost
        float potency
        nvarchar potency_UOM
        nvarchar item_status
        nvarchar stocking_type
        nvarchar tier_level
        nvarchar vendor_name
        float quantity_available
        float total_last_12_months
        nvarchar trademark
        nvarchar item_description_1
        nvarchar item_description_2
        nvarchar primary_UOM
        nvarchar purch_UOM
        float last_in_cost_v2
        varchar Category
        nvarchar PLM_Vendor1
        nvarchar PLM_Vendor2
        nvarchar PLM_Vendor_UNK
        nvarchar Allergen
    }

    Formula_Header_Backup_126130 {
        nvarchar FHMCU
        nvarchar FHPRNT
        nvarchar FHBLND
        nvarchar FHNAME
        real FHRVNO
        nvarchar FHSTUS
        nvarchar FHCUSN
        nvarchar FHCUSP
        nvarchar FHUSER
        nvarchar FHUNTY
        nvarchar FHSIZE
        nvarchar FHTYPM
        nvarchar FHFMCT
        nvarchar FHCLOR
        int FHDOSE
        int FHSRVG
        int FHDLYD
        nvarchar FHHOBN
        real FHRMM
        real FHOVRA
        nvarchar FHMTCP
        real FHSLDS
        real FHWGHT
        real FHCWAX
        nvarchar FHCHNG
        nvarchar FHECDV
        bigint FHTRDJ
        nvarchar_max FHNOTE
        nvarchar FHADDL
    }

    Formula_Header_Backup_126131 {
        nvarchar FHMCU
        nvarchar FHPRNT
        nvarchar FHBLND
        nvarchar FHNAME
        real FHRVNO
        nvarchar FHSTUS
        nvarchar FHCUSN
        nvarchar FHCUSP
        nvarchar FHUSER
        nvarchar FHUNTY
        nvarchar FHSIZE
        nvarchar FHTYPM
        nvarchar FHFMCT
        nvarchar FHCLOR
        int FHDOSE
        int FHSRVG
        int FHDLYD
        nvarchar FHHOBN
        real FHRMM
        real FHOVRA
        nvarchar FHMTCP
        real FHSLDS
        real FHWGHT
        real FHCWAX
        nvarchar FHCHNG
        nvarchar FHECDV
        bigint FHTRDJ
        nvarchar_max FHNOTE
        nvarchar FHADDL
    }

    Formula_Header_Backup_126243 {
        nvarchar FHMCU
        nvarchar FHPRNT
        nvarchar FHBLND
        nvarchar FHNAME
        real FHRVNO
        nvarchar FHSTUS
        nvarchar FHCUSN
        nvarchar FHCUSP
        nvarchar FHUSER
        nvarchar FHUNTY
        nvarchar FHSIZE
        nvarchar FHTYPM
        nvarchar FHFMCT
        nvarchar FHCLOR
        int FHDOSE
        int FHSRVG
        int FHDLYD
        nvarchar FHHOBN
        real FHRMM
        real FHOVRA
        nvarchar FHMTCP
        real FHSLDS
        real FHWGHT
        real FHCWAX
        nvarchar FHCHNG
        nvarchar FHECDV
        bigint FHTRDJ
        nvarchar_max FHNOTE
        nvarchar FHADDL
    }

    Formula_Item_Backup_126130 {
        int FMRWNO
        nvarchar FMMCU
        nvarchar FMPRNT
        nvarchar FMBLND
        nvarchar FMCHLD
        real FMRVNO
        nvarchar FMSTUS
        nvarchar FMDSCR
        nvarchar FMTMRK
        nvarchar FMVEND
        real FMQUOT
        real FMCOST
        nvarchar FMNAME
        nvarchar FMUSER
        real FMPTNC
        nvarchar FMPTUM
        real FMTIVE
        real FMOVRA
        nvarchar FMGORY
        real FMDLYD
        real FMMGTB
        real FMMGMO
        real FMPRFM
        real FMPCST
        nvarchar FMPRNC
        nvarchar FMPRNV
        nvarchar FMNOTE
    }

    Formula_Item_Backup_126131 {
        int FMRWNO
        nvarchar FMMCU
        nvarchar FMPRNT
        nvarchar FMBLND
        nvarchar FMCHLD
        real FMRVNO
        nvarchar FMSTUS
        nvarchar FMDSCR
        nvarchar FMTMRK
        nvarchar FMVEND
        real FMQUOT
        real FMCOST
        nvarchar FMNAME
        nvarchar FMUSER
        real FMPTNC
        nvarchar FMPTUM
        real FMTIVE
        real FMOVRA
        nvarchar FMGORY
        real FMDLYD
        real FMMGTB
        real FMMGMO
        real FMPRFM
        real FMPCST
        nvarchar FMPRNC
        nvarchar FMPRNV
        nvarchar FMNOTE
    }

    Formula_Item_Backup_126243 {
        int FMRWNO
        nvarchar FMMCU
        nvarchar FMPRNT
        nvarchar FMBLND
        nvarchar FMCHLD
        real FMRVNO
        nvarchar FMSTUS
        nvarchar FMDSCR
        nvarchar FMTMRK
        nvarchar FMVEND
        real FMQUOT
        real FMCOST
        nvarchar FMNAME
        nvarchar FMUSER
        real FMPTNC
        nvarchar FMPTUM
        real FMTIVE
        real FMOVRA
        nvarchar FMGORY
        real FMDLYD
        real FMMGTB
        real FMMGMO
        real FMPRFM
        real FMPCST
        nvarchar FMPRNC
        nvarchar FMPRNV
        nvarchar FMNOTE
    }

    Formula_Header ||--o{ Formula_Wt_and_Cost : "branch parent blend history"
    Formula_Item ||--o{ Formula_Item_Cost : "material cost history"
    Raw_Material_Cost }o--o{ Formula_Item : "branch and material cost source"
    Item_Extension ||--o| Formulation_Assistant : "branch and item snapshot"
    Item_Extension ||--o| Formulation_Assistant_BP05 : "branch and item snapshot"
    Item_Extension ||--o| Formulation_Assistant_BP15 : "branch and item snapshot"
    Formula_Header_Backup_126130 ||--o{ Formula_Item_Backup_126130 : "logical revision key"
    Formula_Header_Backup_126131 ||--o{ Formula_Item_Backup_126131 : "logical revision key"
    Formula_Header_Backup_126243 ||--o{ Formula_Item_Backup_126243 : "logical revision key"
```

## 4. PowerBuilder catalog metadata

These five tables belong to PowerBuilder's database catalog, not the PLM domain.

```mermaid
erDiagram
    pbcattbl {
        varchar pbt_tnam
        int pbt_tid
        varchar pbt_ownr
        smallint pbd_fhgt
        smallint pbd_fwgt
        varchar pbd_fitl
        varchar pbd_funl
        smallint pbd_fchr
        smallint pbd_fptc
        varchar pbd_ffce
        smallint pbh_fhgt
        smallint pbh_fwgt
        varchar pbh_fitl
        varchar pbh_funl
        smallint pbh_fchr
        smallint pbh_fptc
        varchar pbh_ffce
        smallint pbl_fhgt
        smallint pbl_fwgt
        varchar pbl_fitl
        varchar pbl_funl
        smallint pbl_fchr
        smallint pbl_fptc
        varchar pbl_ffce
        varchar pbt_cmnt
    }

    pbcatcol {
        varchar pbc_tnam
        int pbc_tid
        varchar pbc_ownr
        varchar pbc_cnam
        smallint pbc_cid
        varchar pbc_labl
        smallint pbc_lpos
        varchar pbc_hdr
        smallint pbc_hpos
        smallint pbc_jtfy
        varchar pbc_mask
        smallint pbc_case
        smallint pbc_hght
        smallint pbc_wdth
        varchar pbc_ptrn
        varchar pbc_bmap
        varchar pbc_init
        varchar pbc_cmnt
        varchar pbc_edit
        varchar pbc_tag
    }

    pbcatedt {
        varchar pbe_name
        varchar pbe_edit
        smallint pbe_type
        int pbe_cntr
        smallint pbe_seqn
        int pbe_flag
        varchar pbe_work
    }

    pbcatfmt {
        varchar pbf_name
        varchar pbf_frmt
        smallint pbf_type
        int pbf_cntr
    }

    pbcatvld {
        varchar pbv_name
        varchar pbv_vald
        smallint pbv_type
        int pbv_cntr
        varchar pbv_msg
    }

    pbcattbl ||--o{ pbcatcol : "owner and table name"
    pbcatedt }o--o{ pbcatcol : "edit-style name"
    pbcatfmt }o--o{ pbcatcol : "format metadata"
    pbcatvld }o--o{ pbcatcol : "validation metadata"
```

## 5. External ERP dependencies

Only columns referenced by PLM procedures are shown. This is a dependency map, not a
complete JDE physical model.

```mermaid
erDiagram
    JDE_Item_Master_F4101 {
        number IMITM
        nvarchar IMLITM
        nvarchar IMDSC1
        nvarchar IMDSC2
        nvarchar IMDSGP
        nvarchar IMUOM1
        nvarchar IMUOM3
        nvarchar IMPRP2
        int IMSLD
        int IMLTLV
    }

    JDE_Item_Branch_F4102 {
        number IBITM
        nvarchar IBLITM
        nvarchar IBMCU
        nvarchar IBSTKT
        nvarchar IBGLPT
        nvarchar IBSRP4
        nvarchar IBPRP4
        nvarchar IBPRP2
        number IBVEND
        int IBSLD
        int IBLTLV
        nvarchar IBWARR
    }

    JDE_Cost_Ledger_F4105 {
        nvarchar COLITM
        nvarchar COMCU
        nvarchar COLEDG
        number COUNCS
    }

    JDE_Item_Location_F41021 {
        number LIITM
        nvarchar LIMCU
        number LIPQOH
        number LIQTO1
        nvarchar LILOTS
    }

    JDE_Address_Book_F0101 {
        number ABAN8
        nvarchar ABALPH
    }

    JDE_WO_Parts_List_F3111 {
        nvarchar WMCPIL
        nvarchar WMMCU
        int WMTRDJ
        number WMUORG
        nvarchar WMDCT
    }

    JDE_Work_Order_Master_F4801 {
        nvarchar WALITM
        int WASTRT
    }

    JDE_Bill_Of_Material_F3002 {
        nvarchar IXKITL
        nvarchar IXLITM
        nvarchar IXMMCU
        nvarchar IXTBM
    }

    JDE_Item_Master_F4101 ||--o{ JDE_Item_Branch_F4102 : "short item number"
    JDE_Item_Branch_F4102 ||--o{ JDE_Cost_Ledger_F4105 : "branch and item"
    JDE_Item_Branch_F4102 ||--o{ JDE_Item_Location_F41021 : "branch and short item"
    JDE_Address_Book_F0101 ||--o{ JDE_Item_Branch_F4102 : "vendor number"
    JDE_Item_Branch_F4102 }o--o{ Item_Extension : "branch and long item"
    JDE_Item_Branch_F4102 }o--o{ Raw_Material_Cost : "refresh source"
    JDE_WO_Parts_List_F3111 }o--o{ Formulation_Assistant : "rolling usage source"
    JDE_Bill_Of_Material_F3002 }o--o{ Formula_Header : "manufacturing report lookup"
    JDE_Work_Order_Master_F4801 }o--o{ Formula_Header : "cost history report lookup"
```

## Structural cautions before CRUD implementation

- `Formula_Header`, `Formula_Item`, `Formula_Certification`, `Raw_Material_Cost`,
  `Empty_Capsule_Weight`, and all assistant/cache tables have no primary key.
- Revision and formulation numeric values use `real`/`float`; equality and money/math
  behavior should not be carried into a clean target model without profiling.
- Status participates in legacy joins even though it is mutable workflow state.
- The dated backup tables and `pbcat*` catalog tables should not become API resources.
- The six scheduled jobs own the cost/catalog/history tables. CRUD services should not
  write those tables directly.
- Names such as `EXICNT`, `EXPLPT`, `EXPEXR`, `EXHCPN`, and `EXNLYT` could not be
  resolved from the supplied procedures/main window and remain explicitly marked as
  legacy fields in the base view until the missing DataWindow definitions are exported.
