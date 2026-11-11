from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

from api.grid import apply_grid_controls
from api.modules.materials.models import Material
from api.modules.specifications.models import (
    ItemAllergen,
    ItemCountry,
    ItemProperty,
    ItemRegulatoryReq,
    ItemSolvent,
    ItemSpec,
    ItemVendorPart,
)
from api.modules.specifications.schemas import SpecificationCreate

# ItemSpec


def get_item_spec(session: Session, item_spec_id: int) -> ItemSpec | None:
    return session.get(ItemSpec, item_spec_id)


def list_item_specs(
    session: Session, *, material_id: int, limit: int = 100, offset: int = 0,
    filters: dict[str, str] | None = None, sort_by: str | None = None,
    sort_dir: str = "asc",
) -> list[ItemSpec]:
    return list(
        session.scalars(
            apply_grid_controls(
                select(ItemSpec).where(ItemSpec.material_id == material_id),
                {
                    "revision": ItemSpec.revision,
                    "review_status": ItemSpec.review_status,
                    "is_released": ItemSpec.is_released,
                    "appearance": ItemSpec.appearance,
                    "physical_form": ItemSpec.physical_form,
                },
                filters=filters, sort_by=sort_by, sort_dir=sort_dir,
                default_order=(ItemSpec.revision.desc(), ItemSpec.id.desc()),
            )
            .offset(offset)
            .limit(limit)
        )
    )


def create_item_spec(session: Session, payload: SpecificationCreate) -> ItemSpec:
    material = session.scalar(
        select(Material).where(
            Material.branch_code == payload.branch_code.strip(),
            Material.item_number == payload.item_number.strip(),
            Material.is_active == True,  # noqa: E712 - SQL Server needs "= 1"
        )
    )
    if material is None:
        raise LookupError("Active material not found")
    specification = ItemSpec(
        material_id=material.id,
        revision=payload.revision,
        review_status=payload.review_status,
        appearance=payload.appearance,
        color=payload.color,
        item_type=payload.item_type,
        physical_form=payload.physical_form,
        created_at=datetime.now(UTC),
        created_by=str(session.info.get("audit_user") or "SYSTEM")[:100],
    )
    session.add(specification)
    session.flush()
    return specification


def update_item_spec(
    session: Session, specification: ItemSpec, *, changes: dict[str, object]
) -> ItemSpec:
    _require_editable_spec(session, specification.id)
    protected = {"id", "material_id", "revision", "created_at", "created_by"}
    if (
        not changes
        or set(changes) & protected
        or set(changes) - set(ItemSpec.__table__.columns.keys())
    ):
        raise ValueError("Invalid specification changes")
    for name, value in changes.items():
        setattr(specification, name, value)
    specification.modified_at = datetime.now(UTC)
    specification.modified_by = str(session.info.get("audit_user") or "SYSTEM")[:100]
    session.flush()
    return specification


# ItemRegulatoryReq


def get_item_regulatory_req(session: Session, row_id: int) -> ItemRegulatoryReq | None:
    return session.get(ItemRegulatoryReq, row_id)


def list_item_regulatory_reqs(
    session: Session, item_spec_id: int, *, limit: int = 100, offset: int = 0,
    filters: dict[str, str] | None = None, sort_by: str | None = None,
    sort_dir: str = "asc",
) -> list[ItemRegulatoryReq]:
    return _list_children(session, ItemRegulatoryReq, item_spec_id, limit=limit, offset=offset,
                          filters=filters, sort_by=sort_by, sort_dir=sort_dir)


def create_item_regulatory_req(session: Session, row: ItemRegulatoryReq) -> ItemRegulatoryReq:
    return _create_child(session, row)


def update_item_regulatory_req(
    session: Session, row: ItemRegulatoryReq, *, changes: dict[str, object]
) -> ItemRegulatoryReq:
    return _update_child(session, row, changes)


# ItemAllergen


def get_item_allergen(session: Session, row_id: int) -> ItemAllergen | None:
    return session.get(ItemAllergen, row_id)


def list_item_allergens(
    session: Session, item_spec_id: int, *, limit: int = 100, offset: int = 0,
    filters: dict[str, str] | None = None, sort_by: str | None = None,
    sort_dir: str = "asc",
) -> list[ItemAllergen]:
    return _list_children(session, ItemAllergen, item_spec_id, limit=limit, offset=offset,
                          filters=filters, sort_by=sort_by, sort_dir=sort_dir)


def create_item_allergen(session: Session, row: ItemAllergen) -> ItemAllergen:
    return _create_child(session, row)


def update_item_allergen(
    session: Session, row: ItemAllergen, *, changes: dict[str, object]
) -> ItemAllergen:
    return _update_child(session, row, changes)


# ItemCountry


def get_item_country(session: Session, row_id: int) -> ItemCountry | None:
    return session.get(ItemCountry, row_id)


def list_item_countries(
    session: Session, item_spec_id: int, *, limit: int = 100, offset: int = 0,
    filters: dict[str, str] | None = None, sort_by: str | None = None,
    sort_dir: str = "asc",
) -> list[ItemCountry]:
    return _list_children(session, ItemCountry, item_spec_id, limit=limit, offset=offset,
                          filters=filters, sort_by=sort_by, sort_dir=sort_dir)


def create_item_country(session: Session, row: ItemCountry) -> ItemCountry:
    return _create_child(session, row)


def update_item_country(
    session: Session, row: ItemCountry, *, changes: dict[str, object]
) -> ItemCountry:
    return _update_child(session, row, changes)


# ItemProperty


def get_item_property(session: Session, row_id: int) -> ItemProperty | None:
    return session.get(ItemProperty, row_id)


def list_item_properties(
    session: Session, item_spec_id: int, *, limit: int = 100, offset: int = 0,
    filters: dict[str, str] | None = None, sort_by: str | None = None,
    sort_dir: str = "asc",
) -> list[ItemProperty]:
    return _list_children(session, ItemProperty, item_spec_id, limit=limit, offset=offset,
                          filters=filters, sort_by=sort_by, sort_dir=sort_dir)


def create_item_property(session: Session, row: ItemProperty) -> ItemProperty:
    return _create_child(session, row)


def update_item_property(
    session: Session, row: ItemProperty, *, changes: dict[str, object]
) -> ItemProperty:
    return _update_child(session, row, changes)


# ItemSolvent


def get_item_solvent(session: Session, row_id: int) -> ItemSolvent | None:
    return session.get(ItemSolvent, row_id)


def list_item_solvents(
    session: Session, item_spec_id: int, *, limit: int = 100, offset: int = 0,
    filters: dict[str, str] | None = None, sort_by: str | None = None,
    sort_dir: str = "asc",
) -> list[ItemSolvent]:
    return _list_children(session, ItemSolvent, item_spec_id, limit=limit, offset=offset,
                          filters=filters, sort_by=sort_by, sort_dir=sort_dir)


def create_item_solvent(session: Session, row: ItemSolvent) -> ItemSolvent:
    return _create_child(session, row)


def update_item_solvent(
    session: Session, row: ItemSolvent, *, changes: dict[str, object]
) -> ItemSolvent:
    return _update_child(session, row, changes)


# ItemVendorPart


def get_item_vendor_part(session: Session, row_id: int) -> ItemVendorPart | None:
    return session.get(ItemVendorPart, row_id)


def list_item_vendor_parts(
    session: Session, item_spec_id: int, *, limit: int = 100, offset: int = 0,
    filters: dict[str, str] | None = None, sort_by: str | None = None,
    sort_dir: str = "asc",
) -> list[ItemVendorPart]:
    return _list_children(session, ItemVendorPart, item_spec_id, limit=limit, offset=offset,
                          filters=filters, sort_by=sort_by, sort_dir=sort_dir)


def create_item_vendor_part(session: Session, row: ItemVendorPart) -> ItemVendorPart:
    return _create_child(session, row)


def update_item_vendor_part(
    session: Session, row: ItemVendorPart, *, changes: dict[str, object]
) -> ItemVendorPart:
    return _update_child(session, row, changes)


type ChildModel = (
    ItemRegulatoryReq
    | ItemAllergen
    | ItemCountry
    | ItemProperty
    | ItemSolvent
    | ItemVendorPart
)


def _require_editable_spec(session: Session, item_spec_id: int) -> None:
    specification = session.get(ItemSpec, item_spec_id)
    if specification is None:
        raise LookupError("Specification not found")
    material = session.get(Material, specification.material_id)
    if material is None or not material.is_active:
        raise ValueError("Cannot edit a specification for an inactive material")
    if specification.is_released:
        raise ValueError("Released specification revisions cannot be edited")


def _list_children[ChildRow: ChildModel](
    session: Session, model: type[ChildRow], item_spec_id: int, *, limit: int, offset: int,
    filters: dict[str, str] | None = None, sort_by: str | None = None,
    sort_dir: str = "asc",
) -> list[ChildRow]:
    return list(
        session.scalars(
            apply_grid_controls(
                select(model).where(model.item_spec_id == item_spec_id),
                {column.key: column for column in model.__table__.columns},
                filters=filters, sort_by=sort_by, sort_dir=sort_dir,
                default_order=(model.id,),
            )
            .offset(offset)
            .limit(limit)
        )
    )


def _create_child[ChildRow: ChildModel](session: Session, row: ChildRow) -> ChildRow:
    _require_editable_spec(session, row.item_spec_id)
    session.add(row)
    session.flush()
    return row


def _update_child[ChildRow: ChildModel](
    session: Session, row: ChildRow, changes: dict[str, object]
) -> ChildRow:
    _require_editable_spec(session, row.item_spec_id)
    protected = {"id", "item_spec_id"}
    if (
        not changes
        or set(changes) & protected
        or set(changes) - set(row.__table__.columns.keys())
    ):
        raise ValueError("Invalid child changes")
    for name, value in changes.items():
        setattr(row, name, value)
    session.flush()
    return row
