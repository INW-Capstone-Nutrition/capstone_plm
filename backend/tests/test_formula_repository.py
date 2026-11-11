import os
from decimal import Decimal

import pytest

os.environ["PLM_DATABASE_URL"] = "sqlite://"
os.environ["PLM_SEED_DEMO_DATA"] = "false"
os.environ["PLM_CHECK_DATABASE_ON_STARTUP"] = "false"

from api.database import Base, SessionLocal, engine  # noqa: E402
from api.main import app  # noqa: E402, F401 - register all model tables
from api.modules.formulas.models import FormulaHeader, FormulaLine  # noqa: E402
from api.modules.formulas.repository import (  # noqa: E402
    create_formula,
    create_header,
    create_line,
    deactivate_formula,
    deactivate_header,
    deactivate_line,
    get_formula,
    get_header,
    get_line,
    list_formulas,
    list_headers,
    list_lines,
    update_formula,
    update_header,
    update_line,
)
from api.modules.formulas.schemas import FormulaCreate  # noqa: E402


def test_formula_repository_lifecycle_retains_revision_and_lines() -> None:
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)

    with SessionLocal() as session:
        formula = create_formula(session, FormulaCreate(name="  Repository test  "))
        session.commit()
        formula_id = formula.id
        header_id = formula.headers[0].id
        session.add(FormulaLine(header_id=header_id, line_number=1, material_item_number="RM-1"))
        session.commit()

        loaded = get_formula(session, formula_id)
        assert loaded is not None
        assert loaded.headers[0].lines[0].material_item_number == "RM-1"
        assert loaded.headers[0].formula_name == "Repository test"

        session.info["audit_user"] = "repository.test"
        update_formula(session, loaded, is_active=True)
        session.commit()
        assert loaded.is_active is True
        assert loaded.updated_by == "repository.test"

        deactivate_formula(session, loaded)
        session.commit()
        session.expire_all()

        assert list_formulas(session) == []
        retained = get_formula(session, formula_id)
        assert retained is not None
        assert retained.is_voided is True
        assert retained.is_active is False
        assert retained.is_production is False
        assert retained.headers[0].workflow_status == "Inactive"
        assert session.get(FormulaHeader, header_id) is not None
        assert session.get(FormulaLine, retained.headers[0].lines[0].id) is not None


@pytest.mark.parametrize("deactivate_from", ["header", "line"])
def test_child_deactivation_voids_formula_without_deleting_snapshots(
    deactivate_from: str,
) -> None:
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)

    with SessionLocal() as session:
        formula = create_formula(session, FormulaCreate(name="Snapshot test"))
        first = formula.headers[0]
        update_header(session, first, changes={"notes": "Original revision"})
        line = create_line(
            session, first, FormulaLine(line_number=1, material_item_number="RM-1")
        )
        update_line(session, line, changes={"notes": "Keep this line"})
        second = create_header(
            session,
            formula,
            FormulaHeader(
                sequence=2,
                revision_number=Decimal("0.02"),
                formula_name="Snapshot test",
            ),
        )
        session.commit()

        assert [header.id for header in list_headers(session, formula.id)] == [first.id, second.id]
        assert get_header(session, first.id) is first
        assert [item.id for item in list_lines(session, first.id)] == [line.id]
        assert get_line(session, line.id) is line
        with pytest.raises(ValueError, match="Historical"):
            update_header(session, first, changes={"notes": "Mutated history"})

        if deactivate_from == "header":
            deactivate_header(session, first)
        else:
            deactivate_line(session, line)
        session.commit()
        session.expire_all()

        persisted = get_formula(session, formula.id)
        assert persisted is not None
        assert persisted.is_voided is True
        assert [(item.sequence, item.workflow_status) for item in persisted.headers] == [
            (1, "Development"),
            (2, "Inactive"),
        ]
        assert get_line(session, line.id) is not None
        assert get_line(session, line.id).notes == "Keep this line"


def test_formula_list_filters_before_paging_and_keeps_lines_for_detail() -> None:
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)

    with SessionLocal() as session:
        first = create_formula(session, FormulaCreate(name="First", branch_code="10"))
        create_line(
            session,
            first.headers[0],
            FormulaLine(line_number=1, material_item_number="RM-1"),
        )
        second = create_formula(session, FormulaCreate(name="Second", branch_code="10"))
        update_header(session, second.headers[0], changes={"workflow_status": "Review"})
        create_formula(session, FormulaCreate(name="Third", branch_code="10"))
        session.commit()

        assert [item.name for item in list_formulas(session, limit=1, offset=0)] == ["Third"]
        assert [item.name for item in list_formulas(session, limit=1, offset=1)] == ["Second"]
        assert [item.name for item in list_formulas(session, status="Review", limit=1)] == [
            "Second"
        ]
        assert [item.name for item in list_formulas(session, status="Development", limit=1)] == [
            "Third"
        ]
        summary = list_formulas(session, query="First")[0]
        assert summary.latest_revision.lines == []
        assert get_formula(session, first.id).headers[0].lines[0].material_item_number == "RM-1"
        assert [item.name for item in list_formulas(
            session, filters={"name": "ir", "branch_code": "10"}, limit=1
        )] == ["Third"]
        assert [item.name for item in list_formulas(
            session, sort_by="name", sort_dir="asc", limit=1
        )] == ["First"]
        assert list_formulas(session, filters={"name": "missing"}) == []
        assert list_formulas(session, filters={"name": "Third", "branch_code": "99"}) == []
        with pytest.raises(ValueError, match="Unknown sort column"):
            list_formulas(session, sort_by="not_a_column")
        assert [row.line_number for row in list_lines(
            session, first.headers[0].id, filters={"material_item_number": "RM-1"}
        )] == [1]
        assert [row.sequence for row in list_headers(
            session, first.id, filters={"formula_name": "first"}, sort_by="sequence"
        )] == [1]
