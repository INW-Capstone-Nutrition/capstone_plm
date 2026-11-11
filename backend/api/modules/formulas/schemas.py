from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import TYPE_CHECKING

from pydantic import BaseModel, Field, field_validator

from api.contracts import ReadModel

if TYPE_CHECKING:
    from api.modules.formulas.models import Formula


class FormulaCreate(BaseModel):
    parent_item_number: str | None = Field(default=None, max_length=64)
    name: str = Field(min_length=2, max_length=160)
    description: str | None = None
    category: str | None = None
    branch_code: str | None = Field(default="10", max_length=12)
    blend_item_number: str | None = Field(default=None, max_length=64)
    customer_name: str | None = None
    unit_type: str | None = None
    notes: str | None = None


class FormulaUpdate(BaseModel):
    is_active: bool | None = None
    is_production: bool | None = None


class FormulaLineRead(ReadModel):
    id: int
    material_id: int | None
    item_spec_id: int | None
    line_number: int
    material_item_number: str
    material_branch_code: str | None
    material_description: str
    material_category: str | None
    selected_vendor_name: str | None
    potency: Decimal | None
    potency_unit: str
    active_percent: Decimal | None
    mg_per_capsule_percent: Decimal | None
    cost_snapshot: Decimal

    @field_validator("material_description", mode="before")
    @classmethod
    def empty_description_for_missing_value(cls, value: str | None) -> str:
        return value or ""


class FormulaReviewIssueRead(ReadModel):
    id: int
    formula_id: int
    header_id: int | None
    line_id: int | None
    issue_code: str
    severity: str
    review_status: str
    issue_detail: str | None
    resolution_note: str | None
    reviewed_by: str | None
    reviewed_dt: datetime | None
    created_by: str
    created_dt: datetime
    updated_by: str
    updated_dt: datetime


class RevisionRead(ReadModel):
    id: int
    sequence: int
    revision_number: Decimal
    legacy_duplicate_sequence: int | None
    revision_label: str
    workflow_status: str
    branch_code: str | None
    parent_item_number: str | None
    blend_item_number: str | None
    formula_name: str
    category: str | None
    customer_name: str | None
    unit_type: str | None
    notes: str | None
    version: int
    created_by: str
    created_dt: datetime
    updated_by: str
    updated_dt: datetime
    lines: list[FormulaLineRead] = []


class FormulaListItem(ReadModel):
    id: int
    parent_item_number: str
    name: str
    category: str | None
    latest_revision: RevisionRead


class FormulaDetail(ReadModel):
    id: int
    parent_item_number: str | None
    name: str
    description: str | None
    category: str | None
    record_origin: str
    is_voided: bool
    is_active: bool
    is_production: bool
    created_by: str
    created_dt: datetime
    updated_by: str
    updated_dt: datetime
    revisions: list[RevisionRead]
    review_issues: list[FormulaReviewIssueRead] = []


def formula_detail(formula: Formula) -> FormulaDetail:
    revisions = sorted(formula.headers, key=lambda revision: revision.sequence)
    latest = revisions[-1]
    return FormulaDetail(
        id=formula.id,
        parent_item_number=latest.parent_item_number,
        name=latest.formula_name,
        description=latest.additional_information,
        category=latest.category,
        record_origin=formula.record_origin,
        is_voided=formula.is_voided,
        is_active=formula.is_active,
        is_production=formula.is_production,
        created_by=formula.created_by,
        created_dt=formula.created_dt,
        updated_by=formula.updated_by,
        updated_dt=formula.updated_dt,
        revisions=[RevisionRead.model_validate(revision) for revision in revisions],
        review_issues=[
            FormulaReviewIssueRead.model_validate(issue) for issue in formula.review_issues
        ],
    )
