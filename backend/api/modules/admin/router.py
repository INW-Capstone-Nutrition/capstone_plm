from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from api.database import get_session
from api.legacy import LEGACY_READ_ONLY_DETAIL, uses_legacy_schema
from api.modules.admin.models import AppUser
from api.modules.admin.schemas import UserCreate, UserRead

router = APIRouter(prefix="/users", tags=["administration"])
SessionDep = Annotated[Session, Depends(get_session)]


@router.get("", response_model=list[UserRead])
def get_users(session: SessionDep) -> list[AppUser]:
    return list(session.scalars(select(AppUser).order_by(AppUser.display_name)))


@router.post("", response_model=UserRead, status_code=status.HTTP_201_CREATED)
def create_user(payload: UserCreate, session: SessionDep) -> AppUser:
    if uses_legacy_schema(session):
        raise HTTPException(status_code=503, detail=LEGACY_READ_ONLY_DETAIL)
    user = AppUser(**payload.model_dump())
    session.add(user)
    session.commit()
    session.refresh(user)
    return user
