from datetime import datetime, timezone


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def as_utc(value: datetime) -> datetime:
    # pymongo mengembalikan datetime naive (tz_aware=False), padahal nilainya
    # UTC. Tempelkan tzinfo sebelum membandingkan atau men-serialisasi.
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value


def iso_utc(value: datetime) -> str:
    return as_utc(value).isoformat().replace("+00:00", "Z")
