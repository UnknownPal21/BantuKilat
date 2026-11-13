from fastapi import APIRouter, Depends

from backend.core.deps import get_current_user
from backend.models.offer import OfferOut
from backend.services import bid_service

router = APIRouter(prefix="/bids", tags=["bids"])


@router.post("/{bid_id}/accept", response_model=OfferOut)
async def accept_bid(
    bid_id: str,
    # Bukan require_role("USER"): pemilik offer bisa ber-role apa pun.
    # Kepemilikan offer yang diperiksa di service.
    user: dict = Depends(get_current_user),
) -> OfferOut:
    data_response = await bid_service.accept(user, bid_id)
    return OfferOut(**data_response)
