"""Align the formula aggregate with the approved three-table ERD.

Revision ID: b6f2c91e45ad
Revises: 8642c144a3ea
Create Date: 2026-10-12
"""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import mssql

from alembic import op

revision: str = "b6f2c91e45ad"
down_revision: str | Sequence[str] | None = "8642c144a3ea"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

FORMULA_SCHEMA = "form"
NVARCHAR_MAX = sa.UnicodeText().with_variant(mssql.NVARCHAR(None), "mssql")


REVISION_RENAMES = (
    ("size_description", "size_", sa.Unicode(30)),
    ("formula_material_type", "material_type", sa.Unicode(30)),
    ("formula_category", "category", sa.Unicode(30)),
    ("color_description", "color", sa.Unicode(30)),
    ("units_per_daily_dose", "dosage_per_unit", sa.Integer()),
    ("servings", "serving_size", sa.Integer()),
    ("daily_doses", "daily_dose", sa.Integer()),
    ("hob_number", "hobb_number", sa.Unicode(30)),
    ("raw_material_markup_percent", "raw_material_markup", sa.Numeric(10, 4)),
    ("manufacturing_overage_percent", "overage_percent", sa.Numeric(10, 4)),
    ("capsule_component_item_number", "empty_capsule_number", sa.Unicode(30)),
    ("coating_solids_percent", "solids", sa.Numeric(10, 4)),
    ("coating_weight_gain_percent", "weight", sa.Numeric(10, 4)),
    ("coating_wax_percent", "carnuba_wax", sa.Numeric(10, 4)),
    ("change_code", "change_type", sa.Unicode(8)),
    ("change_reference", "change_number", sa.Unicode(32)),
)

LINE_RENAMES = (
    ("active_amount", "active_percent", sa.Numeric(10, 4)),
    ("line_overage_percent", "overage_percent", sa.Numeric(10, 4)),
    ("calculated_daily_dose_mg", "daily_dose_percent", sa.Numeric(10, 4)),
    ("calculated_mg_per_unit", "mg_per_capsule_percent", sa.Numeric(10, 4)),
    (
        "calculated_mg_per_unit_with_overage",
        "mg_per_capsule_with_overage",
        sa.Numeric(10, 4),
    ),
    ("calculated_formula_percent", "formula_percent", sa.Numeric(10, 4)),
    ("calculated_cost_percent", "cost_percent", sa.Numeric(10, 4)),
    ("print_cost", "is_total_cost_percent", sa.Boolean()),
    ("print_vendor", "is_total_formula_percent", sa.Boolean()),
)


def _rename_columns(table_name: str, renames: tuple[tuple[str, str, sa.TypeEngine], ...]) -> None:
    for old_name, new_name, column_type in renames:
        op.alter_column(
            table_name,
            old_name,
            new_column_name=new_name,
            existing_type=column_type,
            schema=FORMULA_SCHEMA,
        )


def upgrade() -> None:
    op.add_column(
        "formula",
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        schema=FORMULA_SCHEMA,
    )
    op.add_column(
        "formula",
        sa.Column("status", sa.Unicode(30), nullable=False, server_default="Development"),
        schema=FORMULA_SCHEMA,
    )
    if op.get_bind().dialect.name == "mssql":
        op.execute(
            """
            UPDATE current_formula
            SET
                status = LEFT(COALESCE(latest.workflow_status, N'Development'), 30),
                is_active = CASE
                    WHEN UPPER(COALESCE(latest.workflow_status, N''))
                        IN (N'ARCHIVE', N'ARCHIVED', N'DELETE') THEN 0
                    ELSE 1
                END
            FROM [form].[formula] AS current_formula
            OUTER APPLY (
                SELECT TOP (1) revision.workflow_status
                FROM [form].[formula_revision] AS revision
                WHERE revision.formula_id = current_formula.formula_id
                ORDER BY revision.sequence DESC, revision.formula_revision_id DESC
            ) AS latest
            """
        )
    op.drop_column("formula", "voided_dt", schema=FORMULA_SCHEMA)
    op.drop_column("formula", "voided_by", schema=FORMULA_SCHEMA)
    op.drop_column("formula", "void_reason", schema=FORMULA_SCHEMA)

    _rename_columns("formula_revision", REVISION_RENAMES)
    _rename_columns("formula_line", LINE_RENAMES)
    op.alter_column(
        "formula_line",
        "notes",
        existing_type=sa.Unicode(256),
        type_=NVARCHAR_MAX,
        existing_nullable=True,
        schema=FORMULA_SCHEMA,
    )


def downgrade() -> None:
    op.alter_column(
        "formula_line",
        "notes",
        existing_type=NVARCHAR_MAX,
        type_=sa.Unicode(256),
        existing_nullable=True,
        schema=FORMULA_SCHEMA,
    )
    _rename_columns(
        "formula_line",
        tuple(
            (new_name, old_name, column_type) for old_name, new_name, column_type in LINE_RENAMES
        ),
    )
    _rename_columns(
        "formula_revision",
        tuple(
            (new_name, old_name, column_type)
            for old_name, new_name, column_type in REVISION_RENAMES
        ),
    )

    op.add_column(
        "formula",
        sa.Column("voided_dt", sa.DateTime(timezone=True), nullable=True),
        schema=FORMULA_SCHEMA,
    )
    op.add_column(
        "formula",
        sa.Column("voided_by", sa.Unicode(100), nullable=True),
        schema=FORMULA_SCHEMA,
    )
    op.add_column(
        "formula",
        sa.Column("void_reason", sa.Unicode(256), nullable=True),
        schema=FORMULA_SCHEMA,
    )
    op.drop_column(
        "formula",
        "status",
        schema=FORMULA_SCHEMA,
        mssql_drop_default=True,
    )
    op.drop_column(
        "formula",
        "is_active",
        schema=FORMULA_SCHEMA,
        mssql_drop_default=True,
    )
