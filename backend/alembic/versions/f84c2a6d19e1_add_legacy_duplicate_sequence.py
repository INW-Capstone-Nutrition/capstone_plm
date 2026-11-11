"""Add an audit ordinal for duplicate legacy formula headers.

Revision ID: f84c2a6d19e1
Revises: d13a7c82f904
Create Date: 2026-10-13
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "f84c2a6d19e1"
down_revision: str | Sequence[str] | None = "d13a7c82f904"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

FORMULA_SCHEMA = "form"


def upgrade() -> None:
    op.add_column(
        "formula_revision",
        sa.Column("legacy_duplicate_sequence", sa.SmallInteger(), nullable=True),
        schema=FORMULA_SCHEMA,
    )


def downgrade() -> None:
    op.drop_column(
        "formula_revision",
        "legacy_duplicate_sequence",
        schema=FORMULA_SCHEMA,
    )
