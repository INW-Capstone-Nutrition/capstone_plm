"""Rename formula header and remove misplaced calculation and line audit columns.

Revision ID: c42a9f8d317e
Revises: a31b96c7e520
Create Date: 2026-10-14
"""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import mssql

from alembic import op

revision: str = "c42a9f8d317e"
down_revision: str | Sequence[str] | None = "a31b96c7e520"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

FORMULA_SCHEMA = "form"
AUDIT_DT = sa.DateTime(timezone=True).with_variant(mssql.DATETIME2(precision=3), "mssql")

CALCULATION_COLUMNS = (
    "calculation_run_julian_date",
    "total_daily_dose_mg",
    "total_mg_per_unit",
    "total_mg_per_unit_with_overage",
    "total_formula_amount",
    "raw_material_count",
    "formula_cost",
    "last_active_julian_date",
)


def upgrade() -> None:
    op.rename_table("formula", "formula_header", schema=FORMULA_SCHEMA)

    for column_name in CALCULATION_COLUMNS:
        op.drop_column("formula_revision", column_name, schema=FORMULA_SCHEMA)

    for column_name in ("created_by", "created_dt", "updated_by", "updated_dt"):
        op.drop_column(
            "formula_line",
            column_name,
            schema=FORMULA_SCHEMA,
            mssql_drop_default=True,
        )


def downgrade() -> None:
    op.add_column(
        "formula_line",
        sa.Column(
            "created_by", sa.Unicode(100), nullable=False, server_default=sa.text("'SYSTEM'")
        ),
        schema=FORMULA_SCHEMA,
    )
    op.add_column(
        "formula_line",
        sa.Column(
            "created_dt", AUDIT_DT, nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")
        ),
        schema=FORMULA_SCHEMA,
    )
    op.add_column(
        "formula_line",
        sa.Column(
            "updated_by", sa.Unicode(100), nullable=False, server_default=sa.text("'SYSTEM'")
        ),
        schema=FORMULA_SCHEMA,
    )
    op.add_column(
        "formula_line",
        sa.Column(
            "updated_dt", AUDIT_DT, nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")
        ),
        schema=FORMULA_SCHEMA,
    )

    op.add_column(
        "formula_revision",
        sa.Column("calculation_run_julian_date", sa.Integer(), nullable=True),
        schema=FORMULA_SCHEMA,
    )
    op.add_column(
        "formula_revision",
        sa.Column("total_daily_dose_mg", sa.Numeric(12, 4), nullable=True),
        schema=FORMULA_SCHEMA,
    )
    op.add_column(
        "formula_revision",
        sa.Column("total_mg_per_unit", sa.Numeric(12, 4), nullable=True),
        schema=FORMULA_SCHEMA,
    )
    op.add_column(
        "formula_revision",
        sa.Column("total_mg_per_unit_with_overage", sa.Numeric(12, 4), nullable=True),
        schema=FORMULA_SCHEMA,
    )
    op.add_column(
        "formula_revision",
        sa.Column("total_formula_amount", sa.Numeric(10, 4), nullable=True),
        schema=FORMULA_SCHEMA,
    )
    op.add_column(
        "formula_revision",
        sa.Column("raw_material_count", sa.Integer(), nullable=True),
        schema=FORMULA_SCHEMA,
    )
    op.add_column(
        "formula_revision",
        sa.Column("formula_cost", sa.Numeric(10, 4), nullable=True),
        schema=FORMULA_SCHEMA,
    )
    op.add_column(
        "formula_revision",
        sa.Column("last_active_julian_date", sa.Integer(), nullable=True),
        schema=FORMULA_SCHEMA,
    )

    op.rename_table("formula_header", "formula", schema=FORMULA_SCHEMA)
