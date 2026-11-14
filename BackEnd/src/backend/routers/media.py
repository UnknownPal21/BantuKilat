from fastapi import APIRouter, Depends, Query, Request, Response

from backend.core.deps import get_current_user
from backend.models.media import MediaIn, MediaOut
from backend.services import media_service

router = APIRouter(prefix="/media", tags=["media"])


@router.post("", response_model=MediaOut)
async def upload_media(
    payload: MediaIn,
    user: dict = Depends(get_current_user),
) -> MediaOut:
    """Terima satu foto sebagai data URI base64, simpan sebagai JPEG terkompresi."""
    data_response = await media_service.save_image(user, payload.data, payload.kind)
    return MediaOut(**data_response)


# Tanpa auth: Flutter memakai Image.network, yang tidak mengirim header
# Authorization. Sebagai gantinya URL wajib bertanda tangan dan berumur
# pendek, supaya id media saja tidak cukup untuk membuka foto.
@router.get("/{file_id}")
async def get_media(
    file_id: str,
    request: Request,
    exp: int | None = Query(default=None, description="Unix time kedaluwarsa"),
    sig: str | None = Query(default=None, description="HMAC URL foto"),
) -> Response:
    remaining = media_service.verify_signature(file_id, exp, sig)
    doc = await media_service.load(file_id)

    # Dibatasi per IP: tautan yang bocor tidak bisa dipakai menarik ribuan
    # foto berurutan. Flutter biasanya mengambil satu foto beberapa kali,
    # jadi batasnya longgar.
    media_service.media_view_counter.reserve(
        request.client.host if request.client else "unknown",
        media_service.settings.media_daily_view_limit,
        "buka foto",
        "MEDIA_RATE_LIMITED",
    )

    return Response(
        content=doc["data"],
        media_type=doc.get("content_type", "image/jpeg"),
        headers={
            # private: jangan disimpan cache bersama. URL-nya sendiri unik per
            # tanda tangan, dan umurnya mengikuti sisa masa berlaku.
            "Cache-Control": f"private, max-age={remaining}",
            "Content-Length": str(doc.get("size", len(doc["data"]))),
        },
    )
