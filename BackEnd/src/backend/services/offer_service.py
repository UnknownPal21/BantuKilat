from datetime import datetime, timedelta, timezone

from bson import ObjectId
from bson.errors import InvalidId

from backend.core.errors import ApiError
from backend.db.mongo import db
from backend.models.offer import OfferCreateIn, OfferStatus

# Server yang menentukan fee, bukan client (spec §4 aturan bisnis).
SOS_FEE = 10_000
OFFER_TTL_MINUTES = 30

# Radar teknisi hanya menampilkan offer yang masih bisa ditawar.
NEARBY_STATUSES: list[OfferStatus] = ["WAITING", "NEGOTIATING"]


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _iso(value: datetime) -> str:
    # pymongo mengembalikan datetime naive (tz_aware=False), padahal nilainya UTC.
    # Tanpa tzinfo, Flutter membacanya sebagai waktu lokal.
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.isoformat().replace("+00:00", "Z")


def _object_id(value: str, field: str) -> ObjectId:
    try:
        return ObjectId(value)
    except (InvalidId, TypeError) as exc:
        raise ApiError(422, "VALIDATION_ERROR", f"{field} tidak valid") from exc


def _offer_response(doc: dict) -> dict:
    accepted_bid_id = doc.get("accepted_bid_id")
    technician_id = doc.get("technician_id")

    return {
        "_id": str(doc["_id"]),
        "requester_id": str(doc["requester_id"]),
        "requester_snapshot": doc.get("requester_snapshot") or {},
        "category_id": str(doc["category_id"]),
        "category_snapshot": doc.get("category_snapshot") or {},
        "title": doc["title"],
        "description": doc["description"],
        "photos": doc.get("photos") or [],
        "location": doc["location"],
        "address_text": doc.get("address_text", ""),
        "geo_index": doc.get("geo_index"),
        "is_sos": bool(doc.get("is_sos")),
        "sos_fee": doc.get("sos_fee", 0),
        "initial_budget": doc.get("initial_budget", 0),
        "agreed_price": doc.get("agreed_price"),
        "status": doc["status"],
        "accepted_bid_id": str(accepted_bid_id) if accepted_bid_id else None,
        "technician_id": str(technician_id) if technician_id else None,
        "bid_count": doc.get("bid_count", 0),
        "created_at": _iso(doc["created_at"]),
        "updated_at": _iso(doc["updated_at"]),
        "expires_at": _iso(doc["expires_at"]),
        # distance_m hanya ada kalau dokumen lewat $geoNear.
        "distance_m": round(doc["distance_m"]) if "distance_m" in doc else None,
    }


async def create(user: dict, payload: OfferCreateIn) -> dict:
    category = await db.categories.find_one(
        {"_id": _object_id(payload.category_id, "category_id"), "is_active": True}
    )
    if category is None:
        raise ApiError(
            422, "CATEGORY_NOT_FOUND", "Kategori tidak ditemukan atau tidak aktif"
        )

    now = _now()
    address = user.get("address") or {}

    doc = {
        "requester_id": user["_id"],
        # Snapshot: daftar offer tidak perlu lookup users, dan tetap benar
        # walau nama user berubah setelah offer dibuat.
        "requester_snapshot": {
            "name": user["name"],
            "avatar_url": user.get("avatar_url"),
            "rt": address.get("rt"),
            "rw": address.get("rw"),
        },
        "category_id": category["_id"],
        "category_snapshot": {
            "code": category["code"],
            "label": category["label"],
            "icon": category["icon"],
        },
        "title": payload.title,
        "description": payload.description,
        "photos": payload.photos,
        # GeoJSON selalu [lng, lat] — bukan [lat, lng].
        "location": {"type": "Point", "coordinates": [payload.lng, payload.lat]},
        "address_text": payload.address_text,
        "geo_index": {
            "rt": address.get("rt"),
            "rw": address.get("rw"),
            "district": address.get("district"),
            "city": address.get("city"),
        },
        "is_sos": payload.is_sos,
        "sos_fee": SOS_FEE if payload.is_sos else 0,
        "initial_budget": payload.initial_budget,
        "agreed_price": None,
        # Offer baru belum punya bid -> WAITING, bukan NEGOTIATING.
        "status": "WAITING",
        "accepted_bid_id": None,
        "technician_id": None,
        "bid_count": 0,
        "created_at": now,
        "updated_at": now,
        "expires_at": now + timedelta(minutes=OFFER_TTL_MINUTES),
        "assigned_at": None,
        "completed_at": None,
        "cancel_reason": None,
    }

    result = await db.offers.insert_one(doc)
    doc["_id"] = result.inserted_id
    return _offer_response(doc)


async def nearby(
    lng: float,
    lat: float,
    radius: int,
    category: str | None,
    sos: bool | None,
    limit: int,
) -> list[dict]:
    match: dict = {
        "status": {"$in": NEARBY_STATUSES},
        # Cron EXPIRED belum ada; jangan tampilkan offer yang sudah lewat
        # masa berlaku walau statusnya masih WAITING/NEGOTIATING.
        "expires_at": {"$gt": _now()},
    }

    if category:
        found = await db.categories.find_one({"code": category.upper()}, {"_id": 1})
        if found is None:
            raise ApiError(422, "CATEGORY_NOT_FOUND", "Kode kategori tidak dikenal")
        match["category_id"] = found["_id"]

    # None = tidak memfilter; False/True = filter eksplisit.
    if sos is not None:
        match["is_sos"] = sos

    pipeline = [
        {
            "$geoNear": {
                "near": {"type": "Point", "coordinates": [lng, lat]},
                # $geoNear wajib jadi stage pertama dan sekaligus mengurutkan
                # hasil dari yang terdekat.
                "distanceField": "distance_m",
                "maxDistance": radius,
                "query": match,
                "spherical": True,
                "key": "location",
            }
        },
        {"$limit": limit},
    ]

    cursor = await db.offers.aggregate(pipeline)
    docs = await cursor.to_list(length=limit)
    return [_offer_response(doc) for doc in docs]


async def mine(user: dict, status: OfferStatus | None, limit: int) -> list[dict]:
    query: dict = {"requester_id": user["_id"]}
    if status is not None:
        query["status"] = status

    cursor = db.offers.find(query).sort("created_at", -1).limit(limit)
    docs = await cursor.to_list(length=limit)
    return [_offer_response(doc) for doc in docs]
