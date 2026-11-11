from pydantic import BaseModel, Field

from api.contracts import ReadModel


class MaterialCreate(BaseModel):
    item_number: str = Field(min_length=1, max_length=40)
    description: str = Field(min_length=2, max_length=200)
    category: str | None = None
    base_uom: str = Field(default="MG", max_length=12)
    branch_code: str = Field(default="10", max_length=12)


class MaterialUpdate(BaseModel):
    description: str | None = Field(default=None, max_length=200)
    category: str | None = Field(default=None, max_length=80)
    base_uom: str | None = Field(default=None, max_length=12)
    stocking_type: str | None = Field(default=None, max_length=20)
    tier_level: str | None = Field(default=None, max_length=20)


class MaterialRead(ReadModel):
    id: int
    item_number: str
    description: str | None
    category: str | None
    base_uom: str | None
    branch_code: str
    stocking_type: str | None = None
    tier_level: str | None = None
    source_system: str | None = None
    is_active: bool
