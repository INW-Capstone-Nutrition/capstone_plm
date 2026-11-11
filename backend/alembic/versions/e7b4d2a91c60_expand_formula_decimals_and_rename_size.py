"""Expand formula decimals and name the header size column directly.

Revision ID: e7b4d2a91c60
Revises: d9e31a4b72c6
Create Date: 2026-10-22
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "e7b4d2a91c60"
down_revision: str | Sequence[str] | None = "d9e31a4b72c6"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


HEADER_DECIMALS = (
    "revision_number",
    "raw_material_markup",
    "overage_percent",
    "solids",
    "weight",
    "carnuba_wax",
)

LINE_DECIMALS = (
    "quoted_cost",
    "selected_unit_cost",
    "potency",
    "active_percent",
    "overage_percent",
    "daily_dose_percent",
    "mg_per_capsule_percent",
    "mg_per_capsule_with_overage",
    "formula_percent",
    "cost_percent",
)


def _alter_decimal_columns(old_type: sa.Numeric, new_type: sa.Numeric) -> None:
    for table_name, columns in (
        ("formula_header", HEADER_DECIMALS),
        ("formula_line", LINE_DECIMALS),
    ):
        with op.batch_alter_table(table_name, schema="form") as batch_op:
            for column_name in columns:
                batch_op.alter_column(
                    column_name,
                    existing_type=old_type,
                    type_=new_type,
                    existing_nullable=column_name != "revision_number",
                )


def upgrade() -> None:
    _alter_decimal_columns(sa.Numeric(10, 4), sa.Numeric(16, 8))
    with op.batch_alter_table("formula_header", schema="form") as batch_op:
        batch_op.alter_column(
            "size_",
            new_column_name="size",
            existing_type=sa.Unicode(30),
            existing_nullable=True,
        )


def downgrade() -> None:
    with op.batch_alter_table("formula_header", schema="form") as batch_op:
        batch_op.alter_column(
            "size",
            new_column_name="size_",
            existing_type=sa.Unicode(30),
            existing_nullable=True,
        )
    _alter_decimal_columns(sa.Numeric(16, 8), sa.Numeric(10, 4))
