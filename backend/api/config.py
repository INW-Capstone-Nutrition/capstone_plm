from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parents[1] / ".env")

DEFAULT_DATABASE_URL = "sqlite:///./plm_dev.db"


def _as_bool(value: str | None, default: bool) -> bool:
    if value is None:
        return default
    return value.lower() in {"1", "true", "yes", "on"}


def _uses_database_components() -> bool:
    if os.getenv("PLM_DATABASE_URL"):
        return False
    return all(
        os.getenv(name) for name in ("PLM_DB_HOST", "PLM_DB_NAME", "PLM_DB_USER", "PLM_DB_PASSWORD")
    )


@dataclass(frozen=True, slots=True)
class Settings:
    app_name: str = "PLM Workspace API"
    api_prefix: str = "/api/v1"
    database_url: str = os.getenv("PLM_DATABASE_URL", DEFAULT_DATABASE_URL)
    database_host: str | None = os.getenv("PLM_DB_HOST")
    database_port: int = int(os.getenv("PLM_DB_PORT", "1433"))
    database_name: str | None = os.getenv("PLM_DB_NAME")
    database_user: str | None = os.getenv("PLM_DB_USER")
    database_password: str | None = os.getenv("PLM_DB_PASSWORD")
    database_driver: str = os.getenv("PLM_DB_DRIVER", "ODBC Driver 18 for SQL Server")
    database_encrypt: str = os.getenv("PLM_DB_ENCRYPT", "yes")
    database_trust_server_certificate: str = os.getenv("PLM_DB_TRUST_SERVER_CERTIFICATE", "yes")
    use_database_components: bool = _uses_database_components()
    cors_origins: tuple[str, ...] = tuple(
        value.strip()
        for value in os.getenv("PLM_CORS_ORIGINS", "http://localhost:5173").split(",")
        if value.strip()
    )
    seed_demo_data: bool = _as_bool(
        os.getenv("PLM_SEED_DEMO_DATA"),
        not use_database_components
        and os.getenv("PLM_DATABASE_URL", DEFAULT_DATABASE_URL).startswith("sqlite"),
    )
    auto_create_schema: bool = _as_bool(os.getenv("PLM_AUTO_CREATE_SCHEMA"), False)
    check_database_on_startup: bool = _as_bool(os.getenv("PLM_CHECK_DATABASE_ON_STARTUP"), True)


settings = Settings()
