from datetime import datetime, timezone

from pymongo.errors import DuplicateKeyError

from backend.core.config import settings
from backend.core.errors import ApiError
from backend.core.security import create_access_token, hash_password, verify_password
from backend.db.mongo import db, users
from backend.models.auth import LoginIn, RegisterIn

# Dummy hash untuk menyamakan waktu respons saat email tidak ditemukan.
# Dibuat sekali di level modul, bukan per request.
_DUMMY_HASH = hash_password("dummy-password-for-timing")


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _token_response(doc: dict) -> dict:
    # ObjectId tidak bisa di-serialize FastAPI -> wajib str()
    user_id = str(doc["_id"])
    return {
        "access_token": create_access_token(user_id, doc["role"]),
        "token_type": "bearer",
        "expires_in": settings.jwt_expire_minutes * 60,
        "user": {
            "_id": user_id,
            "role": doc["role"],
            "name": doc["name"],
            "email": doc["email"],
            "phone": doc["phone"],
            "avatar_url": doc.get("avatar_url"),
        },
        "needs_phone": not doc.get("phone"),
    }


def _map_duplicate(exc: DuplicateKeyError) -> ApiError:
    # index mana yang bentrok: email / phone / google_sub
    key = exc.details.get("keyPattern", {}) if exc.details else {}
    if "email" in key:
        return ApiError(409, "EMAIL_TAKEN", "Email sudah terdaftar")
    if "phone" in key:
        return ApiError(409, "PHONE_TAKEN", "Nomor WhatsApp sudah terdaftar")
    return ApiError(409, "DUPLICATE", "Data sudah terdaftar")


async def register(payload: RegisterIn) -> dict:
    email = payload.email.strip().lower()
    now = _now()

    # Cek awal: pesan error lebih ramah. BUKAN pengganti unique index.
    if await db.users.find_one({"email": email}, {"_id": 1}):
        raise ApiError(409, "EMAIL_TAKEN", "Email sudah terdaftar")
    if await db.users.find_one({"phone": payload.phone}, {"_id": 1}):
        raise ApiError(409, "PHONE_TAKEN", "Nomor WhatsApp sudah terdaftar")

    doc = {
        "role": payload.role,
        "name": payload.name,
        "email": email,
        "phone": payload.phone,
        "password_hash": hash_password(payload.password),
        "google_sub": None,
        "avatar_url": None,
        "address": {
            "city": payload.city,
            "district": payload.district,  # perhatikan: "district", bukan "districk"
            "rt": None,
            "rw": None,
            "text": None,
        },
        "location": None,
        "tech": {"skills": payload.skills} if payload.role == "TECHNICIAN" else None,
        "password_reset": None,
        "terms_accepted_at": now if payload.terms_accepted else None,
        "is_active": True,
        "created_at": now,
        "updated_at": now,
    }

    try:
        result = await db.users.insert_one(doc)
    except DuplicateKeyError as exc:
        # Race: dua request lolos cek di atas lalu insert bersamaan.
        raise _map_duplicate(exc) from exc

    doc["_id"] = result.inserted_id
    return _token_response(doc)


async def login(payload: LoginIn) -> dict:
    email = payload.email.strip().lower()
    user = await db.users.find_one({"email": email})

    if user is None:
        # Tetap jalankan verify agar waktu respons serupa (anti timing attack)
        verify_password(payload.password, _DUMMY_HASH)
        raise ApiError(401, "INVALID_CREDENTIALS", "Email atau password salah")

    stored = user.get("password_hash")
    if stored is None:
        # akun Google-only: pesan identik, jangan bocorkan
        raise ApiError(401, "INVALID_CREDENTIALS", "Email atau password salah")

    if not verify_password(payload.password, stored):
        raise ApiError(401, "INVALID_CREDENTIALS", "Email atau password salah")

    if not user.get("is_active"):
        raise ApiError(403, "ACCOUNT_DISABLED", "Akun dinonaktifkan")

    return _token_response(user)
