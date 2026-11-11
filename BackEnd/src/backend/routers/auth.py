from fastapi import APIRouter, status

from backend.core.config import settings
from backend.models.auth import LoginIn, RegisterIn, TokenOut, UserOut
from backend.services import auth_service

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", status_code=status.HTTP_201_CREATED, response_model=TokenOut)
async def register(payload: RegisterIn) -> TokenOut:
    data_response = await auth_service.register(payload)
    return TokenOut(
        **data_response,
    )


@router.post("/login", status_code=status.HTTP_200_OK, response_model=TokenOut)
async def login(payload: LoginIn) -> TokenOut:
    data_response = await auth_service.login(payload)
    return TokenOut(
        **data_response,
    )
