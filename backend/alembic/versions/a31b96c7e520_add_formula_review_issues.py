"""Add auditable formula migration review issues.

Revision ID: a31b96c7e520
Revises: f84c2a6d19e1
Create Date: 2026-10-14
"""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import mssql

from alembic import op

revision: str = "a31b96c7e520"
down_revision: str | Sequence[str] | None = "f84c2a6d19e1"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

FORMULA_SCHEMA = "form"
AUDIT_DT = sa.DateTime(timezone=True).with_variant(mssql.DATETIME2(precision=3), "mssql")


def _audit_columns() -> tuple[sa.Column, ...]:
    return (
        sa.Column(
            "created_by", sa.Unicode(100), nullable=False, server_default=sa.text("'SYSTEM'")
        ),
        sa.Column(
            "created_dt", AUDIT_DT, nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")
        ),
        sa.Column(
            "updated_by", sa.Unicode(100), nullable=False, server_default=sa.text("'SYSTEM'")
        ),
        sa.Column(
            "updated_dt", AUDIT_DT, nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")
        ),
    )


def upgrade() -> None:
    op.create_table(
        "formula_review_issue",
        sa.Column("formula_review_issue_id", sa.Integer(), nullable=False),
        sa.Column("formula_id", sa.Integer(), nullable=False),
        sa.Column("formula_revision_id", sa.Integer(), nullable=True),
        sa.Column("formula_line_id", sa.Integer(), nullable=True),
        sa.Column("issue_code", sa.Unicode(50), nullable=False),
        sa.Column(
            "severity", sa.Unicode(20), nullable=False, server_default=sa.text("'WARNING'")
        ),
        sa.Column(
            "review_status", sa.Unicode(20), nullable=False, server_default=sa.text("'OPEN'")
        ),
        sa.Column("issue_detail", sa.Unicode(1000), nullable=True),
        sa.Column("resolution_note", sa.Unicode(1000), nullable=True),
        sa.Column("reviewed_by", sa.Unicode(100), nullable=True),
        sa.Column("reviewed_dt", AUDIT_DT, nullable=True),
        *_audit_columns(),
        sa.ForeignKeyConstraint(
            ["formula_id"], ["form.formula.formula_id"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["formula_revision_id"],
            ["form.formula_revision.formula_revision_id"],
        ),
        sa.ForeignKeyConstraint(
            ["formula_line_id"], ["form.formula_line.formula_line_id"]
        ),
        sa.PrimaryKeyConstraint("formula_review_issue_id"),
        schema=FORMULA_SCHEMA,
    )


def downgrade() -> None:
    op.drop_table("formula_review_issue", schema=FORMULA_SCHEMA)
