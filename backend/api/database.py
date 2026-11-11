from collections.abc import Generator
from datetime import UTC, datetime

from sqlalchemy import DateTime, Unicode, create_engine, text
from sqlalchemy.dialects import mssql
from sqlalchemy.engine import URL
from sqlalchemy.orm import DeclarativeBase, Mapped, Session, mapped_column, sessionmaker
from sqlalchemy.pool import StaticPool

from api.config import settings

AUDIT_DATETIME = DateTime(timezone=True).with_variant(mssql.DATETIME2(precision=3), "mssql")


class Base(DeclarativeBase):
    """Shared SQLAlchemy model registry, equivalent to an EF Core model."""


def utc_now() -> datetime:
    return datetime.now(UTC)


class AuditColumnsMixin:
    """Standard ownership metadata for application-managed mutable records.

    Services should replace ``SYSTEM`` with the authenticated user name.  The
    defaults also make administrative scripts and legacy backfills explicit
    rather than leaving actor columns null.
    """

    created_by: Mapped[str] = mapped_column(
        Unicode(100), default="SYSTEM", server_default=text("'SYSTEM'")
    )
    created_dt: Mapped[datetime] = mapped_column(
        AUDIT_DATETIME, default=utc_now, server_default=text("CURRENT_TIMESTAMP")
    )
    updated_by: Mapped[str] = mapped_column(
        Unicode(100), default="SYSTEM", server_default=text("'SYSTEM'")
    )
    updated_dt: Mapped[datetime] = mapped_column(
        AUDIT_DATETIME,
        default=utc_now,
        onupdate=utc_now,
        server_default=text("CURRENT_TIMESTAMP"),
    )


def database_target() -> str | URL:
    component_values = (
        settings.database_host,
        settings.database_name,
        settings.database_user,
        settings.database_password,
    )
    if settings.use_database_components and all(component_values):
        return URL.create(
            "mssql+pyodbc",
            username=settings.database_user,
            password=settings.database_password,
            host=settings.database_host,
            port=settings.database_port,
            database=settings.database_name,
            query={
                "driver": settings.database_driver,
                "Encrypt": settings.database_encrypt,
                "TrustServerCertificate": settings.database_trust_server_certificate,
            },
        )
    return settings.database_url


target = database_target()
target_text = target.render_as_string(hide_password=True) if isinstance(target, URL) else target
connect_args = {"check_same_thread": False} if target_text.startswith("sqlite") else {}
engine_options: dict[str, object] = {
    "connect_args": connect_args,
    "pool_pre_ping": True,
}
if target_text in {"sqlite://", "sqlite:///:memory:"}:
    engine_options["poolclass"] = StaticPool
if target_text.startswith("sqlite"):
    # SQL Server owns the physical feature schema. SQLite has no equivalent
    # namespace, so local development/tests translate it to the main database.
    engine_options["execution_options"] = {
        "schema_translate_map": {"form": None, "mat": None, "spec": None}
    }

engine = create_engine(target, **engine_options)
SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


def get_session() -> Generator[Session, None, None]:
    """Provide one SQLAlchemy session per HTTP request."""
    with SessionLocal() as session:
        yield session
