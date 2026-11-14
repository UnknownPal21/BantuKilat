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

# photos berisi id media hasil POST /media (URL /media/<id> juga diterima dan
# dinormalisasi di service). Data URI ditolak: base64 tidak pernah masuk DB.

# Alasan batal dibatasi pilihan, bukan teks bebas: dipakai untuk statistik
# "kenapa tawaran gagal" tanpa perlu NLP.
CancelReason = Literal[
    "SUDAH_SELESAI",
    "SALAH_INPUT",
    "TERLALU_LAMA",
    "LAINNYA",
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
        cleaned: list[str] = []
        for raw in v:
            p = raw.strip()
            if not p:
                continue
            # Jaring terakhir kalau Flutter mengirim data URI langsung ke
            # endpoint ini: tolak sebelum menyimpan string megabyte di Mongo.
            # Id/URL divalidasi lebih lanjut (dan dinormalisasi) di service.
            if p.startswith("data:") or len(p) > 300:
                raise ValueError("Foto harus diunggah lewat POST /media")
            cleaned.append(p)

        if not cleaned:
            raise ValueError("Minimal satu foto")
        return cleaned


class OfferCancelIn(BaseModel):
    """Alasan batal. Opsional supaya user tidak dipaksa memilih saat panik."""

    reason: CancelReason = "LAINNYA"
    note: str | None = Field(default=None, max_length=200)

    model_config = {"extra": "forbid"}

    @field_validator("note")
    @classmethod
    def strip_note(cls, v: str | None) -> str | None:
        if v is None:
            return None
        v = v.strip()
        return v or None


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
    # Terisi hanya kalau offer dibatalkan user atau kedaluwarsa.
    cancelled_at: str | None = None
    cancel_reason: str | None = None

    # Hanya terisi pada GET /offers/nearby ($geoNear).
    distance_m: int | None = None
