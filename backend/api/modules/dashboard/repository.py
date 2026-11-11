from sqlalchemy import func, select, text
from sqlalchemy.orm import Session

from api.legacy import uses_legacy_schema
from api.modules.formulas.models import FormulaHeader
from api.modules.materials.models import FormulationAssistant, Material


def count_revisions_by_status(session: Session) -> dict[str, int]:
    if uses_legacy_schema(session):
        rows = session.execute(
            text(
                """
                SELECT LTRIM(RTRIM(COALESCE(FHSTUS, 'Unknown'))) AS workflow_status,
                       COUNT_BIG(*) AS revision_count
                FROM dbo.Formula_Header
                GROUP BY LTRIM(RTRIM(COALESCE(FHSTUS, 'Unknown')))
                """
            )
        ).all()
        return {status or "Unknown": int(count) for status, count in rows}
    rows = session.execute(
        select(FormulaHeader.workflow_status, func.count(FormulaHeader.id)).group_by(
            FormulaHeader.workflow_status
        )
    ).all()
    return {status: count for status, count in rows}


def material_dashboard_counts(session: Session) -> tuple[int, int]:
    if uses_legacy_schema(session):
        row = session.execute(
            text(
                """
                SELECT COUNT_BIG(*) AS total,
                       SUM(
                           CASE WHEN COALESCE(quantity_available, 0) < 100 THEN 1 ELSE 0 END
                       ) AS alerts
                FROM dbo.Formulation_Assistant
                """
            )
        ).one()
        return int(row.total or 0), int(row.alerts or 0)
    total = session.scalar(select(func.count(Material.id))) or 0
    alerts = (
        session.scalar(
            select(func.count(FormulationAssistant.id)).where(
                FormulationAssistant.quantity_available < 100
            )
        )
        or 0
    )
    return int(total), int(alerts)
