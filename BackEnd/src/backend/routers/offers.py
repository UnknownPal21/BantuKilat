from fastapi import APIRouter, Depends, Query, status

from backend.core.deps import get_current_user, require_role
from backend.models.bid import BidCreateIn, BidOut, BidStatus
from backend.models.offer import OfferCancelIn, OfferCreateIn, OfferOut, OfferStatus
from backend.services import bid_service, offer_service

router = APIRouter(prefix="/offers", tags=["offers"])


@router.post("", status_code=status.HTTP_201_CREATED, response_model=OfferOut)
async def create_offer(
    payload: OfferCreateIn,
    user: dict = Depends(get_current_user),
) -> OfferOut:
    data_response = await offer_service.create(user, payload)
    return OfferOut(**data_response)


# Route statis (/nearby, /mine, /tasks) wajib di atas route dinamis
# (/{offer_id}); kalau tidak, "nearby" dibaca sebagai offer_id.
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


@router.get("/tasks", response_model=list[OfferOut])
async def my_tasks(
    # Kepemilikan teknisi dicek dari dokumen user, bukan role token.
    user: dict = Depends(require_role("TECHNICIAN")),
    status_filter: OfferStatus | None = Query(default=None, alias="status"),
    limit: int = Query(default=50, ge=1, le=100),
) -> list[OfferOut]:
    """Tugas untuk teknisi yang sedang login (ASSIGNED / COMPLETED)."""
    data_response = await offer_service.tasks(user, status_filter, limit)
    return [OfferOut(**item) for item in data_response]


# Route dinamis wajib di bawah /nearby dan /mine, kalau tidak "nearby"
# akan dibaca sebagai offer_id.
@router.get("/{offer_id}", response_model=OfferOut)
async def get_offer(
    offer_id: str,
    user: dict = Depends(get_current_user),
) -> OfferOut:
    data_response = await offer_service.get(offer_id)
    return OfferOut(**data_response)


@router.get("/{offer_id}/bids", response_model=list[BidOut])
async def list_bids(
    offer_id: str,
    user: dict = Depends(get_current_user),
    status_filter: BidStatus | None = Query(default=None, alias="status"),
    limit: int = Query(default=50, ge=1, le=100),
) -> list[BidOut]:
    data_response = await bid_service.list_for_offer(
        user, offer_id, status_filter, limit
    )
    return [BidOut(**item) for item in data_response]


@router.post("/{offer_id}/bids", response_model=BidOut)
async def place_bid(
    offer_id: str,
    payload: BidCreateIn,
    # require_role memakai dokumen user di DB, bukan claim token.
    user: dict = Depends(require_role("TECHNICIAN")),
) -> BidOut:
    data_response = await bid_service.place_bid(user, offer_id, payload)
    return BidOut(**data_response)


@router.post("/{offer_id}/complete", response_model=OfferOut)
async def complete_offer(
    offer_id: str,
    # Kepemilikan tugas diperiksa di service (technician_id == user).
    user: dict = Depends(get_current_user),
) -> OfferOut:
    data_response = await offer_service.complete(user, offer_id)
    return OfferOut(**data_response)


@router.post("/{offer_id}/cancel", response_model=OfferOut)
async def cancel_offer(
    offer_id: str,
    payload: OfferCancelIn | None = None,
    user: dict = Depends(get_current_user),
) -> OfferOut:
    """Batalkan tawaran (hanya selama belum ada teknisi yang ditugaskan).

    Body boleh kosong: alasan default `LAINNYA`.
    """
    data_response = await offer_service.cancel(
        user, offer_id, payload or OfferCancelIn()
    )
    return OfferOut(**data_response)
