"""Replace formula status with an explicit production flag.

Revision ID: d13a7c82f904
Revises: b6f2c91e45ad
Create Date: 2026-10-13
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "d13a7c82f904"
down_revision: str | Sequence[str] | None = "b6f2c91e45ad"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

FORMULA_SCHEMA = "form"


def upgrade() -> None:
    op.add_column(
        "formula",
        sa.Column("is_production", sa.Boolean(), nullable=False, server_default=sa.false()),
        schema=FORMULA_SCHEMA,
    )
    if op.get_bind().dialect.name == "mssql":
        op.execute(
            """
            UPDATE current_formula
            SET
                is_active = CASE
                    WHEN UPPER(LTRIM(RTRIM(COALESCE(latest.workflow_status, N''))))
                        IN (N'ACTIVE', N'COPY') THEN 1
                    ELSE 0
                END,
                is_production = CASE
                    WHEN latest.parent_item_number IS NULL THEN 0
                    WHEN UPPER(REPLACE(LTRIM(RTRIM(latest.parent_item_number)), N' ', N''))
                        LIKE N'P-%' THEN 0
                    WHEN UPPER(REPLACE(LTRIM(RTRIM(latest.parent_item_number)), N' ', N''))
                        LIKE N'B-%' THEN 0
                    WHEN UPPER(REPLACE(LTRIM(RTRIM(latest.parent_item_number)), N' ', N''))
                        LIKE N'AG1%' THEN 0
                    WHEN UPPER(LTRIM(RTRIM(COALESCE(latest.workflow_status, N''))))
                        IN (N'DEVELOPMENT', N'REVIEW', N'QUOTE') THEN 0
                    ELSE 1
                END
            FROM [form].[formula] AS current_formula
            OUTER APPLY (
                SELECT TOP (1)
                    revision.workflow_status,
                    revision.parent_item_number
                FROM [form].[formula_revision] AS revision
                WHERE revision.formula_id = current_formula.formula_id
                ORDER BY revision.sequence DESC, revision.formula_revision_id DESC
            ) AS latest
            """
        )
    op.drop_column(
        "formula",
        "status",
        schema=FORMULA_SCHEMA,
        mssql_drop_default=True,
    )


def downgrade() -> None:
    op.add_column(
        "formula",
        sa.Column("status", sa.Unicode(30), nullable=False, server_default="Development"),
        schema=FORMULA_SCHEMA,
    )
    if op.get_bind().dialect.name == "mssql":
        op.execute(
            """
            UPDATE current_formula
            SET status = LEFT(COALESCE(latest.workflow_status, N'Development'), 30)
            FROM [form].[formula] AS current_formula
            OUTER APPLY (
                SELECT TOP (1) revision.workflow_status
                FROM [form].[formula_revision] AS revision
                WHERE revision.formula_id = current_formula.formula_id
                ORDER BY revision.sequence DESC, revision.formula_revision_id DESC
            ) AS latest
            """
        )
    op.drop_column(
        "formula",
        "is_production",
        schema=FORMULA_SCHEMA,
        mssql_drop_default=True,
    )
