from fastapi import APIRouter, Depends, status

from backend.core.deps import get_current_user
from backend.models.auth import LoginIn, MeOut, PhoneUpdateIn, RegisterIn, TokenOut
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


@router.get("/me", response_model=MeOut)
async def me(user: dict = Depends(get_current_user)) -> MeOut:
    data_response = await auth_service.me(user)
    return MeOut(**data_response)


@router.patch("/me/phone", response_model=MeOut)
async def update_phone(
    payload: PhoneUpdateIn,
    user: dict = Depends(get_current_user),
) -> MeOut:
    data_response = await auth_service.update_phone(user, payload.phone)
    return MeOut(**data_response)
