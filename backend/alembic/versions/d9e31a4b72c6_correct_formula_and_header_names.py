"""Keep the aggregate root as formula and name each revision record formula_header.

Revision ID: d9e31a4b72c6
Revises: c42a9f8d317e
Create Date: 2026-10-14
"""

from collections.abc import Sequence

from alembic import op

revision: str = "d9e31a4b72c6"
down_revision: str | Sequence[str] | None = "c42a9f8d317e"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

FORMULA_SCHEMA = "form"


def upgrade() -> None:
    op.rename_table("formula_header", "formula", schema=FORMULA_SCHEMA)
    op.rename_table("formula_revision", "formula_header", schema=FORMULA_SCHEMA)

    op.alter_column(
        "formula_header",
        "formula_revision_id",
        new_column_name="formula_header_id",
        schema=FORMULA_SCHEMA,
    )
    op.alter_column(
        "formula_line",
        "formula_revision_id",
        new_column_name="formula_header_id",
        schema=FORMULA_SCHEMA,
    )
    op.alter_column(
        "formula_review_issue",
        "formula_revision_id",
        new_column_name="formula_header_id",
        schema=FORMULA_SCHEMA,
    )


def downgrade() -> None:
    op.alter_column(
        "formula_review_issue",
        "formula_header_id",
        new_column_name="formula_revision_id",
        schema=FORMULA_SCHEMA,
    )
    op.alter_column(
        "formula_line",
        "formula_header_id",
        new_column_name="formula_revision_id",
        schema=FORMULA_SCHEMA,
    )
    op.alter_column(
        "formula_header",
        "formula_header_id",
        new_column_name="formula_revision_id",
        schema=FORMULA_SCHEMA,
    )

    op.rename_table("formula_header", "formula_revision", schema=FORMULA_SCHEMA)
    op.rename_table("formula", "formula_header", schema=FORMULA_SCHEMA)
