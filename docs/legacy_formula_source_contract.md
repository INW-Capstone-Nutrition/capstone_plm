# Legacy formula source contract

This is the preserved source contract for the migration into the
three-table formula model. It was checked against `PLM_DEV.sys.columns` on October 6,
2026. Do not infer source columns from the future ORM models; use this inventory and
the disposition map in [`archive/formula_three_table_proposal.md`](archive/formula_three_table_proposal.md)
when building the inserts.

There are 107 source-column occurrences across the seven tables. (`RunDate` appears
in both history tables and is counted once for each source.) The two certification
tables currently exist in `PLM`, not `PLM_DEV`.

## `dbo.Formula_Header`

Current key status: no declared primary key in the source. The application identifies
a legacy revision using branch, parent, blend, and revision; workflow status is a
mutable attribute.

| # | Column | SQL Server type | Null |
|---:|---|---|:---:|
| 1 | `FHMCU` | `nvarchar(12)` | No |
| 2 | `FHPRNT` | `nvarchar(64)` | No |
| 3 | `FHBLND` | `nvarchar(64)` | No |
| 4 | `FHNAME` | `nvarchar(60)` | No |
| 5 | `FHRVNO` | `real` | No |
| 6 | `FHSTUS` | `nvarchar(32)` | No |
| 7 | `FHCUSN` | `nvarchar(30)` | Yes |
| 8 | `FHCUSP` | `nvarchar(60)` | Yes |
| 9 | `FHUSER` | `nvarchar(30)` | Yes |
| 10 | `FHUNTY` | `nvarchar(30)` | Yes |
| 11 | `FHSIZE` | `nvarchar(30)` | Yes |
| 12 | `FHTYPM` | `nvarchar(30)` | Yes |
| 13 | `FHFMCT` | `nvarchar(30)` | Yes |
| 14 | `FHCLOR` | `nvarchar(30)` | Yes |
| 15 | `FHDOSE` | `int` | Yes |
| 16 | `FHSRVG` | `int` | Yes |
| 17 | `FHDLYD` | `int` | Yes |
| 18 | `FHHOBN` | `nvarchar(30)` | Yes |
| 19 | `FHRMM` | `real` | Yes |
| 20 | `FHOVRA` | `real` | Yes |
| 21 | `FHMTCP` | `nvarchar(30)` | Yes |
| 22 | `FHSLDS` | `real` | Yes |
| 23 | `FHWGHT` | `real` | Yes |
| 24 | `FHCWAX` | `real` | Yes |
| 25 | `FHCHNG` | `nvarchar(8)` | Yes |
| 26 | `FHECDV` | `nvarchar(32)` | Yes |
| 27 | `FHTRDJ` | `bigint` | Yes |
| 28 | `FHNOTE` | `nvarchar(max)` | Yes |
| 29 | `FHADDL` | `nvarchar(1024)` | Yes |

## `dbo.Formula_Item`

Current key status: no declared primary key in the source. The legacy line identity is
the header revision key plus `FMRWNO`.

| # | Column | SQL Server type | Null |
|---:|---|---|:---:|
| 1 | `FMRWNO` | `int` | No |
| 2 | `FMMCU` | `nvarchar(12)` | No |
| 3 | `FMPRNT` | `nvarchar(64)` | No |
| 4 | `FMBLND` | `nvarchar(64)` | No |
| 5 | `FMCHLD` | `nvarchar(25)` | No |
| 6 | `FMRVNO` | `real` | No |
| 7 | `FMSTUS` | `nvarchar(30)` | No |
| 8 | `FMDSCR` | `nvarchar(60)` | Yes |
| 9 | `FMTMRK` | `nvarchar(64)` | Yes |
| 10 | `FMVEND` | `nvarchar(128)` | Yes |
| 11 | `FMQUOT` | `real` | Yes |
| 12 | `FMCOST` | `real` | Yes |
| 13 | `FMNAME` | `nvarchar(60)` | Yes |
| 14 | `FMUSER` | `nvarchar(30)` | Yes |
| 15 | `FMPTNC` | `real` | Yes |
| 16 | `FMPTUM` | `nvarchar(8)` | Yes |
| 17 | `FMTIVE` | `real` | Yes |
| 18 | `FMOVRA` | `real` | Yes |
| 19 | `FMGORY` | `nvarchar(30)` | Yes |
| 20 | `FMDLYD` | `real` | Yes |
| 21 | `FMMGTB` | `real` | Yes |
| 22 | `FMMGMO` | `real` | Yes |
| 23 | `FMPRFM` | `real` | Yes |
| 24 | `FMPCST` | `real` | Yes |
| 25 | `FMPRNC` | `nvarchar(1)` | Yes |
| 26 | `FMPRNV` | `nvarchar(1)` | Yes |
| 27 | `FMNOTE` | `nvarchar(256)` | Yes |

## `dbo.Formula_Item_Cost`

Primary key: `RunDate DESC, Item_Num ASC`.

| # | Column | SQL Server type | Null |
|---:|---|---|:---:|
| 1 | `RunDate` | `int` | No |
| 2 | `Item_Num` | `nvarchar(25)` | No |
| 3 | `Item_Cost` | `real` | Yes |

## `dbo.Formula_Wt_and_Cost`

Primary key: `RunDate DESC, Branch, Blend, Parent`.

| # | Column | SQL Server type | Null |
|---:|---|---|:---:|
| 1 | `RunDate` | `int` | No |
| 2 | `Branch` | `varchar(12)` | No |
| 3 | `Parent` | `varchar(25)` | No |
| 4 | `Blend` | `varchar(25)` | No |
| 5 | `Total_Daily Dose/mg Wt` | `real` | Yes |
| 6 | `Total_mg/Unit Wt` | `real` | Yes |
| 7 | `Total_mg/Unit Wt + MO%` | `real` | Yes |
| 8 | `TotalFormula` | `real` | Yes |
| 9 | `Raw_Materials` | `int` | Yes |
| 10 | `Formula_Cost` | `real` | Yes |
| 11 | `Last_Active_Date` | `int` | Yes |

The three mg totals require at least seven integer digits in current data. Their
approved target is presently `decimal(12,4)`, while the other mapped `real` values use
`decimal(10,4)`.

## `dbo.Formulation_Assistant`

Current key status: no primary key. This is a job-rebuilt material lookup/cache, not a
CRUD source. The present data has duplicate item/branch grains, so migration logic
must never assume one row per item without first applying an explicit vendor/cost
selection policy.

| # | Column | SQL Server type | Null |
|---:|---|---|:---:|
| 1 | `IB_item_number` | `nvarchar(25)` | Yes |
| 2 | `EX_item_number` | `nvarchar(25)` | Yes |
| 3 | `prefer` | `nvarchar(3)` | Yes |
| 4 | `IB_branch` | `nvarchar(12)` | Yes |
| 5 | `EX_branch` | `nvarchar(12)` | Yes |
| 6 | `last_in_cost` | `float` | Yes |
| 7 | `potency` | `float` | Yes |
| 8 | `potency_UOM` | `nvarchar(20)` | Yes |
| 9 | `item_status` | `nvarchar(30)` | Yes |
| 10 | `stocking_type` | `nvarchar(4)` | Yes |
| 11 | `tier_level` | `nvarchar(4)` | Yes |
| 12 | `vendor_name` | `nvarchar(60)` | Yes |
| 13 | `quantity_available` | `float` | Yes |
| 14 | `total_last_12_months` | `float` | Yes |
| 15 | `trademark` | `nvarchar(64)` | Yes |
| 16 | `item_description_1` | `nvarchar(64)` | Yes |
| 17 | `item_description_2` | `nvarchar(30)` | Yes |
| 18 | `primary_UOM` | `nvarchar(2)` | Yes |
| 19 | `purch_UOM` | `nvarchar(2)` | Yes |
| 20 | `last_in_cost_v2` | `float` | Yes |
| 21 | `Category` | `varchar(3)` | Yes |
| 22 | `PLM_Vendor1` | `nvarchar(60)` | Yes |
| 23 | `PLM_Vendor2` | `nvarchar(60)` | Yes |
| 24 | `PLM_Vendor_UNK` | `nvarchar(60)` | Yes |
| 25 | `Allergen` | `nvarchar(10)` | Yes |
| 26 | `Item_Description` | `nvarchar(60)` | Yes |

## `dbo.Formula_Certification_Builder`

Current key status: no declared primary key in the supplied source. Current profiling
found no duplicate or blank trimmed `Cert_ID` or `Cert_Name` values, so `Cert_ID` can
become the replacement business-key constraint after staging validation.

| # | Column | SQL Server type | Null |
|---:|---|---|:---:|
| 1 | `Cert_ID` | `nvarchar(8)` | No |
| 2 | `Cert_Name` | `nvarchar(16)` | Yes |
| 3 | `NOTE` | `varchar(256)` | Yes |

## `dbo.Formula_Certification`

Current key status: no declared primary key. It relates to a legacy formula revision
through branch, parent, blend, revision number, and workflow status.

| # | Column | SQL Server type | Null |
|---:|---|---|:---:|
| 1 | `FCMCU` | `nvarchar(12)` | No |
| 2 | `FCPRNT` | `nvarchar(64)` | No |
| 3 | `FCBLND` | `nvarchar(64)` | No |
| 4 | `FCRVNO` | `real` | No |
| 5 | `FCSTUS` | `nvarchar(32)` | No |
| 6 | `FCCERT` | `nvarchar(32)` | No |
| 7 | `FCDATE` | `int` | Yes |
| 8 | `FCNOTE` | `nvarchar(256)` | Yes |

Current source profiling found that `Formula_Certification.FCCERT` matches
`Formula_Certification_Builder.Cert_Name`, not `Cert_ID`. All 60 current assignments
match by trimmed certification name; none match by certification ID. The migration
must resolve the name to the builder row and store the new certification-type key.

## Insert-building rules to retain

- Join a legacy line to its header with `FMMCU = FHMCU`, `FMPRNT = FHPRNT`,
  `FMBLND = FHBLND`, and decimal-normalized `FMRVNO = FHRVNO`. Use status only as a
  migration validation check, not as revision identity.
- Generate and persist one internal `formula_code` for all migrated header revisions
  belonging to the same formulation family. The grouping rule still requires business
  approval.
- Insert the header first and capture the generated `formula_header_id`; use that ID
  for its line and item-map inserts.
- Populate both nullable header compatibility columns and their primary `PARENT` and
  `BLEND` map rows from `FHPRNT` and `FHBLND`.
- Use `Formula_Item.FMCOST` before historical/cache cost sources when seeding an
  existing line's selected cost.
- Do not join `Formulation_Assistant` by item number alone. Include branch and apply a
  deterministic rule that reduces duplicate vendor rows before selecting defaults.
- Preserve source `RunDate`/Julian values until their calendar-date semantics have
  been verified. Do not guess a conversion during the insert.
- Do not make parent, blend, name, revision, or status a target primary key. Stage
  legacy headers, deduplicate them, assign `formula_header_id`, and use an explicit
  source-to-target mapping table while migrating children.
- Migrate certifications by the five available legacy relationship columns first.
  Current profiling yields 7 direct matches. Ignoring status only when exactly one
  four-column header candidate exists safely resolves another 23; 30 rows remain
  unmatched and require a quarantine/manual mapping decision.
- Resolve `Formula_Certification.FCCERT` against trimmed `Cert_Name`, then store the
  replacement certification type ID/code. Do not join it directly to legacy
  `Cert_ID`.
