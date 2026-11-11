"""Initial PLM schema with versioned formulas and ownership metadata.

Revision ID: 8642c144a3ea
Revises:
Create Date: 2026-10-07

This revision was finalized before deployment of the earlier prototype migration.
"""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import mssql

from alembic import op

revision: str = "8642c144a3ea"
down_revision: str | Sequence[str] | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

FORMULA_SCHEMA = "form"
AUDIT_DT = sa.DateTime(timezone=True).with_variant(mssql.DATETIME2(precision=3), "mssql")
NVARCHAR_MAX = sa.UnicodeText().with_variant(mssql.NVARCHAR(None), "mssql")


def _audit_columns() -> list[sa.Column]:
    return [
        sa.Column("created_by", sa.Unicode(100), nullable=False, server_default="SYSTEM"),
        sa.Column(
            "created_dt", AUDIT_DT, nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")
        ),
        sa.Column("updated_by", sa.Unicode(100), nullable=False, server_default="SYSTEM"),
        sa.Column(
            "updated_dt", AUDIT_DT, nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")
        ),
    ]


def upgrade() -> None:
    if op.get_bind().dialect.name == "mssql":
        op.execute(
            "IF SCHEMA_ID(N'form') IS NULL EXEC(N'CREATE SCHEMA [form] AUTHORIZATION [dbo]')"
        )

    op.create_table(
        "app_user",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_name", sa.String(80), nullable=False),
        sa.Column("display_name", sa.String(160), nullable=False),
        sa.Column("email", sa.String(200), nullable=True),
        sa.Column("role", sa.String(40), nullable=False),
        sa.Column("branch_code", sa.String(12), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        *_audit_columns(),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_app_user_user_name", "app_user", ["user_name"], unique=True)

    op.create_table(
        "audit_event",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("occurred_at", AUDIT_DT, nullable=False),
        sa.Column("actor", sa.String(80), nullable=False),
        sa.Column("action", sa.String(80), nullable=False),
        sa.Column("aggregate_type", sa.String(80), nullable=False),
        sa.Column("aggregate_id", sa.String(80), nullable=False),
        sa.Column("summary", sa.Text(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_audit_event_occurred_at", "audit_event", ["occurred_at"])
    op.create_index("ix_audit_event_aggregate_type", "audit_event", ["aggregate_type"])
    op.create_index("ix_audit_event_aggregate_id", "audit_event", ["aggregate_id"])

    op.create_table(
        "formula",
        sa.Column("formula_id", sa.Integer(), nullable=False),
        sa.Column("record_origin", sa.String(20), nullable=False, server_default="PLM"),
        sa.Column("is_voided", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("voided_dt", AUDIT_DT, nullable=True),
        sa.Column("voided_by", sa.Unicode(100), nullable=True),
        sa.Column("void_reason", sa.Unicode(256), nullable=True),
        *_audit_columns(),
        sa.PrimaryKeyConstraint("formula_id"),
        schema=FORMULA_SCHEMA,
    )

    op.create_table(
        "material",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("item_number", sa.String(40), nullable=False),
        sa.Column("description", sa.String(200), nullable=False),
        sa.Column("category", sa.String(80), nullable=True),
        sa.Column("base_uom", sa.String(12), nullable=False),
        sa.Column("cas_number", sa.String(80), nullable=True),
        sa.Column("latin_name", sa.String(160), nullable=True),
        sa.Column("trademark", sa.String(160), nullable=True),
        *_audit_columns(),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_material_item_number", "material", ["item_number"], unique=True)
    op.create_index("ix_material_description", "material", ["description"])

    op.create_table(
        "formula_revision",
        sa.Column("formula_revision_id", sa.Integer(), nullable=False),
        sa.Column("formula_id", sa.Integer(), nullable=False),
        sa.Column("sequence", sa.Integer(), nullable=False),
        sa.Column("revision_number", sa.Numeric(10, 4), nullable=False),
        sa.Column("workflow_status", sa.Unicode(32), nullable=False),
        sa.Column("approval_dt", AUDIT_DT, nullable=True),
        sa.Column("approved_by", sa.Unicode(100), nullable=True),
        sa.Column("formula_name", sa.Unicode(60), nullable=False),
        sa.Column("branch_code", sa.Unicode(12), nullable=True),
        sa.Column("parent_item_number", sa.Unicode(64), nullable=True),
        sa.Column("blend_item_number", sa.Unicode(64), nullable=True),
        sa.Column("customer_number", sa.Unicode(30), nullable=True),
        sa.Column("customer_name", sa.Unicode(60), nullable=True),
        sa.Column("customer_part_number", sa.Unicode(60), nullable=True),
        sa.Column("revision_author", sa.Unicode(30), nullable=True),
        sa.Column("unit_type", sa.Unicode(30), nullable=True),
        sa.Column("size_description", sa.Unicode(30), nullable=True),
        sa.Column("formula_material_type", sa.Unicode(30), nullable=True),
        sa.Column("formula_category", sa.Unicode(30), nullable=True),
        sa.Column("color_description", sa.Unicode(30), nullable=True),
        sa.Column("units_per_daily_dose", sa.Integer(), nullable=True),
        sa.Column("servings", sa.Integer(), nullable=True),
        sa.Column("daily_doses", sa.Integer(), nullable=True),
        sa.Column("hob_number", sa.Unicode(30), nullable=True),
        sa.Column("raw_material_markup_percent", sa.Numeric(10, 4), nullable=True),
        sa.Column("manufacturing_overage_percent", sa.Numeric(10, 4), nullable=True),
        sa.Column("capsule_component_item_number", sa.Unicode(30), nullable=True),
        sa.Column("coating_solids_percent", sa.Numeric(10, 4), nullable=True),
        sa.Column("coating_weight_gain_percent", sa.Numeric(10, 4), nullable=True),
        sa.Column("coating_wax_percent", sa.Numeric(10, 4), nullable=True),
        sa.Column("change_code", sa.Unicode(8), nullable=True),
        sa.Column("change_reference", sa.Unicode(32), nullable=True),
        sa.Column("legacy_transaction_julian_date", sa.BigInteger(), nullable=True),
        sa.Column("notes", NVARCHAR_MAX, nullable=True),
        sa.Column("additional_information", sa.Unicode(1024), nullable=True),
        sa.Column("calculation_run_julian_date", sa.Integer(), nullable=True),
        sa.Column("total_daily_dose_mg", sa.Numeric(12, 4), nullable=True),
        sa.Column("total_mg_per_unit", sa.Numeric(12, 4), nullable=True),
        sa.Column("total_mg_per_unit_with_overage", sa.Numeric(12, 4), nullable=True),
        sa.Column("total_formula_amount", sa.Numeric(10, 4), nullable=True),
        sa.Column("raw_material_count", sa.Integer(), nullable=True),
        sa.Column("formula_cost", sa.Numeric(10, 4), nullable=True),
        sa.Column("last_active_julian_date", sa.Integer(), nullable=True),
        sa.Column("calculation_version", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
        *_audit_columns(),
        sa.ForeignKeyConstraint(["formula_id"], ["form.formula.formula_id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("formula_revision_id"),
        schema=FORMULA_SCHEMA,
    )

    op.create_table(
        "material_branch",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("material_id", sa.Integer(), nullable=False),
        sa.Column("branch_code", sa.String(12), nullable=False),
        sa.Column("item_status", sa.String(30), nullable=False),
        sa.Column("stocking_type", sa.String(20), nullable=True),
        sa.Column("tier_level", sa.String(20), nullable=True),
        sa.Column("vendor_name", sa.String(160), nullable=True),
        sa.Column("vendor_number", sa.String(40), nullable=True),
        sa.Column("unit_cost", sa.Numeric(18, 6), nullable=False),
        sa.Column("quantity_available", sa.Numeric(18, 4), nullable=False),
        *_audit_columns(),
        sa.ForeignKeyConstraint(["material_id"], ["material.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("material_id", "branch_code", name="uq_material_branch"),
    )
    op.create_index("ix_material_branch_branch_code", "material_branch", ["branch_code"])

    op.create_table(
        "material_specification",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("material_id", sa.Integer(), nullable=False),
        sa.Column("branch_code", sa.String(12), nullable=False),
        sa.Column("kind", sa.String(40), nullable=False),
        sa.Column("name", sa.String(120), nullable=False),
        sa.Column("value", sa.String(240), nullable=True),
        sa.Column("status", sa.String(40), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        *_audit_columns(),
        sa.ForeignKeyConstraint(["material_id"], ["material.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("material_id", "branch_code", "kind", "name", name="uq_material_spec"),
    )
    op.create_index(
        "ix_material_specification_branch_code", "material_specification", ["branch_code"]
    )
    op.create_index("ix_material_specification_kind", "material_specification", ["kind"])

    op.create_table(
        "formula_line",
        sa.Column("formula_line_id", sa.Integer(), nullable=False),
        sa.Column("formula_revision_id", sa.Integer(), nullable=False),
        sa.Column("material_id", sa.Integer(), nullable=True),
        sa.Column("line_number", sa.Integer(), nullable=False),
        sa.Column("material_item_number", sa.Unicode(25), nullable=False),
        sa.Column("material_branch_code", sa.Unicode(12), nullable=True),
        sa.Column("material_description_snapshot", sa.Unicode(60), nullable=True),
        sa.Column("material_category_snapshot", sa.Unicode(30), nullable=True),
        sa.Column("trademark_snapshot", sa.Unicode(64), nullable=True),
        sa.Column("selected_vendor_name_snapshot", sa.Unicode(128), nullable=True),
        sa.Column("primary_uom_snapshot", sa.Unicode(8), nullable=True),
        sa.Column("cost_uom_snapshot", sa.Unicode(8), nullable=True),
        sa.Column("quoted_cost", sa.Numeric(10, 4), nullable=True),
        sa.Column("selected_unit_cost", sa.Numeric(10, 4), nullable=True),
        sa.Column("cost_snapshot_run_julian_date", sa.Integer(), nullable=True),
        sa.Column("cost_source_code", sa.Unicode(20), nullable=True),
        sa.Column("potency", sa.Numeric(10, 4), nullable=True),
        sa.Column("potency_uom", sa.Unicode(8), nullable=True),
        sa.Column("active_amount", sa.Numeric(10, 4), nullable=True),
        sa.Column("line_overage_percent", sa.Numeric(10, 4), nullable=True),
        sa.Column("calculated_daily_dose_mg", sa.Numeric(10, 4), nullable=True),
        sa.Column("calculated_mg_per_unit", sa.Numeric(10, 4), nullable=True),
        sa.Column("calculated_mg_per_unit_with_overage", sa.Numeric(10, 4), nullable=True),
        sa.Column("calculated_formula_percent", sa.Numeric(10, 4), nullable=True),
        sa.Column("calculated_cost_percent", sa.Numeric(10, 4), nullable=True),
        sa.Column("print_cost", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("print_vendor", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("entered_by", sa.Unicode(30), nullable=True),
        sa.Column("notes", sa.Unicode(256), nullable=True),
        *_audit_columns(),
        sa.ForeignKeyConstraint(["material_id"], ["material.id"]),
        sa.ForeignKeyConstraint(
            ["formula_revision_id"],
            ["form.formula_revision.formula_revision_id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("formula_line_id"),
        schema=FORMULA_SCHEMA,
    )


def downgrade() -> None:
    op.drop_table("formula_line", schema=FORMULA_SCHEMA)
    op.drop_index("ix_material_specification_kind", table_name="material_specification")
    op.drop_index("ix_material_specification_branch_code", table_name="material_specification")
    op.drop_table("material_specification")
    op.drop_index("ix_material_branch_branch_code", table_name="material_branch")
    op.drop_table("material_branch")
    op.drop_table("formula_revision", schema=FORMULA_SCHEMA)
    op.drop_index("ix_material_description", table_name="material")
    op.drop_index("ix_material_item_number", table_name="material")
    op.drop_table("material")
    op.drop_table("formula", schema=FORMULA_SCHEMA)
    op.drop_index("ix_audit_event_aggregate_id", table_name="audit_event")
    op.drop_index("ix_audit_event_aggregate_type", table_name="audit_event")
    op.drop_index("ix_audit_event_occurred_at", table_name="audit_event")
    op.drop_table("audit_event")
    op.drop_index("ix_app_user_user_name", table_name="app_user")
    op.drop_table("app_user")
