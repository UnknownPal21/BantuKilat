from typing import Literal

from pydantic import BaseModel, Field, field_validator

BidStatus = Literal[
    "PENDING",
    "COUNTERED",
    "ACCEPTED",
    "REJECTED",
    "WITHDRAWN",
    "EXPIRED",
]


class BidCreateIn(BaseModel):
    amount: int = Field(ge=0, le=100_000_000)
    message: str | None = Field(default=None, max_length=300)

    model_config = {"extra": "forbid"}

    @field_validator("message")
    @classmethod
    def strip_message(cls, v: str | None) -> str | None:
        if v is None:
            return None
        v = v.strip()
        return v or None


class BidOut(BaseModel):
    id: str = Field(alias="_id")
    offer_id: str
    technician_id: str
    # name/avatar_url/rating saat bid dikirim, bukan data teknisi sekarang.
    technician_snapshot: dict
    amount: int
    message: str | None = None
    status: BidStatus
    accepted_at: str | None = None
    created_at: str
    # Tidak ada di tabel spec, tapi dibutuhkan saat teknisi mengubah nominal
    # (bid ulang) supaya UI bisa menampilkan "diperbarui".
    updated_at: str | None = None
