from typing import Annotated, Literal

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import inspect
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from api.database import get_session
from api.grid import grid_filters
from api.legacy import LEGACY_READ_ONLY_DETAIL, uses_legacy_schema
from api.modules.materials.models import (
    FormulaItemCost,
    FormulationAssistant,
    ItemJdeOriginal,
)
from api.modules.materials.repository import (
    create_material as save_material,
)
from api.modules.materials.repository import (
    deactivate_material as archive_material,
)
from api.modules.materials.repository import (
    get_material as find_material,
)
from api.modules.materials.repository import (
    get_material_by_key,
    list_formula_item_costs,
    list_formulation_assistants,
    list_item_jde_original,
    list_materials,
)
from api.modules.materials.repository import (
    update_material as save_material_changes,
)
from api.modules.materials.schemas import MaterialCreate, MaterialRead, MaterialUpdate

router = APIRouter(prefix="/materials", tags=["materials"])
SessionDep = Annotated[Session, Depends(get_session)]
SNAPSHOTS = {
    "assistant": (FormulationAssistant, list_formulation_assistants),
    "jde-original": (ItemJdeOriginal, list_item_jde_original),
    "item-cost": (FormulaItemCost, list_formula_item_costs),
}


def _snapshot_values(row: object) -> dict[str, object]:
    return {column.key: getattr(row, column.key) for column in inspect(row).mapper.columns}


def _snapshot_context(material_id: int, kind: str, session: Session):
    if uses_legacy_schema(session):
        raise HTTPException(status_code=503, detail=LEGACY_READ_ONLY_DETAIL)
    material = find_material(session, material_id)
    if material is None:
        raise HTTPException(status_code=404, detail="Material not found")
    snapshot = SNAPSHOTS.get(kind)
    if snapshot is None:
        raise HTTPException(status_code=404, detail="Unknown material table")
    return material, snapshot


@router.get("", response_model=list[MaterialRead])
def get_materials(
    session: SessionDep,
    filters: Annotated[dict[str, str], Depends(grid_filters)],
    query: str | None = None,
    branch_code: str | None = None,
    limit: Annotated[int, Query(ge=1, le=500)] = 100,
    offset: Annotated[int, Query(ge=0)] = 0,
    sort_by: str | None = None,
    sort_dir: Literal["asc", "desc"] = "asc",
) -> list[MaterialRead]:
    try:
        return list_materials(session, query=query, branch=branch_code, limit=limit,
                              offset=offset, filters=filters, sort_by=sort_by, sort_dir=sort_dir)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@router.get("/{material_id}", response_model=MaterialRead)
def get_material(material_id: int, session: SessionDep) -> MaterialRead:
    material = find_material(session, material_id)
    if material is None:
        raise HTTPException(status_code=404, detail="Material not found")
    return MaterialRead.model_validate(material)


@router.get("/lookup/by-key", response_model=MaterialRead)
def lookup_material(branch_code: str, item_number: str, session: SessionDep) -> MaterialRead:
    if uses_legacy_schema(session):
        raise HTTPException(status_code=503, detail=LEGACY_READ_ONLY_DETAIL)
    material = get_material_by_key(session, branch_code.strip(), item_number.strip())
    if material is None:
        raise HTTPException(status_code=404, detail="Material not found")
    return MaterialRead.model_validate(material)


@router.get("/{material_id}/snapshots/{kind}")
def get_material_snapshots(
    material_id: int,
    kind: str,
    session: SessionDep,
    filters: Annotated[dict[str, str], Depends(grid_filters)],
    limit: Annotated[int, Query(ge=1, le=1000)] = 100,
    offset: Annotated[int, Query(ge=0)] = 0,
    sort_by: str | None = None,
    sort_dir: Literal["asc", "desc"] = "asc",
) -> list[dict[str, object]]:
    material, (_, list_rows) = _snapshot_context(material_id, kind, session)
    try:
        rows = list_rows(session, material, limit=limit, offset=offset,
                         filters=filters, sort_by=sort_by, sort_dir=sort_dir)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return [_snapshot_values(row) for row in rows]


@router.get("/{material_id}/snapshots/{kind}/{row_id}")
def get_material_snapshot(
    material_id: int, kind: str, row_id: int, session: SessionDep
) -> dict[str, object]:
    material, (model, _) = _snapshot_context(material_id, kind, session)
    row = session.get(model, row_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Snapshot row not found")
    if kind == "assistant":
        matches = (
            row.material_id == material.id
            or (row.branch_code == material.branch_code and row.item_number == material.item_number)
            or (
                row.ext_branch_code == material.branch_code
                and row.ext_item_number == material.item_number
            )
        )
    elif kind == "jde-original":
        matches = row.material_id == material.id or (
            row.source_branch_code == material.branch_code
            and row.source_item_number == material.item_number
        )
    else:
        matches = row.item_number == material.item_number
    if not matches:
        raise HTTPException(status_code=404, detail="Snapshot row not found")
    return _snapshot_values(row)


@router.post("", response_model=MaterialRead, status_code=status.HTTP_201_CREATED)
def create_material(payload: MaterialCreate, session: SessionDep) -> MaterialRead:
    if uses_legacy_schema(session):
        raise HTTPException(status_code=503, detail=LEGACY_READ_ONLY_DETAIL)
    try:
        material = save_material(session, payload)
        session.commit()
    except IntegrityError as exc:
        session.rollback()
        raise HTTPException(
            status_code=409, detail="Material already exists in this branch"
        ) from exc
    return MaterialRead.model_validate(material)


@router.patch("/{material_id}", response_model=MaterialRead)
def update_material(material_id: int, payload: MaterialUpdate, session: SessionDep) -> MaterialRead:
    if uses_legacy_schema(session):
        raise HTTPException(status_code=503, detail=LEGACY_READ_ONLY_DETAIL)
    material = find_material(session, material_id)
    if material is None:
        raise HTTPException(status_code=404, detail="Material not found")
    try:
        save_material_changes(session, material, payload)
    except ValueError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    session.commit()
    return MaterialRead.model_validate(material)


@router.delete("/{material_id}", response_model=MaterialRead)
def deactivate_material(material_id: int, session: SessionDep) -> MaterialRead:
    if uses_legacy_schema(session):
        raise HTTPException(status_code=503, detail=LEGACY_READ_ONLY_DETAIL)
    material = find_material(session, material_id)
    if material is None:
        raise HTTPException(status_code=404, detail="Material not found")
    archive_material(session, material)
    session.commit()
    return MaterialRead.model_validate(material)
