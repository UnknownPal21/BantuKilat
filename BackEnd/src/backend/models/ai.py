from typing import Literal

from pydantic import BaseModel, Field, field_validator

Severity = Literal["RINGAN", "SEDANG", "BERAT"]
ChatStatus = Literal["ACTIVE", "CLOSED"]
MessageRole = Literal["USER", "ASSISTANT"]


class EstimateIn(BaseModel):
    """Uji grounding tanpa menyimpan apa pun (dipakai saat menyetel prompt)."""

    text: str = Field(min_length=3, max_length=1000)
    # id media hasil POST /media, bukan URL dan bukan data URI.
    photos: list[str] = Field(default_factory=list, max_length=3)

    model_config = {"extra": "forbid"}

    @field_validator("text")
    @classmethod
    def strip_text(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("Cerita kerusakan tidak boleh kosong")
        return v


class ChatCreateIn(BaseModel):
    # Opsional: kalau kosong, judul diambil dari pesan pertama.
    title: str | None = Field(default=None, max_length=60)

    model_config = {"extra": "forbid"}

    @field_validator("title")
    @classmethod
    def strip_title(cls, v: str | None) -> str | None:
        if v is None:
            return None
        v = v.strip()
        return v or None


class MessageIn(BaseModel):
    text: str = Field(min_length=1, max_length=1000)
    # Boleh kosong: pesan lanjutan cukup teks.
    photos: list[str] = Field(default_factory=list, max_length=3)

    model_config = {"extra": "forbid"}

    @field_validator("text")
    @classmethod
    def strip_text(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("Pesan tidak boleh kosong")
        return v


class EstimateBlock(BaseModel):
    """Angka di sini SELALU berasal dari price_catalog, bukan dari model."""

    category_code: str
    category_label: str
    severity: Severity
    # min/median/max = p25/p50/p75 sampel historis, bukan min/max absolut:
    # satu kasus ekstrem tidak boleh menggeser seluruh rentang.
    min: int
    median: int
    max: int
    sample_count: int
    # "city" = data kota user, "national" = fallback nasional.
    scope: Literal["city", "national"]
    city: str | None = None
    confidence: float = 0.0
    # < 0.4 -> UI menampilkan label "perkiraan kasar".
    rough: bool = False


class EstimateOut(BaseModel):
    text: str
    estimate: EstimateBlock | None = None
    model: str
    error: str | None = None
    # False = foto tidak menampilkan kerusakan; harga sengaja tidak diberikan.
    # None = tidak ada foto atau server tidak bisa menilai foto.
    photo_relevant: bool | None = None


class MessageOut(BaseModel):
    id: str = Field(alias="_id")
    conversation_id: str
    role: MessageRole
    text: str
    photos: list[str] = Field(default_factory=list)
    estimate: EstimateBlock | None = None
    photo_relevant: bool | None = None
    model: str | None = None
    error: str | None = None
    created_at: str


class ChatOut(BaseModel):
    id: str = Field(alias="_id")
    title: str
    city: str | None = None
    status: ChatStatus
    message_count: int = 0
    # Cuplikan pesan terakhir, supaya daftar percakapan tidak perlu ikut
    # mengirim seluruh isi pesan.
    preview: str | None = None
    created_at: str
    updated_at: str
    last_message_at: str | None = None


class ChatDetailOut(BaseModel):
    conversation: ChatOut
    messages: list[MessageOut]


class MessageTurnOut(BaseModel):
    user_message: MessageOut
    assistant_message: MessageOut
