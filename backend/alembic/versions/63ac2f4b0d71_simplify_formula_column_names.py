"""Use id primary keys and concise formula snapshot column names.

Revision ID: 63ac2f4b0d71
Revises: 52d91f6c80ab
Create Date: 2026-10-27
"""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import mssql

from alembic import op

revision: str = "63ac2f4b0d71"
down_revision: str | Sequence[str] | None = "52d91f6c80ab"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

FORMULA_SCHEMA = "form"
AUDIT_DT = sa.DateTime(timezone=True).with_variant(mssql.DATETIME2(precision=3), "mssql")

LINE_RENAMES = (
    ("material_description_snapshot", "material_description"),
    ("material_category_snapshot", "material_category"),
    ("trademark_snapshot", "trademark"),
    ("selected_vendor_name_snapshot", "selected_vendor_name"),
    ("primary_uom_snapshot", "primary_uom"),
    ("cost_uom_snapshot", "cost_uom"),
    ("cost_snapshot_run_julian_date", "cost_run_julian_date"),
)


def _rename(table: str, old: str, new: str) -> None:
    op.alter_column(table, old, new_column_name=new, schema=FORMULA_SCHEMA)


def upgrade() -> None:
    _rename("formula", "formula_id", "id")
    _rename("formula_header", "formula_header_id", "id")
    _rename("formula_line", "formula_line_id", "id")
    for old, new in LINE_RENAMES:
        _rename("formula_line", old, new)
    op.drop_column("formula_header", "approval_dt", schema=FORMULA_SCHEMA)
    op.drop_column("formula_header", "approved_by", schema=FORMULA_SCHEMA)


def downgrade() -> None:
    op.add_column(
        "formula_header",
        sa.Column("approval_dt", AUDIT_DT, nullable=True),
        schema=FORMULA_SCHEMA,
    )
    op.add_column(
        "formula_header",
        sa.Column("approved_by", sa.Unicode(100), nullable=True),
        schema=FORMULA_SCHEMA,
    )
    for old, new in reversed(LINE_RENAMES):
        _rename("formula_line", new, old)
    _rename("formula_line", "id", "formula_line_id")
    _rename("formula_header", "id", "formula_header_id")
    _rename("formula", "id", "formula_id")
