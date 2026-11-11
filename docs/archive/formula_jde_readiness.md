# Formula JDE readiness and next steps

## Current conclusion

The underlying `jde`/`core` source layer contains most of the ERP information needed
by the formula feature, but the formula-facing feature layer is not complete yet.

The canonical JDE work-order business key is:

```text
branch_code + work_order_number
```

Keep those as two typed columns. Do not rename `work_order_number` to
`work_order_id`, and do not use a concatenated string as the database join key.

Currently implemented under `form`:

- `form.vw_manufacturing_bom_component`
- `form.vw_latest_work_order_start`

Material identity, cost, inventory and usage are also available under `mat` and should
be consumed directly by the formula material picker/calculation service rather than
copied into duplicate `form` views.

## Formula-related JDE coverage

| Formula/ERP purpose | Verified source contract | Current feature shape | Status |
|---|---|---|---|
| Material/item identity and UOM | `jde.vw_f4101_item_master_prod`, `jde.vw_f4102_item_branch_prod` | `mat.vw_item_branch_cost` | Ready, except optional tier/two-line-description fields |
| Material vendor/customer names | `jde.vw_f0101_address_book_prod` | Included for JDE vendor in `mat.vw_item_branch_cost` | Ready for number/name lookup |
| Material cost options | `jde.vw_f4105_cost_ledger_prod` | `mat.vw_item_branch_cost` | Ready; finance must approve selection policy |
| Material availability | `jde.vw_f41021_item_loc_prod` | `mat.vw_inventory_balance` | Ready; inspection quantity intentionally absent |
| Material usage | `jde.vw_f3111_wo_parts_list_prod` | `mat.vw_material_usage_12_month` | Ready for rolling usage |
| Manufacturing BOM | `jde.vw_f3002_bom_master_prod` | `form.vw_manufacturing_bom_component` | Ready for as-of/effectivity-aware consumption |
| Current active BOM | `core.vw_bom_lines_active_prod` | No `form` wrapper yet | Source ready; wrapper optional |
| Work-order header/status/customer | `jde.vw_f4801_wo_master_prod` | Branch-specific latest-start aggregate only | Source carries the composite key; feature shape still required |
| Work-order components/actual usage | `jde.vw_f3111_wo_parts_list_prod` | Rolling usage aggregate only | Source carries branch + number; detailed feature shape still required |
| Work-order routing/operations | `jde.vw_f3112_wo_routing_prod` | None | `work_unit` exists, but must be proven equivalent to work-order branch before using it as the key |
| Work-order remarks | `jde.vw_f4802_wo_remarks_prod` | None | Branch is absent; cannot safely attach the approximately 5% non-unique numbers yet |
| Sales-order/customer context | `jde.vw_f4201_so_master_prod`, `jde.vw_f4211_so_detail_prod`, F0101 | None | Optional; build only if a formula use case consumes it |
| JDE code descriptions | `jde.vw_f0005_meta_data_prod` | `specs.vw_jde_code_reference` | Ready for lookups |

## Formula-facing views to build next

Build these as separate collections. Do not make one giant work-order view joining
components, routing and remarks because their one-to-many joins would multiply rows.

| Priority | Proposed view | Grain and purpose |
|---:|---|---|
| 1 | `form.vw_work_order_header` | One row per branch_code + work_order_number, enriched with customer name; formula/production inquiry |
| 2 | `form.vw_work_order_component` | One row per branch_code + work_order_number + component line/number; planned/transacted/remaining quantities and lot/location context |
| 3 | `form.vw_work_order_routing` | One row per branch_code + work_order_number + operation number; blocked until F3112 branch semantics are verified |
| 4 | `form.vw_work_order_remark` | One row per branch_code + work_order_number + remark type + line; blocked until F4802 can supply the branch key |
| 5 | `form.vw_active_manufacturing_bom_component` | Current-active convenience projection over `core.vw_bom_lines_active_prod`; use only where “today” is the intended business date |
| 6 | `form.vw_sales_order_line_context` | Optional sales order/line plus bill-to, ship-to and customer names |

The application/API should compose the separate child collections under a work order
or formula response. SQL should not flatten them into one repeating result set.

## Validation required before those views are considered complete

### 1. Enforce the agreed work-order identity

Use `branch_code + work_order_number` for every formula-facing work-order join and API
lookup. `work_order_number` alone is only approximately 95% unique and is not an
acceptable key.

- F4801 exposes `branch_code` and `work_order_number`.
- F3111 exposes `branch` and `work_order_number`; normalize `branch` as
  `branch_code` in the feature view.
- F3112 exposes `work_unit`, not a confirmed work-order branch. Verify it before
  treating it as `branch_code`; otherwise expose the actual branch from the source.
- F4802 currently exposes no branch. The remark feature view must remain deferred or
  the base contract must expose the correct branch/company discriminator.

Three current `core` joins use `work_order_number` alone:

- `core.vw_lot_item_byholds_prod`
- `core.vw_lot_transaction_use_prod`
- `core.vw_lot_wo_reference_prod`

Review those joins before relying on their work-order enrichment. They may attach a
lot/transaction to the wrong branch for the non-unique work-order numbers.

For sales orders, use the available composite identity:

- sales order number;
- sales order type; and
- order company.

### 2. Prove each view's grain

- BOM: branch + parent + component line/number + effectivity/revision.
- Work-order header: branch_code + work_order_number.
- Work-order component: branch_code + work_order_number + component line/number.
- Routing: branch_code + work_order_number + operation number.
- Remarks: branch_code + work_order_number + remark type + line number.

Run duplicate profiles before treating those combinations as application keys.

### 3. Verify business semantics with samples

Use representative work orders/formulas from each branch and reconcile:

- parent and component item numbers;
- BOM quantity/UOM and effectivity;
- planned, transacted and remaining component quantities;
- routing operation order and hours;
- customer/vendor names;
- remarks order;
- current and historical cost; and
- work-order and sales-order links.

### 4. Decide current versus historical behavior

- Formula editing should use current JDE material facts as defaults.
- Activated formula/report reproduction should use persisted snapshots.
- BOM comparison must accept an explicit business date unless the screen is
  explicitly “current active BOM.”
- Current JDE cost must not silently rewrite historical formula cost.

## What JDE will never complete for the formula domain

These remain PLM-owned even after the JDE formula boundary is finished:

- formula header and revision lifecycle;
- ingredient intent, potency overrides and overage;
- formula calculation version and results;
- review/approval decisions;
- formula notes and application audit history; and
- historical snapshots required to reproduce an activated formula.

## Recommended execution sequence

1. Treat `jde` and `core` as the only trusted ERP sources; keep `rpt` excluded.
2. Confirm F3112's branch field and identify the correct F4802 branch discriminator.
3. Build `form.vw_work_order_header` and `form.vw_work_order_component` now.
4. Build routing and remark views only after they can carry the composite key.
5. Review the three core work-order joins that currently use number alone.
6. Add the current-active BOM wrapper only if a “today” screen needs it.
7. Add sales-order/customer context only when a confirmed formula use case requires it.
8. Reconcile the feature views against representative JDE records from every branch.
9. Freeze the formula JDE contract and write parity tests.
10. Then proceed with typed user-maintained `specs` views.
11. Defer quality/dashboard views that depend on unverified `rpt` logic.
