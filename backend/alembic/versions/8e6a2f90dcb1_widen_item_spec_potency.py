"""Widen item specification potency for legacy EXPTNC values.

Revision ID: 8e6a2f90dcb1
Revises: 74661cdc5fba
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "8e6a2f90dcb1"
down_revision: str | Sequence[str] | None = "74661cdc5fba"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.alter_column(
        "item_spec",
        "potency",
        schema="spec",
        existing_type=sa.Numeric(18, 8),
        type_=sa.Numeric(24, 8),
        existing_nullable=True,
    )


def downgrade() -> None:
    op.alter_column(
        "item_spec",
        "potency",
        schema="spec",
        existing_type=sa.Numeric(24, 8),
        type_=sa.Numeric(18, 8),
        existing_nullable=True,
    )
