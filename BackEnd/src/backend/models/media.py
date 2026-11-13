from typing import Literal

from pydantic import BaseModel, Field

from backend.core.config import settings


class MediaIn(BaseModel):
    # Satu foto per request. Base64 hanya format transport: setelah di-decode,
    # yang disimpan adalah byte gambar, dan yang beredar di API hanya id.
    data: str = Field(min_length=1, max_length=settings.media_max_input_chars)
    kind: Literal["offers", "ai"] = "offers"

    model_config = {"extra": "forbid"}


class MediaOut(BaseModel):
    id: str
    url: str
    width: int
    height: int
    size: int
