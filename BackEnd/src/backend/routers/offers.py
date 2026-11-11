from fastapi import APIRouter, Depends, Query, status

from backend.core.deps import get_current_user
from backend.models.offer import OfferCreateIn, OfferOut, OfferStatus
from backend.services import offer_service

router = APIRouter(prefix="/offers", tags=["offers"])


@router.post("", status_code=status.HTTP_201_CREATED, response_model=OfferOut)
async def create_offer(
    payload: OfferCreateIn,
    user: dict = Depends(get_current_user),
) -> OfferOut:
    data_response = await offer_service.create(user, payload)
    return OfferOut(**data_response)


# Harus dideklarasikan sebelum route dinamis (/{offer_id}) kalau nanti ada.
@router.get("/nearby", response_model=list[OfferOut])
async def nearby_offers(
    lng: float = Query(ge=-180, le=180),
    lat: float = Query(ge=-90, le=90),
    radius: int = Query(default=5000, ge=100, le=50_000),
    category: str | None = None,
    sos: bool | None = None,
    limit: int = Query(default=20, ge=1, le=50),
    # Wajib login: offer memuat lokasi & alamat rumah user.
    user: dict = Depends(get_current_user),
) -> list[OfferOut]:
    data_response = await offer_service.nearby(lng, lat, radius, category, sos, limit)
    return [OfferOut(**item) for item in data_response]


@router.get("/mine", response_model=list[OfferOut])
async def my_offers(
    user: dict = Depends(get_current_user),
    status_filter: OfferStatus | None = Query(default=None, alias="status"),
    limit: int = Query(default=20, ge=1, le=50),
) -> list[OfferOut]:
    data_response = await offer_service.mine(user, status_filter, limit)
    return [OfferOut(**item) for item in data_response]
