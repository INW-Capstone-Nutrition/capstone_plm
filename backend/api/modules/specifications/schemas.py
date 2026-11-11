from pydantic import BaseModel, Field

from api.contracts import ReadModel


class SpecificationCreate(BaseModel):
    item_number: str
    branch_code: str = "10"
    revision: int = Field(default=1, ge=1)
    review_status: str | None = None
    appearance: str | None = None
    color: str | None = None
    item_type: str | None = None
    physical_form: str | None = None


class SpecificationUpdate(BaseModel):
    review_status: str | None = None
    appearance: str | None = None
    color: str | None = None
    item_type: str | None = None
    physical_form: str | None = None


class SpecificationRead(ReadModel):
    id: int
    material_id: int
    revision: int
    review_status: str | None
    is_released: bool | None
    appearance: str | None
    color: str | None
    item_type: str | None
    physical_form: str | None
