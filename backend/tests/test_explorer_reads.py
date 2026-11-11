import os
from decimal import Decimal

os.environ["PLM_DATABASE_URL"] = "sqlite://"
os.environ["PLM_SEED_DEMO_DATA"] = "false"
os.environ["PLM_CHECK_DATABASE_ON_STARTUP"] = "false"

from api.database import Base, SessionLocal, engine  # noqa: E402
from api.main import app  # noqa: E402, F401 - register all model tables
from api.modules.formulas.models import Formula, FormulaHeader, FormulaLine  # noqa: E402
from api.modules.formulas.router import (  # noqa: E402
    get_header_detail,
    get_headers,
    get_line_detail,
    get_lines,
)
from api.modules.materials.models import (  # noqa: E402
    FormulaItemCost,
    FormulationAssistant,
    ItemJdeOriginal,
    Material,
)
from api.modules.materials.router import (  # noqa: E402
    get_material,
    get_material_snapshot,
    get_material_snapshots,
    lookup_material,
)
from api.modules.specifications.models import ItemAllergen, ItemSpec  # noqa: E402
from api.modules.specifications.router import (  # noqa: E402
    get_specification,
    get_specification_child,
    get_specification_children,
    get_specification_record,
    get_specifications,
)


def test_explorer_get_and_list_navigation() -> None:
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)
    with SessionLocal() as session:
        material = Material(branch_code="10", item_number="RM-1", description="Ingredient")
        formula = Formula(
            headers=[
                FormulaHeader(
                    sequence=1,
                    revision_number=Decimal("0.01"),
                    formula_name="Explorer formula",
                    branch_code="10",
                    lines=[FormulaLine(line_number=1, material_item_number="RM-1")],
                )
            ]
        )
        session.add_all([material, formula])
        session.flush()
        spec = ItemSpec(material_id=material.id, revision=1)
        session.add(spec)
        session.flush()
        allergen = ItemAllergen(item_spec_id=spec.id, allergen_name="Soy")
        assistant = FormulationAssistant(
            source_table="Formulation_Assistant", material_id=material.id
        )
        jde = ItemJdeOriginal(
            material_id=material.id,
            source_branch_code="10",
            source_item_number="RM-1",
            source_julian_date=126001,
        )
        cost = FormulaItemCost(item_number="RM-1", run_julian_date=126001)
        session.add_all([allergen, assistant, jde, cost])
        session.commit()
        formula_id, header_id, line_id = (
            formula.id,
            formula.headers[0].id,
            formula.headers[0].lines[0].id,
        )
        material_id, spec_id, allergen_id = material.id, spec.id, allergen.id
        snapshot_ids = {"assistant": assistant.id, "jde-original": jde.id, "item-cost": cost.id}

    with SessionLocal() as session:
        assert (
            get_headers(formula_id, session, filters={}, limit=50, offset=0)[0].id == header_id
        )
        assert get_header_detail(formula_id, header_id, session).id == header_id
        assert (
            get_lines(formula_id, header_id, session, filters={}, limit=50, offset=0)[0].id
            == line_id
        )
        assert get_line_detail(formula_id, header_id, line_id, session).id == line_id
        assert lookup_material("10", "RM-1", session).id == material_id
        assert get_material(material_id, session).id == material_id
        for kind, snapshot_id in snapshot_ids.items():
            assert (
                get_material_snapshots(
                    material_id, kind, session, filters={}, limit=50, offset=0
                )[0]["id"]
                == snapshot_id
            )
            assert (
                get_material_snapshot(material_id, kind, snapshot_id, session)["id"] == snapshot_id
            )
        assert (
            get_specifications(
                session, filters={}, material_id=material_id, limit=50, offset=0
            )[0].id == spec_id
        )
        assert get_specification(spec_id, session).id == spec_id
        assert get_specification_record(spec_id, session)["material_id"] == material_id
        assert (
            get_specification_children(
                spec_id, "allergens", session, filters={}, limit=50, offset=0
            )[0]["id"]
            == allergen_id
        )
        assert (
            get_specification_child(spec_id, "allergens", allergen_id, session)["id"] == allergen_id
        )
        assert get_material_snapshots(
            material_id, "assistant", session, filters={"source_table": "assistant"},
            sort_by="source_table", limit=50, offset=0,
        )[0]["id"] == snapshot_ids["assistant"]
        assert get_specification_children(
            spec_id, "allergens", session, filters={"allergen_name": "soy"},
            sort_by="allergen_name", limit=50, offset=0,
        )[0]["id"] == allergen_id
