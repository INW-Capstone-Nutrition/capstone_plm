from typing import Annotated, Literal

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from api.database import get_session
from api.grid import grid_filters
from api.legacy import LEGACY_READ_ONLY_DETAIL, uses_legacy_schema
from api.modules.formulas.repository import (
    create_formula as save_formula,
)
from api.modules.formulas.repository import (
    deactivate_formula as void_formula,
)
from api.modules.formulas.repository import (
    get_formula as find_formula,
)
from api.modules.formulas.repository import (
    get_header,
    get_line,
    list_formulas,
    list_headers,
    list_lines,
)
from api.modules.formulas.repository import (
    update_formula as save_formula_changes,
)
from api.modules.formulas.schemas import (
    FormulaCreate,
    FormulaDetail,
    FormulaLineRead,
    FormulaListItem,
    FormulaUpdate,
    RevisionRead,
    formula_detail,
)

router = APIRouter(prefix="/formulas", tags=["formulas"])
SessionDep = Annotated[Session, Depends(get_session)]


@router.get("", response_model=list[FormulaListItem])
def get_formulas(
    session: SessionDep,
    filters: Annotated[dict[str, str], Depends(grid_filters)],
    query: str | None = None,
    workflow_status: str | None = None,
    branch_code: str | None = None,
    limit: Annotated[int, Query(ge=1, le=10000)] = 10000,
    offset: Annotated[int, Query(ge=0)] = 0,
    sort_by: str | None = None,
    sort_dir: Literal["asc", "desc"] = "asc",
) -> list[FormulaListItem]:
    try:
        return list_formulas(
            session, query=query, status=workflow_status, branch=branch_code, limit=limit,
            offset=offset, filters=filters, sort_by=sort_by, sort_dir=sort_dir,
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@router.get("/{formula_id}/headers", response_model=list[RevisionRead])
def get_headers(
    formula_id: int,
    session: SessionDep,
    filters: Annotated[dict[str, str], Depends(grid_filters)],
    limit: Annotated[int, Query(ge=1, le=10000)] = 100,
    offset: Annotated[int, Query(ge=0)] = 0,
    sort_by: str | None = None,
    sort_dir: Literal["asc", "desc"] = "asc",
) -> list[RevisionRead]:
    if uses_legacy_schema(session):
        raise HTTPException(status_code=503, detail=LEGACY_READ_ONLY_DETAIL)
    try:
        rows = list_headers(session, formula_id, limit=limit, offset=offset,
                            filters=filters, sort_by=sort_by, sort_dir=sort_dir)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return [
        RevisionRead.model_validate(
            {name: getattr(header, name) for name in RevisionRead.model_fields if name != "lines"}
        )
        for header in rows
    ]


@router.get("/{formula_id}/headers/{header_id}", response_model=RevisionRead)
def get_header_detail(formula_id: int, header_id: int, session: SessionDep) -> RevisionRead:
    if uses_legacy_schema(session):
        raise HTTPException(status_code=503, detail=LEGACY_READ_ONLY_DETAIL)
    header = get_header(session, header_id)
    if header is None or header.formula_id != formula_id:
        raise HTTPException(status_code=404, detail="Header not found")
    return RevisionRead.model_validate(
        {name: getattr(header, name) for name in RevisionRead.model_fields if name != "lines"}
    )


@router.get("/{formula_id}/headers/{header_id}/lines", response_model=list[FormulaLineRead])
def get_lines(
    formula_id: int,
    header_id: int,
    session: SessionDep,
    filters: Annotated[dict[str, str], Depends(grid_filters)],
    limit: Annotated[int, Query(ge=1, le=10000)] = 100,
    offset: Annotated[int, Query(ge=0)] = 0,
    sort_by: str | None = None,
    sort_dir: Literal["asc", "desc"] = "asc",
) -> list[FormulaLineRead]:
    if uses_legacy_schema(session):
        raise HTTPException(status_code=503, detail=LEGACY_READ_ONLY_DETAIL)
    header = get_header(session, header_id)
    if header is None or header.formula_id != formula_id:
        raise HTTPException(status_code=404, detail="Header not found")
    try:
        rows = list_lines(session, header_id, limit=limit, offset=offset,
                          filters=filters, sort_by=sort_by, sort_dir=sort_dir)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return [
        FormulaLineRead.model_validate(line)
        for line in rows
    ]


@router.get("/{formula_id}/headers/{header_id}/lines/{line_id}", response_model=FormulaLineRead)
def get_line_detail(
    formula_id: int, header_id: int, line_id: int, session: SessionDep
) -> FormulaLineRead:
    if uses_legacy_schema(session):
        raise HTTPException(status_code=503, detail=LEGACY_READ_ONLY_DETAIL)
    line = get_line(session, line_id)
    if line is None or line.header_id != header_id or line.header.formula_id != formula_id:
        raise HTTPException(status_code=404, detail="Line not found")
    return FormulaLineRead.model_validate(line)


@router.get("/{formula_id}", response_model=FormulaDetail)
def get_formula(formula_id: int, session: SessionDep) -> FormulaDetail:
    formula = find_formula(session, formula_id)
    if not formula:
        raise HTTPException(status_code=404, detail="Formula not found")
    return formula_detail(formula)


@router.post("", response_model=FormulaDetail, status_code=status.HTTP_201_CREATED)
def create_formula(payload: FormulaCreate, session: SessionDep) -> FormulaDetail:
    if uses_legacy_schema(session):
        raise HTTPException(status_code=503, detail=LEGACY_READ_ONLY_DETAIL)
    try:
        formula = save_formula(session, payload)
        session.commit()
    except IntegrityError as exc:
        session.rollback()
        raise HTTPException(status_code=409, detail="Formula business key already exists") from exc
    return formula_detail(formula)


@router.patch("/{formula_id}", response_model=FormulaDetail)
def update_formula(
    formula_id: int, payload: FormulaUpdate, session: SessionDep
) -> FormulaDetail:
    if uses_legacy_schema(session):
        raise HTTPException(status_code=503, detail=LEGACY_READ_ONLY_DETAIL)
    formula = find_formula(session, formula_id)
    if formula is None:
        raise HTTPException(status_code=404, detail="Formula not found")
    try:
        save_formula_changes(session, formula, **payload.model_dump(exclude_unset=True))
    except ValueError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    session.commit()
    return formula_detail(formula)


@router.delete("/{formula_id}", response_model=FormulaDetail)
def deactivate_formula(formula_id: int, session: SessionDep) -> FormulaDetail:
    if uses_legacy_schema(session):
        raise HTTPException(status_code=503, detail=LEGACY_READ_ONLY_DETAIL)
    formula = find_formula(session, formula_id)
    if formula is None:
        raise HTTPException(status_code=404, detail="Formula not found")
    void_formula(session, formula)
    session.commit()
    return formula_detail(formula)
