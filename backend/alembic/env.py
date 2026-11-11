from logging.config import fileConfig

from sqlalchemy import engine_from_config, pool
from sqlalchemy.engine import URL

from alembic import context
from api.database import Base, database_target
from api.modules.model_catalog import load_models

load_models()

config = context.config
if config.config_file_name:
    fileConfig(config.config_file_name)

target = database_target()
target_url = target.render_as_string(hide_password=False) if isinstance(target, URL) else target
config.set_main_option("sqlalchemy.url", target_url.replace("%", "%%"))
target_metadata = Base.metadata


def include_object(
    _object: object,
    _name: str | None,
    type_: str,
    reflected: bool,
    compare_to: object | None,
) -> bool:
    """Ignore legacy/source tables that are not owned by this ORM metadata."""

    return not (type_ == "table" and reflected and compare_to is None)


def run_migrations_offline() -> None:
    context.configure(
        url=config.get_main_option("sqlalchemy.url"),
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=True,
        include_schemas=True,
        include_object=include_object,
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        if connection.dialect.name == "sqlite":
            connection = connection.execution_options(
                schema_translate_map={"form": None, "mat": None, "spec": None}
            )
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            compare_type=True,
            render_as_batch=connection.dialect.name == "sqlite",
            include_schemas=True,
            include_object=include_object,
        )
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
