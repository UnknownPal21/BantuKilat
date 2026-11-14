import base64
import binascii
import hashlib
import hmac
import re
import time
from io import BytesIO
from urllib.parse import urlsplit

from bson import Binary, ObjectId
from bson.errors import InvalidId
from PIL import Image, ImageOps, UnidentifiedImageError

from backend.core.config import settings
from backend.core.errors import ApiError
from backend.core.ratelimit import DayCounter
from backend.core.timeutils import utcnow
from backend.db.mongo import db

# Counter di memori: membatasi penyalahgunaan tanpa query Mongo pada setiap
# GET /media. Kalau nanti lebih dari satu worker, pindahkan ke Redis.
media_view_counter = DayCounter(settings.ai_quota_utc_offset_hours)
media_upload_counter = DayCounter(settings.ai_quota_utc_offset_hours)

# Foto disimpan sebagai satu dokumen biner di collection `media`, bukan GridFS:
# pymongo 4.19 belum menyediakan AsyncGridFSBucket, dan hasil kompresi server
# (<= 1024px JPEG) selalu jauh di bawah limit 16 MB per dokumen.
MAX_SIDE = 1024
JPEG_QUALITY = 82

# Batasi piksel sebelum Pillow membuka gambar: PNG 10 KB bisa mengaku
# 50.000 x 50.000 dan menghabiskan memori saat di-decode.
Image.MAX_IMAGE_PIXELS = 40_000_000

_MEDIA_ID = re.compile(r"^[0-9a-fA-F]{24}$")
# Path foto di URL: /media/<24 hex>, boleh dengan atau tanpa query
# (?exp=...&sig=...) karena Flutter sering mengirim balik URL yang diterimanya.
_MEDIA_PATH = re.compile(r"^/media/([0-9a-fA-F]{24})/?$")

_ALLOWED_PREFIXES = (
    "data:image/jpeg;base64",
    "data:image/jpg;base64",
    "data:image/png;base64",
    "data:image/webp;base64",
)

# Urutan membedakan tanda tangan ini dari token JWT yang memakai secret sama.
_SIGNATURE_CONTEXT = "media-url-v1"


def is_media_id(value: str) -> bool:
    return bool(_MEDIA_ID.fullmatch(value))


def _signature(file_id: str, expires_at: int) -> str:
    message = f"{_SIGNATURE_CONTEXT}:{file_id}:{expires_at}".encode()
    digest = hmac.new(
        settings.jwt_secret.encode(), message, hashlib.sha256
    ).hexdigest()
    # 40 hex = 160 bit: cukup untuk mencegah tebak-tebakan, tetap pendek di URL.
    return digest[:40]


def public_url(file_id: str, ttl: int | None = None) -> str:
    """URL foto bertanda tangan yang kedaluwarsa.

    Tanda tangan dibuat ulang setiap kali response dikirim, jadi UI selalu
    mendapat tautan segar. Tautan lama yang sudah tersebar mati sendiri.
    """
    lifetime = settings.media_url_ttl_seconds if ttl is None else ttl
    expires_at = int(time.time()) + max(1, lifetime)
    signature = _signature(file_id, expires_at)
    base = settings.public_base_url.rstrip("/")
    return f"{base}/media/{file_id}?exp={expires_at}&sig={signature}"


def verify_signature(file_id: str, expires_at: int | None, signature: str | None) -> int:
    """Return sisa detik masa berlaku, atau raise 403.

    Tanpa cek ini, id media (yang bisa muncul di log) cukup untuk membuka
    foto pribadi user.
    """
    if expires_at is None or not signature:
        raise ApiError(
            403, "MEDIA_URL_INVALID", "URL foto tidak memiliki tanda tangan"
        )
    expected = _signature(file_id, int(expires_at))
    if not hmac.compare_digest(expected, signature):
        raise ApiError(403, "MEDIA_URL_INVALID", "Tanda tangan URL foto tidak valid")
    remaining = int(expires_at) - int(time.time())
    if remaining <= 0:
        raise ApiError(403, "MEDIA_URL_EXPIRED", "URL foto sudah kedaluwarsa")
    return remaining


def _decode_data_uri(data: str) -> bytes:
    head, sep, raw = data.partition(",")
    if not sep or head not in _ALLOWED_PREFIXES:
        # Prefix menyatakan MIME, tapi isinya tetap divalidasi Pillow di bawah:
        # prefix "image/png" tidak menjamin byte-nya benar-benar PNG.
        raise ApiError(
            422, "INVALID_PHOTO", "Format foto harus data URI base64 (JPEG/PNG/WebP)"
        )

    # Sebagian library membungkus base64 per 76 karakter dengan newline.
    raw = raw.replace("\r", "").replace("\n", "")
    # Cek panjang string SEBELUM decode: base64 ~4/3 ukuran file, dan tanpa
    # cek ini satu request besar sudah mengalokasikan memorinya.
    if len(raw) > settings.media_max_input_chars:
        raise ApiError(413, "PHOTO_TOO_LARGE", "Foto terlalu besar")

    try:
        blob = base64.b64decode(raw, validate=True)
    except (binascii.Error, ValueError) as exc:
        raise ApiError(422, "INVALID_PHOTO", "Data foto tidak valid") from exc

    if not blob:
        raise ApiError(422, "INVALID_PHOTO", "Data foto kosong")
    if len(blob) > settings.media_max_bytes:
        raise ApiError(413, "PHOTO_TOO_LARGE", "Foto terlalu besar")
    return blob


def _normalize(blob: bytes) -> tuple[bytes, int, int]:
    """Validasi isi file, perbaiki orientasi, kecilkan, dan jadikan JPEG."""
    try:
        # verify() memastikan byte benar-benar gambar, sekaligus membuat objek
        # image tidak bisa dipakai lagi -> harus dibuka ulang untuk diproses.
        with Image.open(BytesIO(blob)) as probe:
            probe.verify()

        with Image.open(BytesIO(blob)) as img:
            img = ImageOps.exif_transpose(img)

            if img.mode in ("RGBA", "LA") or (
                img.mode == "P" and "transparency" in img.info
            ):
                # JPEG tidak punya alpha; tempel di atas putih, bukan hitam.
                rgba = img.convert("RGBA")
                background = Image.new("RGB", rgba.size, (255, 255, 255))
                background.paste(rgba, mask=rgba.getchannel("A"))
                img = background
            else:
                img = img.convert("RGB")

            img.thumbnail((MAX_SIDE, MAX_SIDE), Image.Resampling.LANCZOS)

            out = BytesIO()
            img.save(out, format="JPEG", quality=JPEG_QUALITY, optimize=True)
            return out.getvalue(), img.width, img.height
    except (UnidentifiedImageError, Image.DecompressionBombError) as exc:
        raise ApiError(422, "INVALID_PHOTO", "File bukan gambar yang valid") from exc
    except (OSError, ValueError) as exc:
        raise ApiError(422, "INVALID_PHOTO", "Gambar tidak bisa diproses") from exc


def probe(data: str) -> dict:
    """Validasi + kompres tanpa menyimpan. Dipakai mode dry-run migrasi."""
    blob = _decode_data_uri(data)
    jpeg, width, height = _normalize(blob)
    return {
        "width": width,
        "height": height,
        "size": len(jpeg),
        "original_size": len(blob),
    }


async def save_image(user: dict, data: str, kind: str = "offers") -> dict:
    # Dibatasi SEBELUM decode: satu akun tidak boleh mengisi Atlas M0 dengan
    # puluhan ribu foto.
    media_upload_counter.reserve(
        str(user["_id"]),
        settings.media_daily_upload_limit,
        "unggah foto",
        "MEDIA_RATE_LIMITED",
    )
    blob = _decode_data_uri(data)
    jpeg, width, height = _normalize(blob)
    now = utcnow()
    doc = {
        "owner_id": user["_id"],
        "kind": kind,
        "content_type": "image/jpeg",
        "data": Binary(jpeg),
        "size": len(jpeg),
        "original_size": len(blob),
        "width": width,
        "height": height,
        # Diisi saat foto dipakai offer/chat. Dipakai nanti oleh pembersih
        # file yatim (upload lalu batal), bukan oleh endpoint baca.
        "used_at": None,
        "created_at": now,
    }
    result = await db.media.insert_one(doc)

    file_id = str(result.inserted_id)
    return {
        "id": file_id,
        "url": public_url(file_id),
        "width": width,
        "height": height,
        "size": len(jpeg),
    }


def _object_id_or_404(value: str) -> ObjectId:
    try:
        return ObjectId(value)
    except (InvalidId, TypeError) as exc:
        raise ApiError(404, "MEDIA_NOT_FOUND", "Foto tidak ditemukan") from exc


async def load(file_id: str) -> dict:
    oid = _object_id_or_404(file_id)
    # Proyeksi wajib: tanpa ini setiap request membaca seluruh byte gambar.
    doc = await db.media.find_one(
        {"_id": oid}, {"data": 1, "content_type": 1, "size": 1}
    )
    if doc is None:
        raise ApiError(404, "MEDIA_NOT_FOUND", "Foto tidak ditemukan")
    return doc


async def load_blobs(photo_ids: list[str]) -> list[bytes]:
    """Ambil byte gambar untuk dikirim ke model AI.

    Pemanggil wajib sudah memvalidasi kepemilikan lewat require_owned_photos;
    di sini hanya urusan isi file.
    """
    if not photo_ids:
        return []

    docs = await db.media.find(
        {"_id": {"$in": [ObjectId(value) for value in photo_ids]}},
        {"data": 1},
    ).to_list(length=len(photo_ids))
    by_id = {str(doc["_id"]): bytes(doc["data"]) for doc in docs}

    blobs: list[bytes] = []
    for value in photo_ids:
        blob = by_id.get(value.lower())
        if blob is None:
            raise ApiError(422, "PHOTO_NOT_FOUND", "Foto tidak ditemukan")
        blobs.append(blob)
    return blobs


def normalize_ref(value: str) -> str:
    """Terima id media **atau** URL /media/<id>, kembalikan id 24 hex.

    Flutter sering mengirim balik URL yang diterima dari response sebelumnya,
    lengkap dengan ?exp=&sig=. Kalau string mentah itu disimpan, tanda
    tangannya ikut mati saat kedaluwarsa dan foto tidak bisa dibuka lagi.
    """
    raw = (value or "").strip()
    if is_media_id(raw):
        return raw.lower()

    if raw.lower().startswith("data:"):
        # Keputusan desain: base64 tidak pernah masuk DB. Pesan/offer hanya
        # menyimpan id, jadi client wajib upload dulu ke POST /media.
        raise ApiError(
            422,
            "PHOTO_NOT_UPLOADED",
            "Unggah foto lewat POST /media, lalu kirim id atau URL-nya",
        )

    parts = urlsplit(raw)
    # Host tidak diperiksa: yang diambil hanya id-nya, lalu kepemilikan tetap
    # divalidasi. Yang penting path-nya memang /media/<24 hex>.
    match = _MEDIA_PATH.fullmatch(parts.path)
    if match:
        return match.group(1).lower()

    raise ApiError(
        422,
        "PHOTO_REF_INVALID",
        "Foto harus berupa id media atau URL /media/<id>",
    )


def normalize_refs(values: list[str]) -> list[str]:
    ids = [normalize_ref(value) for value in values]
    if len(set(ids)) != len(ids):
        raise ApiError(422, "VALIDATION_ERROR", "Foto tidak boleh duplikat")
    return ids


async def resolve_photos(user: dict, refs: list[str]) -> list[str]:
    """Normalisasi id/URL lalu pastikan semuanya milik user ini."""
    if not refs:
        return []
    return await require_owned_photos(user, normalize_refs(refs))


async def require_owned_photos(user: dict, photo_ids: list[str]) -> list[str]:
    """Pastikan setiap id ada, milik user ini, dan tidak duplikat.

    Tanpa cek owner, user A bisa menempelkan id foto user B ke offer-nya.
    """
    if len(set(photo_ids)) != len(photo_ids):
        raise ApiError(422, "VALIDATION_ERROR", "Foto tidak boleh duplikat")

    oids: list[ObjectId] = []
    for value in photo_ids:
        if not is_media_id(value):
            raise ApiError(422, "VALIDATION_ERROR", "ID foto tidak valid")
        oids.append(ObjectId(value))

    docs = await db.media.find(
        {"_id": {"$in": oids}, "owner_id": user["_id"]}, {"_id": 1}
    ).to_list(length=len(oids))

    found = {str(doc["_id"]) for doc in docs}
    missing = [value for value in photo_ids if value.lower() not in found]
    if missing:
        # Pesan sengaja tidak menyebut id mana yang gagal, supaya tidak
        # membocorkan keberadaan foto milik user lain.
        raise ApiError(
            422, "PHOTO_NOT_FOUND", "Foto tidak ditemukan atau bukan milik Anda"
        )

    # Pertahankan urutan pilihan user: foto pertama tetap photos[0].
    return [value.lower() for value in photo_ids]


async def mark_used(photo_ids: list[str]) -> None:
    if not photo_ids:
        return
    await db.media.update_many(
        {"_id": {"$in": [ObjectId(value) for value in photo_ids]}},
        {"$set": {"used_at": utcnow()}},
    )
