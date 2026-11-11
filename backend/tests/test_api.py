import os
from decimal import Decimal

os.environ["PLM_DATABASE_URL"] = "sqlite://"
os.environ["PLM_SEED_DEMO_DATA"] = "false"
os.environ["PLM_CHECK_DATABASE_ON_STARTUP"] = "false"

from fastapi.testclient import TestClient  # noqa: E402

from api.database import Base, SessionLocal, engine  # noqa: E402
from api.main import app  # noqa: E402
from api.modules.formulas.models import (  # noqa: E402
    Formula,
    FormulaHeader,
    FormulaLine,
    FormulaReviewIssue,
)
from api.modules.formulas.schemas import FormulaLineRead  # noqa: E402


def test_health() -> None:
    with TestClient(app) as client:
        response = client.get("/api/v1/health")

    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_formula_models_use_form_schema() -> None:
    assert Formula.__table__.schema == "form"
    assert FormulaHeader.__table__.schema == "form"
    assert FormulaLine.__table__.schema == "form"
    assert FormulaReviewIssue.__table__.schema == "form"

    formula_target = next(iter(FormulaHeader.__table__.foreign_keys)).target_fullname
    revision_target = next(
        foreign_key.target_fullname
        for foreign_key in FormulaLine.__table__.foreign_keys
        if foreign_key.parent.name == "formula_header_id"
    )
    assert formula_target == "form.formula.id"
    assert revision_target == "form.formula_header.id"

    for model in (Formula, FormulaHeader, FormulaLine):
        assert tuple(column.name for column in model.__table__.primary_key) == ("id",)


def test_formula_models_match_required_audit_and_lifecycle_metadata() -> None:
    audit_columns = {"created_by", "created_dt", "updated_by", "updated_dt"}
    for model in (Formula, FormulaHeader, FormulaReviewIssue):
        assert audit_columns <= set(model.__table__.columns.keys())
    assert audit_columns.isdisjoint(FormulaLine.__table__.columns.keys())

    assert {
        "formula_id",
        "formula_header_id",
        "formula_line_id",
        "issue_code",
        "severity",
        "review_status",
        "issue_detail",
        "resolution_note",
        "reviewed_by",
        "reviewed_dt",
    } <= set(FormulaReviewIssue.__table__.columns.keys())

    formula_columns = set(Formula.__table__.columns.keys())
    assert {"is_voided", "is_active", "is_production"} <= formula_columns
    assert "status" not in formula_columns
    assert {"voided_dt", "voided_by", "void_reason"}.isdisjoint(formula_columns)
    assert "formula_name" not in Formula.__table__.columns
    assert "formula_name" in FormulaHeader.__table__.columns

    revision_columns = set(FormulaHeader.__table__.columns.keys())
    assert {"approval_dt", "approved_by"}.isdisjoint(revision_columns)
    assert {
        "calculation_run_julian_date",
        "total_daily_dose_mg",
        "total_mg_per_unit",
        "total_mg_per_unit_with_overage",
        "total_formula_amount",
        "raw_material_count",
        "formula_cost",
        "last_active_julian_date",
    }.isdisjoint(revision_columns)
    assert {
        "legacy_duplicate_sequence",
        "size",
        "material_type",
        "category",
        "color",
        "dosage_per_unit",
        "serving_size",
        "daily_dose",
        "hobb_number",
        "raw_material_markup",
        "overage_percent",
        "empty_capsule_number",
        "solids",
        "weight",
        "carnuba_wax",
        "change_type",
        "change_number",
    } <= revision_columns

    line_columns = set(FormulaLine.__table__.columns.keys())
    assert {
        "material_description",
        "material_category",
        "trademark",
        "selected_vendor_name",
        "primary_uom",
        "cost_uom",
        "cost_run_julian_date",
    } <= line_columns
    assert not any(column.endswith("_snapshot") for column in line_columns)
    assert {
        "active_percent",
        "overage_percent",
        "daily_dose_percent",
        "mg_per_capsule_percent",
        "mg_per_capsule_with_overage",
        "formula_percent",
        "cost_percent",
        "is_total_cost_percent",
        "is_total_formula_percent",
    } <= line_columns

def test_create_and_read_formula() -> None:
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)
    payload = {
        "parent_item_number": "FG-TEST-01",
        "name": "Test Formula",
        "branch_code": "10",
        "blend_item_number": "BL-TEST-01",
        "unit_type": "Tablet",
    }

    with TestClient(app) as client:
        created = client.post("/api/v1/formulas", json=payload)
        listing = client.get("/api/v1/formulas")

    assert created.status_code == 201
    assert created.json()["revisions"][0]["workflow_status"] == "Development"
    assert created.json()["revisions"][0]["revision_number"] == "0.01000000"
    assert created.json()["is_active"] is False
    assert created.json()["is_production"] is False
    assert created.json()["created_by"] == "SYSTEM"
    assert listing.status_code == 200
    assert listing.json()[0]["parent_item_number"] == "FG-TEST-01"


def test_formula_decimal_precision_round_trip() -> None:
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)

    formula = Formula(
        headers=[
            FormulaHeader(
                sequence=1,
                revision_number=Decimal("0.12345678"),
                formula_name="Precision Test",
                size="00",
                raw_material_markup=Decimal("12.12345678"),
                lines=[
                    FormulaLine(
                        line_number=1,
                        material_item_number="RM-TEST-01",
                        selected_unit_cost=Decimal("1.12345678"),
                    )
                ],
            )
        ]
    )

    with SessionLocal() as session:
        session.add(formula)
        session.commit()
        session.expire_all()
        header = session.get(FormulaHeader, formula.headers[0].id)

        assert header is not None
        assert header.size == "00"
        assert header.revision_number == Decimal("0.12345678")
        assert header.raw_material_markup == Decimal("12.12345678")
        assert header.lines[0].selected_unit_cost == Decimal("1.12345678")
        assert FormulaLineRead.model_validate(header.lines[0]).material_description == ""


def test_formula_line_change_touches_header_audit() -> None:
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)

    line = FormulaLine(line_number=10, material_item_number="RM-TEST-01")
    formula = Formula(
        record_origin="PLM",
        headers=[
            FormulaHeader(
                sequence=1,
                revision_number=Decimal("0.01"),
                workflow_status="Development",
                formula_name="Audit Test",
                lines=[line],
            )
        ],
    )

    with SessionLocal() as session:
        session.add(formula)
        session.commit()
        session.info["audit_user"] = "line.editor"
        line.notes = "Changed line"
        session.commit()
        session.refresh(formula)

        assert formula.updated_by == "line.editor"
        assert formula.headers[0].updated_by == "line.editor"
