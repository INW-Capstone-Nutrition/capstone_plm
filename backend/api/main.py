from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from api.config import settings
from api.database import Base, SessionLocal, engine
from api.modules import register_modules
from api.modules.model_catalog import load_models
from api.seed import seed_demo_data

load_models()


@asynccontextmanager
async def lifespan(_: FastAPI):
    if settings.check_database_on_startup:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
    if settings.auto_create_schema:
        Base.metadata.create_all(bind=engine)
    if settings.seed_demo_data:
        with SessionLocal() as session:
            seed_demo_data(session)
    yield


def create_app() -> FastAPI:
    application = FastAPI(
        title=settings.app_name,
        version="0.1.0",
        description="Modern PLM API mapped from the legacy PowerBuilder application.",
        lifespan=lifespan,
    )
    application.add_middleware(
        CORSMiddleware,
        allow_origins=list(settings.cors_origins),
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    register_modules(application, prefix=settings.api_prefix)

    @application.get("/", include_in_schema=False)
    def root() -> dict[str, str]:
        return {"name": settings.app_name, "docs": "/docs"}

    return application


app = create_app()
