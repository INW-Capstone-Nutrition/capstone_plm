import os

import pytest

os.environ["PLM_DATABASE_URL"] = "sqlite://"
os.environ["PLM_SEED_DEMO_DATA"] = "false"
os.environ["PLM_CHECK_DATABASE_ON_STARTUP"] = "false"

from api.database import Base, SessionLocal, engine  # noqa: E402
from api.main import app  # noqa: E402, F401 - register all model tables
from api.modules.materials.repository import create_material, deactivate_material  # noqa: E402
from api.modules.materials.schemas import MaterialCreate  # noqa: E402
from api.modules.specifications.models import (  # noqa: E402
    ItemAllergen,
    ItemCountry,
    ItemProperty,
    ItemRegulatoryReq,
    ItemSolvent,
    ItemVendorPart,
)
from api.modules.specifications.repository import (  # noqa: E402
    create_item_allergen,
    create_item_country,
    create_item_property,
    create_item_regulatory_req,
    create_item_solvent,
    create_item_spec,
    create_item_vendor_part,
    get_item_spec,
    list_item_specs,
    update_item_allergen,
    update_item_country,
    update_item_property,
    update_item_regulatory_req,
    update_item_solvent,
    update_item_spec,
    update_item_vendor_part,
)
from api.modules.specifications.schemas import SpecificationCreate  # noqa: E402


def test_item_spec_revisions_are_paged_and_released_revision_is_immutable() -> None:
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)

    with SessionLocal() as session:
        material = create_material(
            session, MaterialCreate(item_number="RM-1", description="Material")
        )
        first = create_item_spec(
            session, SpecificationCreate(item_number="RM-1", revision=1)
        )
        session.info["audit_user"] = "spec.editor"
        second = create_item_spec(
            session, SpecificationCreate(item_number="RM-1", revision=2)
        )
        update_item_spec(session, second, changes={"appearance": "White powder"})
        session.commit()

        assert get_item_spec(session, first.id) is first
        first_page = list_item_specs(session, material_id=material.id, limit=1)
        second_page = list_item_specs(session, material_id=material.id, limit=1, offset=1)
        assert [item.revision for item in first_page] == [2]
        assert [
            item.revision for item in second_page
        ] == [1]
        assert second.appearance == "White powder"
        assert second.created_by == "spec.editor"
        assert second.modified_by == "spec.editor"
        assert [item.revision for item in list_item_specs(
            session, material_id=material.id, filters={"appearance": "white"}, limit=1
        )] == [2]
        assert [item.revision for item in list_item_specs(
            session, material_id=material.id, sort_by="revision", sort_dir="asc", limit=1
        )] == [1]

        first.is_released = True
        session.commit()
        with pytest.raises(ValueError, match="Released"):
            update_item_spec(session, first, changes={"appearance": "Changed"})

        deactivate_material(session, material)
        session.commit()
        with pytest.raises(LookupError, match="Active material"):
            create_item_spec(session, SpecificationCreate(item_number="RM-1", revision=3))


@pytest.mark.parametrize(
    ("model", "create", "update", "field"),
    [
        (ItemRegulatoryReq, create_item_regulatory_req, update_item_regulatory_req, "halal_status"),
        (ItemAllergen, create_item_allergen, update_item_allergen, "allergen_name"),
        (ItemCountry, create_item_country, update_item_country, "country_name"),
        (ItemProperty, create_item_property, update_item_property, "property_name"),
        (ItemSolvent, create_item_solvent, update_item_solvent, "solvent_name"),
        (ItemVendorPart, create_item_vendor_part, update_item_vendor_part, "vendor_name"),
    ],
)
def test_item_child_repositories_preserve_released_revision(
    model: type, create: object, update: object, field: str
) -> None:
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)

    with SessionLocal() as session:
        create_material(session, MaterialCreate(item_number="RM-1", description="Material"))
        specification = create_item_spec(session, SpecificationCreate(item_number="RM-1"))
        child = create(session, model(item_spec_id=specification.id))
        update(session, child, changes={field: "Original"})
        session.commit()

        assert getattr(session.get(model, child.id), field) == "Original"
        specification.is_released = True
        session.commit()
        with pytest.raises(ValueError, match="Released"):
            update(session, child, changes={field: "Changed"})
        assert getattr(session.get(model, child.id), field) == "Original"
