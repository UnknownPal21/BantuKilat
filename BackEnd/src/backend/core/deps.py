from bson import ObjectId
from bson.errors import InvalidId
from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt import InvalidTokenError

from backend.core.errors import ApiError
from backend.core.security import decode_token
from backend.db.mongo import db


# auto_error=False supaya request tanpa header tidak dibalas 403 {"detail": ...}
# milik HTTPBearer, tapi 401 {"code", "message"} milik kita.
_bearer = HTTPBearer(auto_error=False)


def _unauthorized() -> ApiError:
    # Satu pesan untuk semua penyebab: header hilang, token rusak, token
    # kedaluwarsa, sub bukan hex, user tidak ada, user tidak aktif.
    # Membedakan pesannya akan membocorkan status akun.
    return ApiError(401, "UNAUTHORIZED", "Sesi tidak valid")


async def get_current_user(
    cred: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> dict:
    if cred is None:
        raise _unauthorized()

    try:
        payload = decode_token(cred.credentials)
    except InvalidTokenError as exc:
        # InvalidTokenError adalah induk dari ExpiredSignatureError,
        # InvalidSignatureError, DecodeError, InvalidAudienceError, dst.
        raise _unauthorized() from exc

    sub = payload.get("sub")
    if not isinstance(sub, str):
        raise _unauthorized()

    try:
        user_id = ObjectId(sub)
    except (InvalidId, TypeError) as exc:
        raise _unauthorized() from exc

    user = await db.users.find_one({"_id": user_id})
    if user is None or not user.get("is_active"):
        raise _unauthorized()

    return user


def require_role(*roles: str):
    """Dependency factory: `Depends(require_role("TECHNICIAN"))`.

    Role diambil dari dokumen user, bukan dari claim token, supaya perubahan
    role langsung berlaku tanpa menunggu token lama kedaluwarsa.
    """

    async def checker(user: dict = Depends(get_current_user)) -> dict:
        if user.get("role") not in roles:
            raise ApiError(403, "FORBIDDEN", "Akses ditolak")
        return user

    return checker
