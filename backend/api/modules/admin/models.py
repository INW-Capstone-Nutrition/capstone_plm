from sqlalchemy import Boolean, String
from sqlalchemy.orm import Mapped, mapped_column

from api.database import AuditColumnsMixin, Base


class AppUser(AuditColumnsMixin, Base):
    __tablename__ = "app_user"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_name: Mapped[str] = mapped_column(String(80), unique=True, index=True)
    display_name: Mapped[str] = mapped_column(String(160))
    email: Mapped[str | None] = mapped_column(String(200))
    role: Mapped[str] = mapped_column(String(40), default="formulator")
    branch_code: Mapped[str | None] = mapped_column(String(12))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
