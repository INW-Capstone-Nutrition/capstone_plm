from __future__ import annotations

from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    BigInteger,
    Boolean,
    ForeignKey,
    Index,
    Numeric,
    Unicode,
    UniqueConstraint,
    true,
)
from sqlalchemy.orm import Mapped, mapped_column

from api.database import AUDIT_DATETIME, AuditColumnsMixin, Base, utc_now


class Material(AuditColumnsMixin, Base):
    """One PLM material identity per branch and item number."""

    __tablename__ = "material"
    __table_args__ = (
        UniqueConstraint("branch_code", "item_number", name="uq_mat_material_branch_item"),
        {"schema": "mat"},
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    branch_code: Mapped[str] = mapped_column(Unicode(12))
    item_number: Mapped[str] = mapped_column(Unicode(40))
    description: Mapped[str | None] = mapped_column(Unicode(200))
    category: Mapped[str | None] = mapped_column(Unicode(80))
    base_uom: Mapped[str | None] = mapped_column(Unicode(12))
    stocking_type: Mapped[str | None] = mapped_column(Unicode(20))
    tier_level: Mapped[str | None] = mapped_column(Unicode(20))
    source_system: Mapped[str | None] = mapped_column(Unicode(20))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, server_default=true())


class FormulaItemCost(Base):
    __tablename__ = "formula_item_cost"
    __table_args__ = {"schema": "mat"}

    id: Mapped[int] = mapped_column(primary_key=True)
    run_julian_date: Mapped[int] = mapped_column(BigInteger)
    item_number: Mapped[str] = mapped_column(Unicode(40))
    item_cost: Mapped[Decimal | None] = mapped_column(Numeric(20, 8))


class ItemJdeOriginal(Base):
    __tablename__ = "item_jde_original"
    __table_args__ = (
        UniqueConstraint(
            "source_branch_code", "source_item_number", "source_julian_date",
            name="uq_mat_item_jde_original_source",
        ),
        {"schema": "mat"},
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    material_id: Mapped[int | None] = mapped_column(ForeignKey("mat.material.id"), index=True)
    source_branch_code: Mapped[str] = mapped_column(Unicode(12))
    source_item_number: Mapped[str] = mapped_column(Unicode(40))
    source_julian_date: Mapped[int] = mapped_column(BigInteger)
    description_3: Mapped[str | None] = mapped_column(Unicode(200))
    gl_posting_code: Mapped[str | None] = mapped_column(Unicode(40))
    stocking_type: Mapped[str | None] = mapped_column(Unicode(20))
    primary_uom: Mapped[str | None] = mapped_column(Unicode(12))
    category_code: Mapped[str | None] = mapped_column(Unicode(40))
    sld_value: Mapped[int | None]
    ltlv_value: Mapped[int | None]
    warr_value: Mapped[str | None] = mapped_column(Unicode(80))
    unit_cost: Mapped[Decimal | None] = mapped_column(Numeric(20, 8))
    lrgn_value: Mapped[str | None] = mapped_column(Unicode(80))


class FormulationAssistant(Base):
    __tablename__ = "formulation_assistant"
    __table_args__ = (
        Index("ix_mat_formulation_assistant_branch_item", "branch_code", "item_number"),
        {"schema": "mat"},
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    material_id: Mapped[int | None] = mapped_column(ForeignKey("mat.material.id"), index=True)
    source_table: Mapped[str] = mapped_column(Unicode(64))
    branch_code: Mapped[str | None] = mapped_column(Unicode(12))
    item_number: Mapped[str | None] = mapped_column(Unicode(40))
    ext_branch_code: Mapped[str | None] = mapped_column(Unicode(12))
    ext_item_number: Mapped[str | None] = mapped_column(Unicode(40))
    preference_code: Mapped[str | None] = mapped_column(Unicode(40))
    last_in_cost: Mapped[Decimal | None] = mapped_column(Numeric(20, 8))
    last_in_cost_v2: Mapped[Decimal | None] = mapped_column(Numeric(20, 8))
    potency: Mapped[Decimal | None] = mapped_column(Numeric(18, 8))
    potency_uom: Mapped[str | None] = mapped_column(Unicode(20))
    item_status: Mapped[str | None] = mapped_column(Unicode(40))
    stocking_type: Mapped[str | None] = mapped_column(Unicode(20))
    tier_level: Mapped[str | None] = mapped_column(Unicode(20))
    vendor_name: Mapped[str | None] = mapped_column(Unicode(160))
    quantity_available: Mapped[Decimal | None] = mapped_column(Numeric(20, 4))
    total_last_12_months: Mapped[Decimal | None] = mapped_column(Numeric(20, 4))
    trademark: Mapped[str | None] = mapped_column(Unicode(160))
    item_description_1: Mapped[str | None] = mapped_column(Unicode(200))
    item_description_2: Mapped[str | None] = mapped_column(Unicode(200))
    item_description: Mapped[str | None] = mapped_column(Unicode(200))
    primary_uom: Mapped[str | None] = mapped_column(Unicode(12))
    purchasing_uom: Mapped[str | None] = mapped_column(Unicode(12))
    category: Mapped[str | None] = mapped_column(Unicode(80))
    primary_plm_vendor: Mapped[str | None] = mapped_column(Unicode(160))
    secondary_plm_vendor: Mapped[str | None] = mapped_column(Unicode(160))
    unclassified_plm_vendor: Mapped[str | None] = mapped_column(Unicode(160))
    has_allergen: Mapped[bool | None] = mapped_column(Boolean)
    source_built_at: Mapped[datetime | None] = mapped_column(AUDIT_DATETIME)
    refreshed_at: Mapped[datetime] = mapped_column(AUDIT_DATETIME, default=utc_now)
