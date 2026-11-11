"""Preserve large legacy formula-line potency values.

Revision ID: 52d91f6c80ab
Revises: e7b4d2a91c60
Create Date: 2026-10-26
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "52d91f6c80ab"
down_revision: str | Sequence[str] | None = "e7b4d2a91c60"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.alter_column(
        "formula_line",
        "potency",
        existing_type=sa.Numeric(16, 8),
        type_=sa.Numeric(18, 8),
        existing_nullable=True,
        schema="form",
    )


def downgrade() -> None:
    op.alter_column(
        "formula_line",
        "potency",
        existing_type=sa.Numeric(18, 8),
        type_=sa.Numeric(16, 8),
        existing_nullable=True,
        schema="form",
    )
