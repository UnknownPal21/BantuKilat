from datetime import datetime, timedelta, timezone
from uuid import uuid4

from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError
from jwt import decode, encode

from backend.core.config import settings

hasher = PasswordHasher()


def hash_password(password: str) -> str:
    return hasher.hash(password)


def verify_password(password: str, hashed_password: str) -> bool:
    try:
        hasher.verify(hashed_password, password)
    except (VerificationError, InvalidHashError):
        return False
    return True


def create_access_token(user_id: str, role: str) -> str:
    now = datetime.now(timezone.utc)
    return encode(
        {
            "sub": user_id,
            "role": role,
            "iat": now,
            "jti": uuid4().hex,
            "exp": now + timedelta(minutes=settings.jwt_expire_minutes),
            "iss": "bantukilat-api",
            "aud": "bantukilat-app",
        },
        settings.jwt_secret,
        algorithm="HS256",
    )


def decode_token(token: str) -> dict:
    return decode(
        token,
        settings.jwt_secret,
        algorithms=["HS256"],
        audience="bantukilat-app",
        issuer="bantukilat-api",
    )
