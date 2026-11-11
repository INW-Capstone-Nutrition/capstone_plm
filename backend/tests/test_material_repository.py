import os

import pytest

os.environ["PLM_DATABASE_URL"] = "sqlite://"
os.environ["PLM_SEED_DEMO_DATA"] = "false"
os.environ["PLM_CHECK_DATABASE_ON_STARTUP"] = "false"

from api.database import Base, SessionLocal, engine  # noqa: E402
from api.main import app  # noqa: E402, F401 - register all model tables
from api.modules.materials.models import FormulationAssistant, ItemJdeOriginal  # noqa: E402
from api.modules.materials.repository import (  # noqa: E402
    create_material,
    deactivate_material,
    get_material,
    list_materials,
    update_material,
)
from api.modules.materials.schemas import MaterialCreate, MaterialUpdate  # noqa: E402


def test_material_repository_updates_identity_without_touching_snapshots() -> None:
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)

    with SessionLocal() as session:
        material = create_material(
            session,
            MaterialCreate(branch_code=" 10 ", item_number=" RM-1 ", description=" Original "),
        )
        session.add_all(
            [
                FormulationAssistant(source_table="Formulation_Assistant", material_id=material.id),
                ItemJdeOriginal(
                    material_id=material.id,
                    source_branch_code="10",
                    source_item_number="RM-1",
                    source_julian_date=126001,
                ),
            ]
        )
        session.commit()

        assert material.branch_code == "10"
        assert material.item_number == "RM-1"
        assert [item.id for item in list_materials(session, branch="10")] == [material.id]
        assert get_material(session, material.id) is material

        session.info["audit_user"] = "material.editor"
        update_material(
            session,
            material,
            MaterialUpdate(description="Updated", category="Vitamin"),
        )
        session.commit()
        session.expire_all()

        persisted = get_material(session, material.id)
        assert persisted is not None
        assert persisted.description == "Updated"
        assert persisted.category == "Vitamin"
        assert persisted.updated_by == "material.editor"
        assert session.query(FormulationAssistant).one().material_id == material.id
        assert session.query(ItemJdeOriginal).one().material_id == material.id

        deactivate_material(session, persisted)
        session.commit()
        session.expire_all()

        assert list_materials(session, branch="10") == []
        inactive = get_material(session, material.id)
        assert inactive is not None
        assert inactive.is_active is False
        assert session.query(FormulationAssistant).one().material_id == material.id
        assert session.query(ItemJdeOriginal).one().material_id == material.id
        with pytest.raises(ValueError, match="inactive"):
            update_material(session, inactive, MaterialUpdate(description="Must not change"))


def test_material_list_can_reach_subsequent_pages() -> None:
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)

    with SessionLocal() as session:
        for item_number in ("RM-3", "RM-1", "RM-2"):
            create_material(
                session,
                MaterialCreate(item_number=item_number, description=item_number),
            )
        session.commit()

        assert [item.item_number for item in list_materials(session, limit=2)] == [
            "RM-1",
            "RM-2",
        ]
        assert [item.item_number for item in list_materials(session, limit=2, offset=2)] == [
            "RM-3"
        ]
        assert [item.item_number for item in list_materials(
            session, filters={"item_number": "m-2", "branch_code": "10"}, limit=1
        )] == ["RM-2"]
        assert [item.item_number for item in list_materials(
            session, sort_by="item_number", sort_dir="desc", limit=1
        )] == ["RM-3"]
        assert len(list_materials(session, filters={"is_active": "Yes"})) == 3
        assert list_materials(session, filters={"is_active": "No"}) == []
        assert list_materials(session, filters={"item_number": "%"}) == []
