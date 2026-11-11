from __future__ import annotations

from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    BigInteger,
    Boolean,
    ForeignKey,
    Integer,
    Numeric,
    SmallInteger,
    String,
    Unicode,
    UnicodeText,
    event,
)
from sqlalchemy.dialects import mssql
from sqlalchemy.orm import Mapped, Session, mapped_column, relationship

from api.database import AUDIT_DATETIME, AuditColumnsMixin, Base, utc_now

FORMULA_SCHEMA = "form"
NVARCHAR_MAX = UnicodeText().with_variant(mssql.NVARCHAR(None), "mssql")


class Formula(AuditColumnsMixin, Base):
    """Stable identity for one formula family across all future revisions."""

    __tablename__ = "formula"
    __table_args__ = {"schema": FORMULA_SCHEMA}

    id: Mapped[int] = mapped_column(primary_key=True)
    record_origin: Mapped[str] = mapped_column(String(20), default="PLM")
    is_voided: Mapped[bool] = mapped_column(Boolean, default=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=False)
    is_production: Mapped[bool] = mapped_column(Boolean, default=False)

    headers: Mapped[list[FormulaHeader]] = relationship(
        back_populates="formula",
        cascade="all, delete-orphan",
        order_by="FormulaHeader.sequence",
    )
    review_issues: Mapped[list[FormulaReviewIssue]] = relationship(
        back_populates="formula",
        cascade="all, delete-orphan",
        order_by="FormulaReviewIssue.id",
    )


class FormulaHeader(AuditColumnsMixin, Base):
    """Complete, independently reproducible header snapshot for one revision."""

    __tablename__ = "formula_header"
    __table_args__ = {"schema": FORMULA_SCHEMA}

    id: Mapped[int] = mapped_column(primary_key=True)
    formula_id: Mapped[int] = mapped_column(
        ForeignKey(f"{FORMULA_SCHEMA}.formula.id", ondelete="CASCADE")
    )
    sequence: Mapped[int] = mapped_column(Integer, default=1)
    revision_number: Mapped[Decimal] = mapped_column(Numeric(16, 8))
    legacy_duplicate_sequence: Mapped[int | None] = mapped_column(SmallInteger)
    workflow_status: Mapped[str] = mapped_column(Unicode(32), default="Development")
    formula_name: Mapped[str] = mapped_column(Unicode(60))
    branch_code: Mapped[str | None] = mapped_column(Unicode(12))
    parent_item_number: Mapped[str | None] = mapped_column(Unicode(64))
    blend_item_number: Mapped[str | None] = mapped_column(Unicode(64))
    customer_number: Mapped[str | None] = mapped_column(Unicode(30))
    customer_name: Mapped[str | None] = mapped_column(Unicode(60))
    customer_part_number: Mapped[str | None] = mapped_column(Unicode(60))
    revision_author: Mapped[str | None] = mapped_column(Unicode(30))
    unit_type: Mapped[str | None] = mapped_column(Unicode(30))
    size: Mapped[str | None] = mapped_column(Unicode(30))
    material_type: Mapped[str | None] = mapped_column(Unicode(30))
    category: Mapped[str | None] = mapped_column(Unicode(30))
    color: Mapped[str | None] = mapped_column(Unicode(30))
    dosage_per_unit: Mapped[int | None]
    serving_size: Mapped[int | None]
    daily_dose: Mapped[int | None]
    hobb_number: Mapped[str | None] = mapped_column(Unicode(30))

    raw_material_markup: Mapped[Decimal | None] = mapped_column(Numeric(16, 8))
    overage_percent: Mapped[Decimal | None] = mapped_column(Numeric(16, 8))
    empty_capsule_number: Mapped[str | None] = mapped_column(Unicode(30))
    solids: Mapped[Decimal | None] = mapped_column(Numeric(16, 8))
    weight: Mapped[Decimal | None] = mapped_column(Numeric(16, 8))
    carnuba_wax: Mapped[Decimal | None] = mapped_column(Numeric(16, 8))

    change_type: Mapped[str | None] = mapped_column(Unicode(8))
    change_number: Mapped[str | None] = mapped_column(Unicode(32))
    legacy_transaction_julian_date: Mapped[int | None] = mapped_column(BigInteger)
    notes: Mapped[str | None] = mapped_column(NVARCHAR_MAX)
    additional_information: Mapped[str | None] = mapped_column(Unicode(1024))

    calculation_version: Mapped[int] = mapped_column(Integer, default=1)
    version: Mapped[int] = mapped_column(Integer, default=1)

    formula: Mapped[Formula] = relationship(back_populates="headers")
    lines: Mapped[list[FormulaLine]] = relationship(
        back_populates="header",
        cascade="all, delete-orphan",
        order_by="FormulaLine.line_number",
    )
    review_issues: Mapped[list[FormulaReviewIssue]] = relationship(back_populates="header")

    @property
    def revision_label(self) -> str:
        return format(self.revision_number, "f").rstrip("0").rstrip(".")


class FormulaLine(Base):
    __tablename__ = "formula_line"
    __table_args__ = {"schema": FORMULA_SCHEMA}

    id: Mapped[int] = mapped_column(primary_key=True)
    header_id: Mapped[int] = mapped_column(
        "formula_header_id",
        ForeignKey(f"{FORMULA_SCHEMA}.formula_header.id", ondelete="CASCADE"),
    )
    material_id: Mapped[int | None] = mapped_column(ForeignKey("mat.material.id"))
    item_spec_id: Mapped[int | None] = mapped_column(ForeignKey("spec.item_spec.id"))
    line_number: Mapped[int]
    material_item_number: Mapped[str] = mapped_column(Unicode(25))
    material_branch_code: Mapped[str | None] = mapped_column(Unicode(12))
    material_description: Mapped[str | None] = mapped_column(Unicode(60))
    material_category: Mapped[str | None] = mapped_column(Unicode(30))
    trademark: Mapped[str | None] = mapped_column(Unicode(64))
    selected_vendor_name: Mapped[str | None] = mapped_column(Unicode(128))
    primary_uom: Mapped[str | None] = mapped_column(Unicode(8))
    cost_uom: Mapped[str | None] = mapped_column(Unicode(8))

    quoted_cost: Mapped[Decimal | None] = mapped_column(Numeric(16, 8))
    selected_unit_cost: Mapped[Decimal | None] = mapped_column(Numeric(16, 8))
    cost_run_julian_date: Mapped[int | None]
    cost_source_code: Mapped[str | None] = mapped_column(Unicode(20))

    potency: Mapped[Decimal | None] = mapped_column(Numeric(18, 8))
    potency_uom: Mapped[str | None] = mapped_column(Unicode(8))
    active_percent: Mapped[Decimal | None] = mapped_column(Numeric(16, 8))
    overage_percent: Mapped[Decimal | None] = mapped_column(Numeric(16, 8))
    daily_dose_percent: Mapped[Decimal | None] = mapped_column(Numeric(16, 8))
    mg_per_capsule_percent: Mapped[Decimal | None] = mapped_column(Numeric(16, 8))
    mg_per_capsule_with_overage: Mapped[Decimal | None] = mapped_column(Numeric(16, 8))
    formula_percent: Mapped[Decimal | None] = mapped_column(Numeric(16, 8))
    cost_percent: Mapped[Decimal | None] = mapped_column(Numeric(16, 8))
    is_total_cost_percent: Mapped[bool] = mapped_column(Boolean, default=False)
    is_total_formula_percent: Mapped[bool] = mapped_column(Boolean, default=False)
    entered_by: Mapped[str | None] = mapped_column(Unicode(30))
    notes: Mapped[str | None] = mapped_column(NVARCHAR_MAX)

    header: Mapped[FormulaHeader] = relationship(back_populates="lines")
    review_issues: Mapped[list[FormulaReviewIssue]] = relationship(back_populates="line")

    @property
    def potency_unit(self) -> str:
        return self.potency_uom or ""

    @property
    def cost_snapshot(self) -> Decimal:
        return self.selected_unit_cost or Decimal("0")


class FormulaReviewIssue(AuditColumnsMixin, Base):
    """Auditable migration or data-quality issue requiring a user decision."""

    __tablename__ = "formula_review_issue"
    __table_args__ = {"schema": FORMULA_SCHEMA}

    id: Mapped[int] = mapped_column("formula_review_issue_id", primary_key=True)
    formula_id: Mapped[int] = mapped_column(
        ForeignKey(f"{FORMULA_SCHEMA}.formula.id", ondelete="CASCADE")
    )
    header_id: Mapped[int | None] = mapped_column(
        "formula_header_id",
        ForeignKey(f"{FORMULA_SCHEMA}.formula_header.id"),
    )
    line_id: Mapped[int | None] = mapped_column(
        "formula_line_id",
        ForeignKey(f"{FORMULA_SCHEMA}.formula_line.id"),
    )
    issue_code: Mapped[str] = mapped_column(Unicode(50))
    severity: Mapped[str] = mapped_column(Unicode(20), default="WARNING")
    review_status: Mapped[str] = mapped_column(Unicode(20), default="OPEN")
    issue_detail: Mapped[str | None] = mapped_column(Unicode(1000))
    resolution_note: Mapped[str | None] = mapped_column(Unicode(1000))
    reviewed_by: Mapped[str | None] = mapped_column(Unicode(100))
    reviewed_dt: Mapped[datetime | None] = mapped_column(AUDIT_DATETIME)

    formula: Mapped[Formula] = relationship(back_populates="review_issues")
    header: Mapped[FormulaHeader | None] = relationship(back_populates="review_issues")
    line: Mapped[FormulaLine | None] = relationship(back_populates="review_issues")


class FormulaWtAndCost(Base):
    """Dated calculation result; source key has no formula revision or status."""

    __tablename__ = "formula_wt_and_cost"
    __table_args__ = {"schema": FORMULA_SCHEMA}

    id: Mapped[int] = mapped_column(primary_key=True)
    run_julian_date: Mapped[int] = mapped_column(BigInteger)
    branch_code: Mapped[str] = mapped_column(Unicode(12))
    parent_item_number: Mapped[str] = mapped_column(Unicode(64))
    blend_item_number: Mapped[str] = mapped_column(Unicode(64))
    total_daily_dose_mg_weight: Mapped[Decimal | None] = mapped_column(Numeric(20, 8))
    total_mg_per_unit_weight: Mapped[Decimal | None] = mapped_column(Numeric(20, 8))
    total_mg_per_unit_weight_with_mo: Mapped[Decimal | None] = mapped_column(Numeric(20, 8))
    total_formula: Mapped[Decimal | None] = mapped_column(Numeric(20, 8))
    raw_materials: Mapped[int | None]
    formula_cost: Mapped[Decimal | None] = mapped_column(Numeric(20, 8))
    last_active_julian_date: Mapped[int | None] = mapped_column(BigInteger)


@event.listens_for(Session, "before_flush")
def touch_formula_header_for_line_changes(
    session: Session, _flush_context: object, _instances: object
) -> None:
    """Roll line mutations up to the owning header's audit metadata."""

    actor = str(session.info.get("audit_user") or "SYSTEM")[:100]
    changed_objects = session.new.union(session.dirty).union(session.deleted)
    touched_header_ids: set[int] = set()

    for changed_object in changed_objects:
        if not isinstance(changed_object, FormulaLine):
            continue
        if changed_object in session.dirty and not session.is_modified(
            changed_object, include_collections=False
        ):
            continue

        formula_header = changed_object.header
        if formula_header is None and changed_object.header_id is not None:
            formula_header = session.get(FormulaHeader, changed_object.header_id)
        if formula_header is None:
            continue

        header_identity = (
            formula_header.id if formula_header.id is not None else id(formula_header)
        )
        if header_identity in touched_header_ids:
            continue
        touched_header_ids.add(header_identity)
        changed_at = utc_now()
        formula_header.updated_by = actor
        formula_header.updated_dt = changed_at
        formula_header.formula.updated_by = actor
        formula_header.formula.updated_dt = changed_at
