from pydantic import BaseModel, ConfigDict


class ReadModel(BaseModel):
    """Base for API responses populated from SQLAlchemy objects."""

    model_config = ConfigDict(from_attributes=True)
