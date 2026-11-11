from typing import Annotated, Literal

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import inspect
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from api.database import get_session
from api.grid import grid_filters
from api.legacy import LEGACY_READ_ONLY_DETAIL, uses_legacy_schema
from api.modules.specifications.repository import (
    create_item_spec,
    get_item_allergen,
    get_item_country,
    get_item_property,
    get_item_regulatory_req,
    get_item_solvent,
    get_item_spec,
    get_item_vendor_part,
    list_item_allergens,
    list_item_countries,
    list_item_properties,
    list_item_regulatory_reqs,
    list_item_solvents,
    list_item_specs,
    list_item_vendor_parts,
    update_item_spec,
)
from api.modules.specifications.schemas import (
    SpecificationCreate,
    SpecificationRead,
    SpecificationUpdate,
)

router = APIRouter(prefix="/specifications", tags=["specifications"])
SessionDep = Annotated[Session, Depends(get_session)]
CHILD_READERS = {
    "regulatory": (get_item_regulatory_req, list_item_regulatory_reqs),
    "allergens": (get_item_allergen, list_item_allergens),
    "countries": (get_item_country, list_item_countries),
    "properties": (get_item_property, list_item_properties),
    "solvents": (get_item_solvent, list_item_solvents),
    "vendor-parts": (get_item_vendor_part, list_item_vendor_parts),
}


def _child_reader(item_spec_id: int, kind: str, session: Session):
    if uses_legacy_schema(session):
        raise HTTPException(status_code=503, detail=LEGACY_READ_ONLY_DETAIL)
    if get_item_spec(session, item_spec_id) is None:
        raise HTTPException(status_code=404, detail="Specification not found")
    readers = CHILD_READERS.get(kind)
    if readers is None:
        raise HTTPException(status_code=404, detail="Unknown specification table")
    return readers


def _row_values(row: object) -> dict[str, object]:
    return {column.key: getattr(row, column.key) for column in inspect(row).mapper.columns}


@router.get("", response_model=list[SpecificationRead])
def get_specifications(
    session: SessionDep,
    filters: Annotated[dict[str, str], Depends(grid_filters)],
    material_id: int,
    limit: Annotated[int, Query(ge=1, le=1000)] = 100,
    offset: Annotated[int, Query(ge=0)] = 0,
    sort_by: str | None = None,
    sort_dir: Literal["asc", "desc"] = "asc",
) -> list[SpecificationRead]:
    if uses_legacy_schema(session):
        raise HTTPException(status_code=503, detail=LEGACY_READ_ONLY_DETAIL)
    try:
        rows = list_item_specs(session, material_id=material_id, limit=limit, offset=offset,
                               filters=filters, sort_by=sort_by, sort_dir=sort_dir)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return [
        SpecificationRead.model_validate(specification)
        for specification in rows
    ]


@router.get("/{item_spec_id}", response_model=SpecificationRead)
def get_specification(item_spec_id: int, session: SessionDep) -> SpecificationRead:
    if uses_legacy_schema(session):
        raise HTTPException(status_code=503, detail=LEGACY_READ_ONLY_DETAIL)
    specification = get_item_spec(session, item_spec_id)
    if specification is None:
        raise HTTPException(status_code=404, detail="Specification not found")
    return SpecificationRead.model_validate(specification)


@router.get("/{item_spec_id}/record")
def get_specification_record(item_spec_id: int, session: SessionDep) -> dict[str, object]:
    if uses_legacy_schema(session):
        raise HTTPException(status_code=503, detail=LEGACY_READ_ONLY_DETAIL)
    specification = get_item_spec(session, item_spec_id)
    if specification is None:
        raise HTTPException(status_code=404, detail="Specification not found")
    return _row_values(specification)


@router.get("/{item_spec_id}/children/{kind}")
def get_specification_children(
    item_spec_id: int,
    kind: str,
    session: SessionDep,
    filters: Annotated[dict[str, str], Depends(grid_filters)],
    limit: Annotated[int, Query(ge=1, le=1000)] = 100,
    offset: Annotated[int, Query(ge=0)] = 0,
    sort_by: str | None = None,
    sort_dir: Literal["asc", "desc"] = "asc",
) -> list[dict[str, object]]:
    _, list_rows = _child_reader(item_spec_id, kind, session)
    try:
        rows = list_rows(session, item_spec_id, limit=limit, offset=offset,
                         filters=filters, sort_by=sort_by, sort_dir=sort_dir)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return [
        _row_values(row)
        for row in rows
    ]


@router.get("/{item_spec_id}/children/{kind}/{row_id}")
def get_specification_child(
    item_spec_id: int, kind: str, row_id: int, session: SessionDep
) -> dict[str, object]:
    get_row, _ = _child_reader(item_spec_id, kind, session)
    row = get_row(session, row_id)
    if row is None or row.item_spec_id != item_spec_id:
        raise HTTPException(status_code=404, detail="Specification row not found")
    return _row_values(row)


@router.post("", status_code=status.HTTP_201_CREATED)
def create_specification(payload: SpecificationCreate, session: SessionDep) -> dict[str, int | str]:
    if uses_legacy_schema(session):
        raise HTTPException(status_code=503, detail=LEGACY_READ_ONLY_DETAIL)
    try:
        specification = create_item_spec(session, payload)
        session.commit()
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except IntegrityError as exc:
        session.rollback()
        raise HTTPException(
            status_code=409, detail="Specification revision already exists for this material"
        ) from exc
    return {"id": specification.id, "status": "created"}


@router.patch("/{item_spec_id}", response_model=SpecificationRead)
def update_specification(
    item_spec_id: int, payload: SpecificationUpdate, session: SessionDep
) -> SpecificationRead:
    if uses_legacy_schema(session):
        raise HTTPException(status_code=503, detail=LEGACY_READ_ONLY_DETAIL)
    specification = get_item_spec(session, item_spec_id)
    if specification is None:
        raise HTTPException(status_code=404, detail="Specification not found")
    try:
        update_item_spec(session, specification, changes=payload.model_dump(exclude_unset=True))
    except ValueError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    session.commit()
    return SpecificationRead.model_validate(specification)
