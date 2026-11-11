from pydantic import BaseModel

from api.modules.formulas.schemas import FormulaListItem


class DashboardSummary(BaseModel):
    active_formulas: int
    in_review: int
    development: int
    material_alerts: int
    total_materials: int
    workflow_counts: dict[str, int]
    recent_formulas: list[FormulaListItem]
