from __future__ import annotations

import zlib
from datetime import UTC, datetime
from decimal import Decimal

from sqlalchemy import or_, select, text
from sqlalchemy.orm import Session, selectinload

from api.grid import apply_grid_controls
from api.legacy import uses_legacy_schema
from api.modules.formulas.models import Formula, FormulaHeader, FormulaLine
from api.modules.formulas.schemas import (
    FormulaCreate,
    FormulaListItem,
    RevisionRead,
)

# Formula


def get_formula(session: Session, formula_id: int) -> Formula | None:
    return session.scalar(
        select(Formula)
        .where(Formula.id == formula_id)
        .options(
            selectinload(Formula.headers).selectinload(FormulaHeader.lines),
            selectinload(Formula.review_issues),
        )
    )


def list_formulas(
    session: Session,
    *,
    query: str | None = None,
    status: str | None = None,
    branch: str | None = None,
    limit: int = 10000,
    offset: int = 0,
    filters: dict[str, str] | None = None,
    sort_by: str | None = None,
    sort_dir: str = "asc",
) -> list[FormulaListItem]:
    if uses_legacy_schema(session):
        return _list_legacy_formulas(
            session, query=query, status=status, branch=branch, limit=limit, offset=offset,
            filters=filters, sort_by=sort_by, sort_dir=sort_dir,
        )
    latest_id = (
        select(FormulaHeader.id)
        .where(FormulaHeader.formula_id == Formula.id)
        .order_by(FormulaHeader.sequence.desc(), FormulaHeader.id.desc())
        .limit(1)
        .correlate(Formula)
        .scalar_subquery()
    )
    statement = (
        select(Formula, FormulaHeader)
        .join(FormulaHeader, FormulaHeader.id == latest_id)
        .where(Formula.is_voided == False)  # noqa: E712 - SQL Server needs "= 0"
    )
    if query:
        match = f"%{query.strip()}%"
        statement = statement.where(or_(
                FormulaHeader.formula_name.ilike(match),
                FormulaHeader.parent_item_number.ilike(match),
                FormulaHeader.blend_item_number.ilike(match),
            ))
    if status:
        statement = statement.where(FormulaHeader.workflow_status == status)
    if branch:
        statement = statement.where(FormulaHeader.branch_code == branch)
    statement = apply_grid_controls(
        statement,
        {
            "name": FormulaHeader.formula_name,
            "parent_item_number": FormulaHeader.parent_item_number,
            "branch_code": FormulaHeader.branch_code,
            "revision_label": FormulaHeader.revision_number,
            "workflow_status": FormulaHeader.workflow_status,
        },
        filters=filters, sort_by=sort_by, sort_dir=sort_dir,
        default_order=(Formula.updated_dt.desc(), Formula.id.desc()),
    )
    statement = statement.offset(offset).limit(limit)
    items: list[FormulaListItem] = []
    for formula, latest in session.execute(statement).all():
        items.append(
            FormulaListItem(
                id=formula.id,
                parent_item_number=latest.parent_item_number or "",
                name=latest.formula_name,
                category=latest.category,
                latest_revision=RevisionRead.model_validate(
                    {
                        name: getattr(latest, name)
                        for name in RevisionRead.model_fields
                        if name != "lines"
                    }
                ),
            )
        )
    return items


def create_formula(session: Session, payload: FormulaCreate) -> Formula:
    formula = Formula(
        record_origin="PLM",
        is_active=False,
        is_production=False,
        headers=[
            FormulaHeader(
                sequence=1,
                revision_number=Decimal("0.01"),
                workflow_status="Development",
                formula_name=payload.name.strip(),
                branch_code=payload.branch_code.strip() if payload.branch_code else None,
                parent_item_number=(
                    payload.parent_item_number.strip() if payload.parent_item_number else None
                ),
                blend_item_number=(
                    payload.blend_item_number.strip() if payload.blend_item_number else None
                ),
                customer_name=payload.customer_name,
                unit_type=payload.unit_type,
                category=payload.category,
                overage_percent=Decimal("0"),
                additional_information=payload.description,
                notes=payload.notes,
            )
        ],
    )
    session.add(formula)
    session.flush()
    return formula


def update_formula(
    session: Session,
    formula: Formula,
    *,
    is_active: bool | None = None,
    is_production: bool | None = None,
) -> Formula:
    if formula.is_voided:
        raise ValueError("Cannot update a deactivated formula")
    if is_active is not None:
        formula.is_active = is_active
    if is_production is not None:
        formula.is_production = is_production
    formula.updated_by = str(session.info.get("audit_user") or "SYSTEM")[:100]
    formula.updated_dt = datetime.now(UTC)
    session.flush()
    return formula


def deactivate_formula(session: Session, formula: Formula) -> Formula:
    formula.is_voided = True
    formula.is_active = False
    formula.is_production = False
    actor = str(session.info.get("audit_user") or "SYSTEM")[:100]
    changed_at = datetime.now(UTC)
    formula.updated_by = actor
    formula.updated_dt = changed_at
    if formula.headers:
        latest = max(formula.headers, key=lambda header: header.sequence)
        latest.workflow_status = "Inactive"
        latest.updated_by = actor
        latest.updated_dt = changed_at
    session.flush()
    return formula


# FormulaHeader


def get_header(session: Session, header_id: int) -> FormulaHeader | None:
    return session.get(FormulaHeader, header_id)


def list_headers(
    session: Session, formula_id: int, *, limit: int = 100, offset: int = 0,
    filters: dict[str, str] | None = None, sort_by: str | None = None,
    sort_dir: str = "asc",
) -> list[FormulaHeader]:
    return list(
        session.scalars(
            apply_grid_controls(
                select(FormulaHeader).where(FormulaHeader.formula_id == formula_id),
                {
                    "sequence": FormulaHeader.sequence,
                    "revision_label": FormulaHeader.revision_number,
                    "formula_name": FormulaHeader.formula_name,
                    "branch_code": FormulaHeader.branch_code,
                    "workflow_status": FormulaHeader.workflow_status,
                },
                filters=filters, sort_by=sort_by, sort_dir=sort_dir,
                default_order=(FormulaHeader.sequence, FormulaHeader.id),
            )
            .offset(offset)
            .limit(limit)
        )
    )


def create_header(session: Session, formula: Formula, header: FormulaHeader) -> FormulaHeader:
    if formula.is_voided:
        raise ValueError("Cannot add a revision to a deactivated formula")
    if header.formula_id is not None and header.formula_id != formula.id:
        raise ValueError("Header belongs to another formula")
    header.formula = formula
    session.add(header)
    session.flush()
    return header


def update_header(
    session: Session, header: FormulaHeader, *, changes: dict[str, object]
) -> FormulaHeader:
    _require_editable_header(header)
    protected = {"id", "formula_id", "sequence", "revision_number", "created_by", "created_dt"}
    if (
        not changes
        or set(changes) & protected
        or set(changes) - set(FormulaHeader.__table__.columns.keys())
    ):
        raise ValueError("Invalid header changes")
    for name, value in changes.items():
        setattr(header, name, value)
    header.updated_by = str(session.info.get("audit_user") or "SYSTEM")[:100]
    header.updated_dt = datetime.now(UTC)
    session.flush()
    return header


def deactivate_header(session: Session, header: FormulaHeader) -> FormulaHeader:
    deactivate_formula(session, header.formula)
    return header


# FormulaLine


def get_line(session: Session, line_id: int) -> FormulaLine | None:
    return session.get(FormulaLine, line_id)


def list_lines(
    session: Session, header_id: int, *, limit: int = 100, offset: int = 0,
    filters: dict[str, str] | None = None, sort_by: str | None = None,
    sort_dir: str = "asc",
) -> list[FormulaLine]:
    return list(
        session.scalars(
            apply_grid_controls(
                select(FormulaLine).where(FormulaLine.header_id == header_id),
                {
                    "line_number": FormulaLine.line_number,
                    "material_item_number": FormulaLine.material_item_number,
                    "material_description": FormulaLine.material_description,
                    "material_branch_code": FormulaLine.material_branch_code,
                    "potency": FormulaLine.potency,
                },
                filters=filters, sort_by=sort_by, sort_dir=sort_dir,
                default_order=(FormulaLine.line_number, FormulaLine.id),
            )
            .offset(offset)
            .limit(limit)
        )
    )


def create_line(session: Session, header: FormulaHeader, line: FormulaLine) -> FormulaLine:
    _require_editable_header(header)
    if line.header_id is not None and line.header_id != header.id:
        raise ValueError("Line belongs to another header")
    line.header = header
    session.add(line)
    session.flush()
    return line


def update_line(session: Session, line: FormulaLine, *, changes: dict[str, object]) -> FormulaLine:
    _require_editable_header(line.header)
    protected = {"id", "formula_header_id"}
    if (
        not changes
        or set(changes) & protected
        or set(changes) - set(FormulaLine.__table__.columns.keys())
    ):
        raise ValueError("Invalid line changes")
    for name, value in changes.items():
        setattr(line, name, value)
    session.flush()
    return line


def deactivate_line(session: Session, line: FormulaLine) -> FormulaLine:
    deactivate_formula(session, line.header.formula)
    return line


def _require_editable_header(header: FormulaHeader) -> None:
    if header.formula.is_voided:
        raise ValueError("Cannot edit a deactivated formula")
    if header.workflow_status != "Development":
        raise ValueError("Only Development revisions can be edited")
    if any(other.sequence > header.sequence for other in header.formula.headers):
        raise ValueError("Historical revisions cannot be edited")


def _stable_id(*parts: object) -> int:
    value = "|".join("" if part is None else str(part).strip() for part in parts)
    return zlib.crc32(value.encode("utf-8"))


def _list_legacy_formulas(
    session: Session,
    *,
    query: str | None,
    status: str | None,
    branch: str | None,
    limit: int,
    offset: int,
    filters: dict[str, str] | None,
    sort_by: str | None,
    sort_dir: str,
) -> list[FormulaListItem]:
    columns = {
        "name": "formula_name",
        "parent_item_number": "parent_item_number",
        "branch_code": "branch_code",
        "revision_label": "revision_number",
        "workflow_status": "workflow_status",
    }
    if sort_by and sort_by not in columns:
        raise ValueError(f"Unknown sort column: {sort_by}")
    if sort_dir not in {"asc", "desc"}:
        raise ValueError("sort_dir must be asc or desc")
    parameters = {
        "match": f"%{query.strip()}%" if query else None,
        "status": status,
        "branch": branch,
        "limit": limit,
        "offset": offset,
    }
    conditions = []
    for index, (name, value) in enumerate((filters or {}).items()):
        if name not in columns:
            raise ValueError(f"Unknown filter column: {name}")
        conditions.append(
            f"LOWER(CONVERT(nvarchar(4000), {columns[name]})) "
            f"LIKE LOWER(:filter_{index}) ESCAPE '\\'"
        )
        escaped = value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
        parameters[f"filter_{index}"] = f"%{escaped}%"
    where_filters = " AND " + " AND ".join(conditions) if conditions else ""
    order = (
        f"{columns[sort_by]} {sort_dir.upper()}, " if sort_by else ""
    ) + "formula_name, parent_item_number, branch_code, blend_item_number"
    rows = session.execute(
        text(
            f"""
            WITH revisions AS (
                SELECT
                    FHMCU AS branch_code,
                    FHPRNT AS parent_item_number,
                    FHBLND AS blend_item_number,
                    FHNAME AS formula_name,
                    FHRVNO AS revision_number,
                    LTRIM(RTRIM(COALESCE(FHSTUS, ''))) AS workflow_status,
                    FHCUSN AS customer_name,
                    FHUNTY AS unit_type,
                    FHFMCT AS category,
                    FHNOTE AS notes,
                    ROW_NUMBER() OVER (
                        PARTITION BY FHPRNT
                        ORDER BY FHRVNO DESC, FHSTUS, FHMCU
                    ) AS revision_rank
                FROM dbo.Formula_Header
                WHERE (
                    :match IS NULL
                    OR FHNAME LIKE :match
                    OR FHPRNT LIKE :match
                    OR FHBLND LIKE :match
                )
                  AND (:status IS NULL OR LTRIM(RTRIM(COALESCE(FHSTUS, ''))) = :status)
                  AND (:branch IS NULL OR LTRIM(RTRIM(COALESCE(FHMCU, ''))) = :branch)
            )
            SELECT *
            FROM revisions
            WHERE revision_rank = 1{where_filters}
            ORDER BY {order}
            OFFSET :offset ROWS FETCH NEXT :limit ROWS ONLY
            """
        ),
        parameters,
    ).mappings()

    items: list[FormulaListItem] = []
    for row in rows:
        revision_number = row["revision_number"]
        revision_label = str(revision_number if revision_number is not None else "0")
        formula_id = _stable_id(row["parent_item_number"], row["formula_name"])
        revision_id = _stable_id(
            row["branch_code"],
            row["parent_item_number"],
            row["blend_item_number"],
            revision_label,
            row["workflow_status"],
        )
        items.append(
            FormulaListItem(
                id=formula_id,
                parent_item_number=str(row["parent_item_number"] or "").strip(),
                name=str(row["formula_name"] or "Unnamed formula").strip(),
                category=(str(row["category"]).strip() if row["category"] else None),
                latest_revision=RevisionRead(
                    id=revision_id,
                    sequence=max(1, int(float(revision_number or 1))),
                    revision_number=Decimal(str(revision_number or 0)),
                    revision_label=revision_label,
                    workflow_status=row["workflow_status"] or "Unknown",
                    branch_code=str(row["branch_code"] or "").strip(),
                    parent_item_number=str(row["parent_item_number"] or "").strip(),
                    blend_item_number=str(row["blend_item_number"] or "").strip(),
                    formula_name=str(row["formula_name"] or "Unnamed formula").strip(),
                    category=(str(row["category"]).strip() if row["category"] else None),
                    customer_name=(
                        str(row["customer_name"]).strip() if row["customer_name"] else None
                    ),
                    unit_type=(str(row["unit_type"]).strip() if row["unit_type"] else None),
                    notes=row["notes"],
                    version=1,
                    created_by="LEGACY_MIGRATION",
                    created_dt=datetime.now(UTC),
                    updated_by="LEGACY_MIGRATION",
                    updated_dt=datetime.now(UTC),
                    lines=[],
                ),
            )
        )
    return items
