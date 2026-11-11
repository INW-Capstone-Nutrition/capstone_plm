from sqlalchemy import text
from sqlalchemy.orm import Session

LEGACY_READ_ONLY_DETAIL = (
    "Legacy PLM is connected in read-only mode; normalized write schema is not installed."
)


def uses_legacy_schema(session: Session) -> bool:
    if session.bind is None or session.bind.dialect.name != "mssql":
        return False
    normalized = session.scalar(text("SELECT OBJECT_ID(N'form.formula', N'U')"))
    legacy = session.scalar(text("SELECT OBJECT_ID(N'dbo.Formula_Header', N'U')"))
    return normalized is None and legacy is not None
