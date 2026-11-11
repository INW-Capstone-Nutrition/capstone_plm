from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from api.database import get_session
from api.modules.dashboard.repository import (
    count_revisions_by_status,
    material_dashboard_counts,
)
from api.modules.dashboard.schemas import DashboardSummary
from api.modules.formulas.repository import list_formulas

router = APIRouter(prefix="/dashboard", tags=["dashboard"])
SessionDep = Annotated[Session, Depends(get_session)]


@router.get("", response_model=DashboardSummary)
def get_dashboard(session: SessionDep) -> DashboardSummary:
    workflow_counts = count_revisions_by_status(session)
    recent = list_formulas(session, limit=5)
    total_materials, material_alerts = material_dashboard_counts(session)
    return DashboardSummary(
        active_formulas=workflow_counts.get("Active", 0),
        in_review=workflow_counts.get("Review", 0),
        development=workflow_counts.get("Development", 0),
        material_alerts=material_alerts or 0,
        total_materials=total_materials or 0,
        workflow_counts=workflow_counts,
        recent_formulas=recent,
    )
