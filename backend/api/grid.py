"""Validated read-only grid controls shared by repository list queries."""

import json
from collections.abc import Mapping

from fastapi import HTTPException, Query
from sqlalchemy import Boolean, Unicode, cast
from sqlalchemy.sql import Select


def parse_filters(raw: str | None) -> dict[str, str]:
    if not raw:
        return {}
    try:
        values = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ValueError("filters must be a JSON object") from exc
    if not isinstance(values, dict) or any(
        not isinstance(key, str) or not isinstance(value, str)
        for key, value in values.items()
    ):
        raise ValueError("filters must map column names to text")
    return {key: value.strip() for key, value in values.items() if value.strip()}


def grid_filters(filters: str | None = Query(default=None)) -> dict[str, str]:
    try:
        return parse_filters(filters)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


def apply_grid_controls(
    statement: Select,
    columns: Mapping[str, object],
    *,
    filters: Mapping[str, str] | None = None,
    sort_by: str | None = None,
    sort_dir: str = "asc",
    default_order: tuple[object, ...] = (),
) -> Select:
    if sort_by and sort_by not in columns:
        raise ValueError(f"Unknown sort column: {sort_by}")
    if sort_dir not in {"asc", "desc"}:
        raise ValueError("sort_dir must be asc or desc")
    for name, value in (filters or {}).items():
        if name not in columns:
            raise ValueError(f"Unknown filter column: {name}")
        column = columns[name]
        if isinstance(column.type, Boolean):
            normalized = value.casefold()
            if normalized not in {"yes", "no", "true", "false", "1", "0"}:
                raise ValueError(f"{name} must be Yes or No")
            statement = statement.where(column == (normalized in {"yes", "true", "1"}))
        else:
            escaped = value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
            statement = statement.where(cast(column, Unicode).ilike(f"%{escaped}%", escape="\\"))
    if sort_by:
        column = columns[sort_by]
        statement = statement.order_by(column.desc() if sort_dir == "desc" else column.asc())
    return statement.order_by(*default_order)
