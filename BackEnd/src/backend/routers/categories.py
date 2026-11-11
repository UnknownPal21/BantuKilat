from fastapi import APIRouter

from backend.models.category import CategoryOut
from backend.services import category_service

router = APIRouter(prefix="/categories", tags=["categories"])


@router.get("", response_model=list[CategoryOut])
async def list_categories(include_inactive: bool = False) -> list[CategoryOut]:
    data_response = await category_service.list_categories(include_inactive)
    return [CategoryOut(**item) for item in data_response]
