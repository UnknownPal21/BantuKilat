from datetime import timedelta

from bson import ObjectId
from bson.errors import InvalidId
from pymongo import ReturnDocument

from backend.core.errors import ApiError
from backend.core.timeutils import iso_utc, utcnow
from backend.db.mongo import db
from backend.models.offer import OfferCancelIn, OfferCreateIn, OfferStatus
from backend.services import ai_client, media_service, price_service

# Server yang menentukan fee, bukan client (spec §4 aturan bisnis).
SOS_FEE = 10_000
OFFER_TTL_MINUTES = 30

# Di bawah ini bukan harga jasa wajar; jangan kotori katalog dengan nominal
# uji coba.
MIN_DEAL_FOR_SAMPLE = 5_000

# Radar teknisi hanya menampilkan offer yang masih bisa ditawar.
NEARBY_STATUSES: list[OfferStatus] = ["WAITING", "NEGOTIATING"]


def _object_id(value: str, field: str) -> ObjectId:
    try:
        return ObjectId(value)
    except (InvalidId, TypeError) as exc:
        raise ApiError(422, "VALIDATION_ERROR", f"{field} tidak valid") from exc


def offer_id_or_404(value: str) -> ObjectId:
    """Untuk id di path URL: bentuk salah tetap 404, bukan 422."""
    try:
        return ObjectId(value)
    except (InvalidId, TypeError) as exc:
        raise ApiError(404, "OFFER_NOT_FOUND", "Tawaran tidak ditemukan") from exc



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
        "photos": [
            # Hanya id media yang bisa dijadikan URL. Data lama berupa path
            # atau data URI base64 dibuang: mengembalikannya utuh bisa
            # membuat satu response berukuran megabyte.
            media_service.public_url(p)
            for p in doc.get("photos") or []
            if media_service.is_media_id(p)
        ],
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
        "created_at": iso_utc(doc["created_at"]),
        "updated_at": iso_utc(doc["updated_at"]),
        "expires_at": iso_utc(doc["expires_at"]),
        "assigned_at": iso_utc(doc["assigned_at"]) if doc.get("assigned_at") else None,
        "completed_at": iso_utc(doc["completed_at"]) if doc.get("completed_at") else None,
        "cancelled_at": iso_utc(doc["cancelled_at"]) if doc.get("cancelled_at") else None,
        "cancel_reason": doc.get("cancel_reason"),
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

    # Setiap id/URL dinormalisasi ke id, lalu harus ada di collection media
    # dan milik user ini.
    photos = await media_service.resolve_photos(user, payload.photos)

    now = utcnow()
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
        "photos": photos,
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
        "cancelled_at": None,
    }

    result = await db.offers.insert_one(doc)
    doc["_id"] = result.inserted_id
    # Baru setelah offer benar-benar tersimpan, foto ditandai terpakai.
    await media_service.mark_used(photos)
    return _offer_response(doc)


async def get(offer_id: str) -> dict:
    doc = await db.offers.find_one({"_id": offer_id_or_404(offer_id)})
    if doc is None:
        raise ApiError(404, "OFFER_NOT_FOUND", "Tawaran tidak ditemukan")
    return _offer_response(doc)


async def complete(user: dict, offer_id: str) -> dict:
    """Tandai offer selesai dan catat satu sampel harga.

    Retry aman: kalau pemanggilan pertama sudah mengubah status tapi gagal
    setelahnya (mis. timeout jaringan), percobaan kedua tidak boleh menjawab
    409 begitu saja. Kalau offer sudah COMPLETED **oleh teknisi yang sama**,
    langkah yang belum selesai diulang sampai benar-benar konsisten.
    """
    oid = offer_id_or_404(offer_id)
    now = utcnow()

    # Filter ikut memastikan yang menekan tombol adalah teknisi pemenang.
    # Kalau dua request datang bersamaan, hanya satu yang mengubah dokumen.
    updated = await db.offers.find_one_and_update(
        {"_id": oid, "status": "ASSIGNED", "technician_id": user["_id"]},
        {
            "$set": {
                "status": "COMPLETED",
                "completed_at": now,
                "updated_at": now,
            }
        },
        return_document=ReturnDocument.AFTER,
    )

    if updated is None:
        # Tidak ada dokumen yang cocok -> cari tahu sebabnya untuk pesan yang tepat.
        offer = await db.offers.find_one({"_id": oid})
        if offer is None:
            raise ApiError(404, "OFFER_NOT_FOUND", "Tawaran tidak ditemukan")
        if offer.get("status") == "COMPLETED":
            if offer.get("technician_id") != user["_id"]:
                raise ApiError(
                    409, "OFFER_ALREADY_COMPLETED", "Tawaran sudah diselesaikan"
                )
            # Sudah selesai oleh user ini: selesaikan sisa pekerjaan idempoten
            # (sampel harga & penghitung teknisi) lalu kembalikan apa adanya.
            await _ensure_completion_side_effects(offer)
            return _offer_response(offer)
        if offer.get("status") != "ASSIGNED":
            raise ApiError(409, "OFFER_NOT_ASSIGNED", "Tawaran belum ditugaskan")
        raise ApiError(
            403,
            "NOT_ASSIGNED_TECHNICIAN",
            "Hanya teknisi yang ditugaskan bisa menyelesaikan",
        )

    # Statistik teknisi hanya naik pada transisi ASSIGNED -> COMPLETED, jadi
    # letaknya di sini (bukan di _ensure_completion_side_effects) supaya
    # pemanggilan ulang tidak menghitung dua kali.
    await db.users.update_one(
        {"_id": user["_id"]}, {"$inc": {"tech.completed_count": 1}}
    )
    await _ensure_completion_side_effects(updated)

    return _offer_response(updated)


async def _ensure_completion_side_effects(offer: dict) -> None:
    """Langkah setelah COMPLETED yang aman diulang.

    Harga deal ikut memperkaya katalog: AI yang sama memakai data ini pada
    percakapan berikutnya. `record_sample` sudah idempoten lewat unique index
    parsial `offer_id`, jadi memanggilnya berkali-kali tidak menggandakan
    sampel.
    """
    await _record_deal_sample(offer)


async def cancel(user: dict, offer_id: str, payload: OfferCancelIn) -> dict:
    """User membatalkan tawarannya sendiri.

    Hanya boleh selama belum ada teknisi yang ditugaskan. Setelah `ASSIGNED`
    teknisi sudah menolak pekerjaan lain demi tawaran ini, jadi pembatalan
    harus lewat jalur lain (belum ada) — bukan diam-diam di sini.
    """
    oid = offer_id_or_404(offer_id)
    now = utcnow()

    # Guard pada status ikut di filter penulisan, bukan hanya dicek dulu:
    # dua request bersamaan tidak bisa sama-sama berhasil.
    updated = await db.offers.find_one_and_update(
        {
            "_id": oid,
            "requester_id": user["_id"],
            "status": {"$in": ["WAITING", "NEGOTIATING"]},
        },
        {
            "$set": {
                "status": "CANCELLED",
                "cancel_reason": payload.reason,
                "cancelled_at": now,
                "updated_at": now,
            }
        },
        return_document=ReturnDocument.AFTER,
    )

    if updated is None:
        offer = await db.offers.find_one(
            {"_id": oid}, {"requester_id": 1, "status": 1}
        )
        if offer is None:
            raise ApiError(404, "OFFER_NOT_FOUND", "Tawaran tidak ditemukan")
        if offer["requester_id"] != user["_id"]:
            raise ApiError(
                403, "NOT_OFFER_OWNER", "Hanya pembuat tawaran yang bisa membatalkan"
            )
        if offer["status"] == "CANCELLED":
            # Menekan tombol dua kali bukan error yang perlu ditakuti user.
            return await get(offer_id)
        if offer["status"] == "EXPIRED":
            raise ApiError(409, "OFFER_EXPIRED", "Tawaran sudah kedaluwarsa")
        if offer["status"] == "ASSIGNED":
            raise ApiError(
                409,
                "OFFER_ALREADY_ASSIGNED",
                "Tawaran sudah diambil teknisi dan tidak bisa dibatalkan",
            )
        raise ApiError(
            409, "OFFER_NOT_CANCELLABLE", "Tawaran ini tidak bisa dibatalkan"
        )

    # Bid yang masih menunggu tidak boleh menggantung: teknisinya perlu tahu
    # bahwa tawarannya tidak akan pernah dipilih.
    await db.bids.update_many(
        {"offer_id": oid, "status": "PENDING"},
        {"$set": {"status": "WITHDRAWN", "updated_at": now}},
    )
    await _refresh_bid_count(oid, now)

    return _offer_response(updated)


async def expire_overdue(limit: int = 500) -> int:
    """Ubah offer lewat `expires_at` menjadi EXPIRED.

    Dipanggil dari job periodik. Selama ini offer mati hanya *disaring* di
    query (`nearby`, `place_bid`, `accept`), sehingga dokumennya tetap
    berstatus WAITING/NEGOTIATING di database: daftar "tawaran saya" user
    menampilkan tawaran yang sebenarnya sudah mati, dan bid di dalamnya
    menggantung PENDING selamanya.

    Mengembalikan jumlah offer yang berubah status.
    """
    now = utcnow()
    cursor = db.offers.find(
        {
            "status": {"$in": NEARBY_STATUSES},
            "expires_at": {"$lte": now},
        },
        {"_id": 1},
    ).limit(limit)
    ids = [doc["_id"] async for doc in cursor]
    if not ids:
        return 0

    # Filter status diulang di sini: offer bisa saja baru saja di-accept
    # teknisi di antara pembacaan di atas dan penulisan ini.
    result = await db.offers.update_many(
        {
            "_id": {"$in": ids},
            "status": {"$in": NEARBY_STATUSES},
            "expires_at": {"$lte": now},
        },
        {
            "$set": {
                "status": "EXPIRED",
                "cancelled_at": now,
                "cancel_reason": "KEDALUWARSA",
                "updated_at": now,
            }
        },
    )
    if result.modified_count:
        await db.bids.update_many(
            {
                "offer_id": {"$in": ids},
                "status": "PENDING",
            },
            {"$set": {"status": "EXPIRED", "updated_at": now}},
        )
    return result.modified_count


async def _refresh_bid_count(offer_id: ObjectId, now) -> None:
    """Hitung ulang bid_count dari bid PENDING.

    Dihitung ulang, bukan dikurangi satu-satu, supaya angka tidak pernah
    menyimpang walau ada withdraw/reject di jalur lain.
    """
    count = await db.bids.count_documents({"offer_id": offer_id, "status": "PENDING"})
    await db.offers.update_one(
        {"_id": offer_id},
        {"$set": {"bid_count": count, "updated_at": now}},
    )


async def sync_after_bid_change(offer_id: ObjectId, now) -> int:
    """Samakan status offer & bid_count setelah bid berubah (withdraw/reject).

    Kalau bid PENDING terakhir hilang, offer kembali ke WAITING. Tanpa ini
    tawaran tetap berstatus NEGOTIATING padahal tidak ada yang ditawar dan
    tidak bisa ditawar lagi oleh teknisi baru.

    Filter status di penulisan menjaga offer yang baru saja di-accept tidak
    ikut diturunkan kembali.
    """
    pending = await db.bids.count_documents(
        {"offer_id": offer_id, "status": "PENDING"}
    )
    await db.offers.update_one(
        {
            "_id": offer_id,
            "status": {"$in": ["WAITING", "NEGOTIATING"]},
        },
        {
            "$set": {
                "bid_count": pending,
                "status": "NEGOTIATING" if pending else "WAITING",
                "updated_at": now,
            }
        },
    )
    return pending


async def _record_deal_sample(offer: dict) -> None:
    price = offer.get("agreed_price")
    code = (offer.get("category_snapshot") or {}).get("code")
    if not price or not code or int(price) < MIN_DEAL_FOR_SAMPLE:
        return

    # Offer tidak menyimpan severity (AI memang tidak mengisi form), jadi
    # keparahan diturunkan dari teksnya. Kalau meleset, dampaknya hanya
    # distribusi harga yang sedikit bergeser, bukan data offer yang berubah.
    severity = ai_client.guess_severity(
        f"{offer.get('title', '')} {offer.get('description', '')}"
    )
    city = (offer.get("geo_index") or {}).get("city")

    recorded = await price_service.record_sample(
        code, severity, city, int(price), "DEAL", offer["_id"]
    )
    if recorded:
        await price_service.refresh(code, severity)


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
        "expires_at": {"$gt": utcnow()},
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


async def tasks(
    user: dict,
    status: OfferStatus | None,
    limit: int,
) -> list[dict]:
    """Tawaran yang ditugaskan ke teknisi ini.

    Endpoint terpisah, bukan filter di `/offers/nearby`: nearby sengaja hanya
    berisi offer terbuka (WAITING/NEGOTIATING) untuk radar bid. Tanpa endpoint
    ini, tugas yang sudah ASSIGNED/COMPLETED tidak pernah bisa ditampilkan.
    """
    query: dict = {"technician_id": user["_id"]}
    if status is not None:
        query["status"] = status

    cursor = db.offers.find(query).sort("updated_at", -1).limit(limit)
    docs = await cursor.to_list(length=limit)
    return [_offer_response(doc) for doc in docs]
