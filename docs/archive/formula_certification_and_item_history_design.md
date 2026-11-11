# Formula certification and item-history design

## Parent, blend, name, and identity

The legacy fields have different meanings:

- `FHNAME` is the human-readable formula name. It is mutable and is not present in
  formula child tables, so it cannot be part of a usable legacy relationship key.
- `FHPRNT` identifies the legacy parent/finished-good context when a JDE item exists.
  The legacy application also places provisional `P - ...` labels in this field.
- `FHBLND` identifies the legacy blend/bulk context when a JDE item exists. The
  application also places provisional `B - ...` labels in this field.
- `FHRVNO` identifies the legacy revision within that context.

Current `PLM` profiling supports that interpretation:

| Finding | Result |
|---|---:|
| Formula-header rows | 38,815 |
| Numeric parent rows | 19,830 |
| Numeric blend rows | 20,790 |
| `P - ...` provisional parent rows | 17,163 |
| `B - ...` provisional blend rows | 17,137 |
| Distinct numeric parents found in current JDE item master | 2,226 of 2,249 |
| Distinct numeric blends found in current JDE item master | 2,461 of 2,477 |
| Formula names used by more than one parent/blend pair | 766 |
| Blend values used by more than one parent | 138 |

The new application should therefore use an internal `formula_code` as the stable
pre-JDE identity. Nullable parent and blend columns remain on `form.formula_header`
for legacy compatibility, while `form.formula_item_map` supports multiple future JDE
assignments.

## Do not create a legacy composite primary key

The available legacy relationship tuple is:

```text
branch + parent + blend + revision + status
```

Formula name is not available in `Formula_Item` or `Formula_Certification` as a
reliable relationship column. It cannot repair the key.

The production source also does not satisfy a uniqueness constraint:

| Candidate | Duplicate groups |
|---|---:|
| Branch + parent + blend + revision | 150 |
| Branch + parent + blend + revision + status | 66 |
| Five-column groups with conflicting names | 17 |
| Maximum rows for one five-column key | 10 |

Use `form.formula_header.formula_header_id int` as the target primary key. Treat the
legacy columns as migration/reconciliation attributes, not as a target PK or FK.
Migration requires a staging table with its own row ID, a documented deduplication
rule, and a source-row-to-target-header mapping.

## Formula certifications

Certifications are one-to-many children of a formula revision and do not fit into the
three core formula tables. Add them under `quality` after the formula model is approved:

```sql
CREATE TABLE [quality].[certification_type]
(
    [certification_type_id] int IDENTITY(1,1) NOT NULL PRIMARY KEY,
    [certification_code] nvarchar(8) NOT NULL UNIQUE,
    [certification_name] nvarchar(32) NOT NULL,
    [notes] nvarchar(256) NULL
);

CREATE TABLE [quality].[formula_certification]
(
    [formula_certification_id] int IDENTITY(1,1) NOT NULL PRIMARY KEY,
    [formula_header_id] int NOT NULL,
    [certification_type_id] int NOT NULL,
    [legacy_certification_date_value] int NULL,
    [notes] nvarchar(256) NULL,
    [created_at_utc] datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT [FK_formula_certification_header]
        FOREIGN KEY ([formula_header_id])
        REFERENCES [form].[formula_header] ([formula_header_id]),
    CONSTRAINT [FK_formula_certification_type]
        FOREIGN KEY ([certification_type_id])
        REFERENCES [quality].[certification_type] ([certification_type_id]),
    CONSTRAINT [UQ_formula_certification]
        UNIQUE ([formula_header_id], [certification_type_id])
);
```

Source data requires cleanup:

- The certification tables are in `PLM`, not the current `PLM_DEV` target.
- All 60 current `FCCERT` values match `Cert_Name`; none match `Cert_ID`.
- Seven certification rows directly match a header using all five legacy columns.
- Another 23 resolve uniquely when status is ignored.
- Thirty remain unmatched and must be quarantined or manually mapped.

Do not silently discard or arbitrarily attach the unmatched rows.

## PLM item/specification ownership

The eight discovered item tables are relevant, but they are not formula-header or
formula-line columns:

| Legacy table | Proposed owner | Purpose |
|---|---|---|
| `Item_Extension` | `mat` | PLM-owned item/branch extension root |
| `Item_Allergen` | `specs` | Allergen declarations |
| `Item_Country` | `specs` | Country/regulatory applicability |
| `Item_Property` | `specs` or `quality` | Test/property requirements and results metadata |
| `Item_Regulatory_Requirement` | `specs` | Regulatory flags and preferences |
| `Item_Solvent` | `specs` | Solvent composition/detail |
| `Item_Vendor_Part` | `mat` | Vendor/manufacturer part relationships |
| `Item_JDE_Original` | `audit` | Dated snapshot of original JDE values |

All eight existing tables are non-temporal. Updating or deleting a row can currently
erase prior state, except for history manually represented by dated
`Item_JDE_Original` rows.

## Audit-safe recommendation

Use two layers:

1. **Current lookup layer:** JDE/core views plus current PLM-owned `mat` and `specs`
   records for editing, searches, and defaults.
2. **Immutable approved snapshot:** when a formula revision is approved, preserve the
   material/specification facts actually used by that revision.

The immutable layer can be implemented in one of two ways:

- explicit `specs.item_spec_revision` records and children, with each formula line
  referencing the approved specification revision; or
- an immutable approval snapshot document per formula revision/material when rapid
  implementation is more important than relational reporting.

The explicit specification-revision model is preferable when old allergen, country,
property, solvent, vendor, and regulatory values must be queried individually. A JSON
snapshot is simpler but less convenient for cross-formula reporting.

SQL Server temporal tables can supplement either design for change auditing, but a
temporal history alone is not the same as an approved business snapshot. The formula
revision should retain an explicit reference to the material/specification version it
used so an auditor does not need to infer the correct point in time.

Do not copy volatile `Formulation_Assistant` fields such as inventory availability or
rolling usage into the approved formula. Snapshot only values used in the formula's
calculation or decision, such as selected cost, potency, UOM, material description,
and selected vendor.
