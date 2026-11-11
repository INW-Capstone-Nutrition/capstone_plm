from __future__ import annotations

import zlib
from datetime import UTC, datetime

from sqlalchemy import and_, or_, select, text
from sqlalchemy.orm import Session

from api.grid import apply_grid_controls
from api.legacy import uses_legacy_schema
from api.modules.materials.models import (
    FormulaItemCost,
    FormulationAssistant,
    ItemJdeOriginal,
    Material,
)
from api.modules.materials.schemas import MaterialCreate, MaterialRead, MaterialUpdate


def get_material(session: Session, material_id: int) -> Material | None:
    return session.get(Material, material_id)


def get_material_by_key(session: Session, branch_code: str, item_number: str) -> Material | None:
    return session.scalar(
        select(Material).where(
            Material.branch_code == branch_code,
            Material.item_number == item_number,
        )
    )


def list_materials(
    session: Session,
    *,
    query: str | None = None,
    branch: str | None = None,
    limit: int = 100,
    offset: int = 0,
    filters: dict[str, str] | None = None,
    sort_by: str | None = None,
    sort_dir: str = "asc",
) -> list[MaterialRead]:
    if uses_legacy_schema(session):
        columns = {
            "item_number": "item_number",
            "branch_code": "branch_code",
            "description": "description",
            "category": "category",
            "is_active": "is_active",
        }
        if sort_by and sort_by not in columns:
            raise ValueError(f"Unknown sort column: {sort_by}")
        if sort_dir not in {"asc", "desc"}:
            raise ValueError("sort_dir must be asc or desc")
        parameters = {
            "match": f"%{query.strip()}%" if query else None,
            "branch": branch,
            "limit": limit,
            "offset": offset,
        }
        conditions = []
        for index, (name, value) in enumerate((filters or {}).items()):
            if name not in columns:
                raise ValueError(f"Unknown filter column: {name}")
            if name == "is_active":
                if value.casefold() not in {"yes", "true", "1"}:
                    if value.casefold() not in {"no", "false", "0"}:
                        raise ValueError("is_active must be Yes or No")
                    conditions.append("is_active = 0")
                continue
            conditions.append(
                f"LOWER(CONVERT(nvarchar(4000), {columns[name]})) "
                f"LIKE LOWER(:filter_{index}) ESCAPE '\\'"
            )
            escaped = value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
            parameters[f"filter_{index}"] = f"%{escaped}%"
        where_filters = " AND " + " AND ".join(conditions) if conditions else ""
        order = (
            f"{columns[sort_by]} {sort_dir.upper()}, " if sort_by else ""
        ) + "branch_code, item_number"
        rows = session.execute(
            text(
                f"""
                WITH materials AS (SELECT
                    COALESCE(IB_item_number, EX_item_number) AS item_number,
                    Item_Description AS description,
                    Category AS category,
                    primary_UOM AS base_uom,
                    COALESCE(IB_branch, EX_branch) AS branch_code,
                    stocking_type,
                    tier_level,
                    1 AS is_active
                FROM dbo.Formulation_Assistant
                WHERE (
                    :match IS NULL
                    OR COALESCE(IB_item_number, EX_item_number) LIKE :match
                    OR Item_Description LIKE :match
                )
                  AND (
                    :branch IS NULL
                    OR LTRIM(RTRIM(COALESCE(IB_branch, EX_branch, ''))) = :branch
                  ))
                SELECT * FROM materials
                WHERE 1 = 1{where_filters}
                ORDER BY {order}
                OFFSET :offset ROWS FETCH NEXT :limit ROWS ONLY
                """
            ),
            parameters,
        ).mappings()
        return [
            MaterialRead(
                id=_stable_id(row["item_number"], row["branch_code"]),
                item_number=str(row["item_number"] or "").strip(),
                description=(str(row["description"]).strip() if row["description"] else None),
                category=(str(row["category"]).strip() if row["category"] else None),
                base_uom=(str(row["base_uom"]).strip() if row["base_uom"] else None),
                branch_code=str(row["branch_code"] or "").strip(),
                stocking_type=row["stocking_type"],
                tier_level=row["tier_level"],
                source_system="PLM",
                is_active=True,  # Legacy source has no lifecycle flag; this path is read-only.
            )
            for row in rows
        ]

    statement = select(Material).where(Material.is_active == True)  # noqa: E712
    if query:
        match = f"%{query.strip()}%"
        statement = statement.where(
            or_(Material.item_number.ilike(match), Material.description.ilike(match))
        )
    if branch:
        statement = statement.where(Material.branch_code == branch)
    statement = apply_grid_controls(
        statement,
        {
            "item_number": Material.item_number,
            "branch_code": Material.branch_code,
            "description": Material.description,
            "category": Material.category,
            "is_active": Material.is_active,
        },
        filters=filters, sort_by=sort_by, sort_dir=sort_dir,
        default_order=(Material.branch_code, Material.item_number, Material.id),
    ).offset(offset).limit(limit)

    return [MaterialRead.model_validate(material) for material in session.scalars(statement).all()]


def create_material(session: Session, payload: MaterialCreate) -> Material:
    material = Material(
        branch_code=payload.branch_code.strip(),
        item_number=payload.item_number.strip(),
        description=payload.description.strip(),
        category=payload.category,
        base_uom=payload.base_uom,
        source_system="PLM",
    )
    session.add(material)
    session.flush()
    return material


def update_material(session: Session, material: Material, payload: MaterialUpdate) -> Material:
    if not material.is_active:
        raise ValueError("Cannot update an inactive material")
    for name, value in payload.model_dump(exclude_unset=True).items():
        setattr(material, name, value)
    material.updated_by = str(session.info.get("audit_user") or "SYSTEM")[:100]
    material.updated_dt = datetime.now(UTC)
    session.flush()
    return material


def deactivate_material(session: Session, material: Material) -> Material:
    material.is_active = False
    material.updated_by = str(session.info.get("audit_user") or "SYSTEM")[:100]
    material.updated_dt = datetime.now(UTC)
    session.flush()
    return material


def list_formulation_assistants(
    session: Session, material: Material, *, limit: int = 100, offset: int = 0,
    filters: dict[str, str] | None = None, sort_by: str | None = None,
    sort_dir: str = "asc",
) -> list[FormulationAssistant]:
    return list(
        session.scalars(
            apply_grid_controls(
                select(FormulationAssistant).where(
                    or_(
                        FormulationAssistant.material_id == material.id,
                        and_(
                            FormulationAssistant.branch_code == material.branch_code,
                            FormulationAssistant.item_number == material.item_number,
                        ),
                        and_(
                            FormulationAssistant.ext_branch_code == material.branch_code,
                            FormulationAssistant.ext_item_number == material.item_number,
                        ),
                    ),
                ),
                {column.key: column for column in FormulationAssistant.__table__.columns},
                filters=filters, sort_by=sort_by, sort_dir=sort_dir,
                default_order=(FormulationAssistant.id,),
            )
            .offset(offset)
            .limit(limit)
        )
    )


def list_item_jde_original(
    session: Session, material: Material, *, limit: int = 100, offset: int = 0,
    filters: dict[str, str] | None = None, sort_by: str | None = None,
    sort_dir: str = "asc",
) -> list[ItemJdeOriginal]:
    return list(
        session.scalars(
            apply_grid_controls(
                select(ItemJdeOriginal).where(
                    or_(
                        ItemJdeOriginal.material_id == material.id,
                        and_(
                            ItemJdeOriginal.source_branch_code == material.branch_code,
                            ItemJdeOriginal.source_item_number == material.item_number,
                        ),
                    ),
                ),
                {column.key: column for column in ItemJdeOriginal.__table__.columns},
                filters=filters, sort_by=sort_by, sort_dir=sort_dir,
                default_order=(
                    ItemJdeOriginal.source_julian_date.desc(), ItemJdeOriginal.id.desc()
                ),
            )
            .offset(offset)
            .limit(limit)
        )
    )


def list_formula_item_costs(
    session: Session, material: Material, *, limit: int = 100, offset: int = 0,
    filters: dict[str, str] | None = None, sort_by: str | None = None,
    sort_dir: str = "asc",
) -> list[FormulaItemCost]:
    return list(
        session.scalars(
            apply_grid_controls(
                select(FormulaItemCost).where(FormulaItemCost.item_number == material.item_number),
                {column.key: column for column in FormulaItemCost.__table__.columns},
                filters=filters, sort_by=sort_by, sort_dir=sort_dir,
                default_order=(FormulaItemCost.run_julian_date.desc(), FormulaItemCost.id.desc()),
            )
            .offset(offset)
            .limit(limit)
        )
    )


def _stable_id(*parts: object) -> int:
    value = "|".join("" if part is None else str(part).strip() for part in parts)
    return zlib.crc32(value.encode("utf-8"))
