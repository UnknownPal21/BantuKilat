from fastapi import APIRouter, Depends, Response

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
# Authorization. Nama file ObjectId tidak bisa ditebak.
@router.get("/{file_id}")
async def get_media(file_id: str) -> Response:
    doc = await media_service.load(file_id)
    return Response(
        content=doc["data"],
        media_type=doc.get("content_type", "image/jpeg"),
        headers={
            # Isi file tidak pernah berubah untuk id yang sama -> aman immutable.
            "Cache-Control": "public, max-age=31536000, immutable",
            "Content-Length": str(doc.get("size", len(doc["data"]))),
        },
    )
