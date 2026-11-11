"""Add material lifecycle flag without deleting referenced history.

Revision ID: b2e53f781d46
Revises: 8e6a2f90dcb1
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "b2e53f781d46"
down_revision: str | Sequence[str] | None = "8e6a2f90dcb1"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "material",
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        schema="mat",
    )


def downgrade() -> None:
    op.drop_column("material", "is_active", schema="mat")
