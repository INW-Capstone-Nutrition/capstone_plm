def load_models() -> None:
    """Load every module's ORM mappings into the shared SQLAlchemy metadata."""
    from api.modules.admin import models as administration_models
    from api.modules.audit import models as audit_models
    from api.modules.formulas import models as formula_models
    from api.modules.materials import models as material_models
    from api.modules.specifications import models as specification_models

    _ = (
        administration_models,
        audit_models,
        formula_models,
        material_models,
        specification_models,
    )
