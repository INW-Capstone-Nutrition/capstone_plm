from fastapi import FastAPI


def register_modules(app: FastAPI, *, prefix: str) -> None:
    """Composition root for all business modules."""
    from api.modules.admin.router import router as administration_router
    from api.modules.dashboard.router import router as dashboard_router
    from api.modules.formulas.router import router as formulas_router
    from api.modules.materials.router import router as materials_router
    from api.modules.specifications.router import router as specifications_router
    from api.modules.system.router import router as system_router

    for router in (
        system_router,
        dashboard_router,
        formulas_router,
        materials_router,
        specifications_router,
        administration_router,
    ):
        app.include_router(router, prefix=prefix)
