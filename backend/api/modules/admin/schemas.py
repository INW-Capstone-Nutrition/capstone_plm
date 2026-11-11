from pydantic import BaseModel

from api.contracts import ReadModel


class UserCreate(BaseModel):
    user_name: str
    display_name: str
    email: str | None = None
    role: str = "formulator"
    branch_code: str | None = None


class UserRead(ReadModel):
    id: int
    user_name: str
    display_name: str
    email: str | None
    role: str
    branch_code: str | None
    is_active: bool
