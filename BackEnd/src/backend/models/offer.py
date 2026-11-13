from typing import Literal

from pydantic import BaseModel, Field, field_validator

OfferStatus = Literal[
    "WAITING",
    "NEGOTIATING",
    "ASSIGNED",
    "COMPLETED",
    "CANCELLED",
    "EXPIRED",
]


class OfferCreateIn(BaseModel):
    category_id: str
    title: str = Field(min_length=5, max_length=100)
    description: str = Field(min_length=10, max_length=1000)
    photos: list[str] = Field(min_length=1, max_length=5)
    lng: float = Field(ge=-180, le=180)
    lat: float = Field(ge=-90, le=90)
    address_text: str = Field(min_length=3, max_length=200)
    is_sos: bool = False
    initial_budget: int = Field(ge=0, le=100_000_000)

    model_config = {"extra": "forbid"}

    @field_validator("title", "description", "address_text")
    @classmethod
    def strip_text(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("Tidak boleh kosong")
        return v

    @field_validator("photos")
    @classmethod
    def clean_photos(cls, v: list[str]) -> list[str]:
        # Buang string kosong: photos: ["", "a.jpg"] tidak boleh lolos.
        cleaned = [p.strip() for p in v if p.strip()]
        if not cleaned:
            raise ValueError("Minimal satu foto")
        return cleaned


class OfferOut(BaseModel):
    id: str = Field(alias="_id")
    requester_id: str
    requester_snapshot: dict
    category_id: str
    category_snapshot: dict
    title: str
    description: str
    photos: list[str]
    location: dict
    address_text: str
    geo_index: dict | None = None

    is_sos: bool
    sos_fee: int
    initial_budget: int
    agreed_price: int | None = None

    status: OfferStatus
    accepted_bid_id: str | None = None
    technician_id: str | None = None
    bid_count: int = 0

    # str ISO-8601, bukan datetime: pymongo mengembalikan datetime naive,
    # dan Pydantic akan men-serialisasinya tanpa zona -> Flutter salah tafsir.
    created_at: str
    updated_at: str
    expires_at: str
    assigned_at: str | None = None
    completed_at: str | None = None

    # Hanya terisi pada GET /offers/nearby ($geoNear).
    distance_m: int | None = None
