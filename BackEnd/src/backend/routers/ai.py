from fastapi import APIRouter, Depends, Query, status

from backend.core.deps import get_current_user
from backend.models.ai import (
    ChatCreateIn,
    ChatDetailOut,
    ChatOut,
    EstimateIn,
    EstimateOut,
    MessageIn,
    MessageTurnOut,
)
from backend.services import ai_service

router = APIRouter(prefix="/ai", tags=["ai"])


@router.post("/estimate", response_model=EstimateOut)
async def estimate(
    payload: EstimateIn,
    user: dict = Depends(get_current_user),
) -> EstimateOut:
    """Klasifikasi + rentang harga tanpa menyimpan apa pun.

    Dipakai untuk menguji grounding sebelum chat dipakai: yang diperiksa hanya
    apakah kategori/keparahan masuk akal dan apakah angkanya berasal dari
    price_catalog.
    """
    data_response = await ai_service.estimate(user, payload)
    return EstimateOut(**data_response)


@router.post(
    "/chats", status_code=status.HTTP_201_CREATED, response_model=ChatOut
)
async def create_chat(
    payload: ChatCreateIn,
    user: dict = Depends(get_current_user),
) -> ChatOut:
    data_response = await ai_service.create_chat(user, payload)
    return ChatOut(**data_response)


@router.get("/chats", response_model=list[ChatOut])
async def list_chats(
    user: dict = Depends(get_current_user),
    limit: int = Query(default=20, ge=1, le=50),
) -> list[ChatOut]:
    data_response = await ai_service.list_chats(user, limit)
    return [ChatOut(**item) for item in data_response]


@router.get("/chats/{chat_id}", response_model=ChatDetailOut)
async def get_chat(
    chat_id: str,
    user: dict = Depends(get_current_user),
    limit: int = Query(default=30, ge=1, le=50),
    # ISO-8601 dari created_at pesan tertua yang sudah tampil (paginasi ke atas).
    before: str | None = None,
) -> ChatDetailOut:
    data_response = await ai_service.get_chat(user, chat_id, limit, before)
    return ChatDetailOut(**data_response)


@router.post("/chats/{chat_id}/messages", response_model=MessageTurnOut)
async def send_message(
    chat_id: str,
    payload: MessageIn,
    user: dict = Depends(get_current_user),
) -> MessageTurnOut:
    data_response = await ai_service.send_message(user, chat_id, payload)
    return MessageTurnOut(**data_response)


@router.post("/chats/{chat_id}/close", response_model=ChatOut)
async def close_chat(
    chat_id: str,
    user: dict = Depends(get_current_user),
) -> ChatOut:
    data_response = await ai_service.close_chat(user, chat_id)
    return ChatOut(**data_response)
