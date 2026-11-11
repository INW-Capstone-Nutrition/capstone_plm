from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from api.modules.admin.models import AppUser
from api.modules.formulas.models import Formula, FormulaHeader, FormulaLine
from api.modules.materials.models import Material


def seed_demo_data(session: Session) -> None:
    if session.scalar(select(func.count(Formula.id))):
        return

    materials = [
        Material(
            item_number="RM-10482",
            branch_code="10",
            description="Ascorbic Acid USP Fine Powder",
            category="Vitamin",
            base_uom="MG",
        ),
        Material(
            item_number="RM-10731",
            branch_code="10",
            description="Zinc Citrate Granular",
            category="Mineral",
            base_uom="MG",
        ),
        Material(
            item_number="RM-20318",
            branch_code="05",
            description="Microcrystalline Cellulose 102",
            category="Excipient",
            base_uom="MG",
        ),
    ]
    session.add_all(materials)
    session.flush()

    formula_data = [
        ("FG-24018", "Daily Defense Complex", "Active", "10", "BL-88214", "Wellwise", "Tablet"),
        ("FG-24032", "Magnesium PM", "Review", "10", "BL-88309", "Northstar", "Capsule"),
        ("FG-24041", "Citrus Hydration", "Development", "05", "BL-88411", "Vela Health", "Powder"),
        ("FG-23987", "Women’s Daily Multi", "Active", "10", "BL-87932", "Wellwise", "Tablet"),
        ("FG-24029", "Collagen Support", "Quote", "15", "BL-88290", "Lumina", "Capsule"),
    ]
    for index, (parent, name, workflow, branch, blend, customer, unit_type) in enumerate(
        formula_data, start=1
    ):
        formula = Formula(
            record_origin="PLM",
            is_active=workflow in {"Active", "Copy"},
            is_production=(
                workflow not in {"Development", "Review", "Quote"}
                and not parent.upper().replace(" ", "").startswith(("P-", "B-", "AG1"))
            ),
        )
        revision = FormulaHeader(
            sequence=3 if workflow == "Active" else 1,
            revision_number=Decimal("3.0" if workflow == "Active" else "0.01"),
            workflow_status=workflow,
            formula_name=name,
            branch_code=branch,
            parent_item_number=parent,
            blend_item_number=blend,
            customer_name=customer,
            unit_type=unit_type,
            category="Core Nutrition" if index < 4 else "Specialty",
            additional_information=f"Migrated formulation workspace for {name}.",
            notes="Demo data generated for the migration starter.",
        )
        if index <= 2:
            revision.lines = [
                FormulaLine(
                    line_number=10,
                    material_id=materials[0].id,
                    material_item_number=materials[0].item_number,
                    material_description=materials[0].description,
                    potency=Decimal("100"),
                    active_percent=Decimal("250"),
                    mg_per_capsule_percent=Decimal("250"),
                    selected_unit_cost=Decimal("0.0142"),
                ),
                FormulaLine(
                    line_number=20,
                    material_id=materials[1].id,
                    material_item_number=materials[1].item_number,
                    material_description=materials[1].description,
                    potency=Decimal("31"),
                    active_percent=Decimal("15"),
                    mg_per_capsule_percent=Decimal("48.3871"),
                    selected_unit_cost=Decimal("0.0318"),
                ),
            ]
        formula.headers = [revision]
        session.add(formula)

    session.add(
        AppUser(
            user_name="a.chen",
            display_name="test user",
            email="alex.chen@example.com",
            role="formulation_lead",
            branch_code="10",
        )
    )
    session.commit()
