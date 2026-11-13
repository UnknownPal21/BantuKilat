from bson import ObjectId
from bson.errors import InvalidId
from pymongo import ReturnDocument
from pymongo.errors import DuplicateKeyError

from backend.core.errors import ApiError
from backend.core.timeutils import as_utc, iso_utc, utcnow
from backend.db.mongo import db
from backend.models.bid import BidCreateIn, BidStatus
from backend.services import offer_service
from backend.services.offer_service import offer_id_or_404


def bid_id_or_404(value: str) -> ObjectId:
    try:
        return ObjectId(value)
    except (InvalidId, TypeError) as exc:
        raise ApiError(404, "BID_NOT_FOUND", "Penawaran tidak ditemukan") from exc


def _bid_response(doc: dict) -> dict:
    accepted_at = doc.get("accepted_at")
    updated_at = doc.get("updated_at")

    return {
        "_id": str(doc["_id"]),
        "offer_id": str(doc["offer_id"]),
        "technician_id": str(doc["technician_id"]),
        "technician_snapshot": doc.get("technician_snapshot") or {},
        "amount": doc.get("amount", 0),
        "message": doc.get("message"),
        "status": doc["status"],
        "accepted_at": iso_utc(accepted_at) if accepted_at else None,
        "created_at": iso_utc(doc["created_at"]),
        "updated_at": iso_utc(updated_at) if updated_at else None,
    }


async def list_for_offer(
    user: dict,
    offer_id: str,
    status: BidStatus | None,
    limit: int,
) -> list[dict]:
    oid = offer_id_or_404(offer_id)

    offer = await db.offers.find_one({"_id": oid}, {"requester_id": 1})
    if offer is None:
        raise ApiError(404, "OFFER_NOT_FOUND", "Tawaran tidak ditemukan")

    query: dict = {"offer_id": oid}
    if user["_id"] != offer["requester_id"]:
        # Teknisi hanya melihat bid miliknya sendiri. Kalau semua teknisi bisa
        # melihat harga pesaing, mereka tinggal mengirim satu rupiah lebih murah.
        query["technician_id"] = user["_id"]

    if status is not None:
        query["status"] = status

    cursor = db.bids.find(query).sort("created_at", -1).limit(limit)
    docs = await cursor.to_list(length=limit)
    return [_bid_response(doc) for doc in docs]


async def place_bid(user: dict, offer_id: str, payload: BidCreateIn) -> dict:
    oid = offer_id_or_404(offer_id)
    now = utcnow()

    offer = await db.offers.find_one(
        {"_id": oid}, {"requester_id": 1, "status": 1, "expires_at": 1}
    )
    if offer is None:
        raise ApiError(404, "OFFER_NOT_FOUND", "Tawaran tidak ditemukan")
    if offer["requester_id"] == user["_id"]:
        raise ApiError(403, "BID_OWN_OFFER", "Tidak bisa menawar tawaran sendiri")

    expires_at = offer.get("expires_at")
    if expires_at is not None and as_utc(expires_at) <= now:
        # Cron EXPIRED belum ada; tolak di sini supaya offer mati tidak
        # bisa ditawar.
        raise ApiError(409, "OFFER_EXPIRED", "Tawaran sudah kedaluwarsa")
    if offer["status"] not in ("WAITING", "NEGOTIATING"):
        raise ApiError(409, "OFFER_NOT_OPEN", "Tawaran sudah tidak menerima penawaran")

    tech = user.get("tech") or {}
    snapshot = {
        "name": user["name"],
        "avatar_url": user.get("avatar_url"),
        "rating": tech.get("rating"),
    }

    # Upsert: teknisi yang sudah punya bid PENDING mengubah nominal, bukan
    # membuat dokumen kedua. Index unik parsial {offer_id, technician_id} +
    # status PENDING yang menjaganya saat dua request datang bersamaan.
    try:
        result = await db.bids.update_one(
            {
                "offer_id": oid,
                "technician_id": user["_id"],
                "status": "PENDING",
            },
            {
                "$set": {
                    "amount": payload.amount,
                    "message": payload.message,
                    "technician_snapshot": snapshot,
                    "updated_at": now,
                },
                "$setOnInsert": {
                    "status": "PENDING",
                    "accepted_at": None,
                    "created_at": now,
                },
            },
            upsert=True,
        )
    except DuplicateKeyError as exc:
        raise ApiError(409, "BID_ALREADY_EXISTS", "Penawaran sudah terkirim") from exc

    is_new = result.upserted_id is not None

    # Guard + efek samping dalam satu operasi. Kalau offer ditutup di antara
    # cek di atas dan titik ini, find_one_and_update mengembalikan None.
    offer_update: dict = {"$set": {"status": "NEGOTIATING", "updated_at": now}}
    if is_new:
        offer_update["$inc"] = {"bid_count": 1}

    updated_offer = await db.offers.find_one_and_update(
        {"_id": oid, "status": {"$in": ["WAITING", "NEGOTIATING"]}},
        offer_update,
        return_document=ReturnDocument.AFTER,
    )
    if updated_offer is None:
        # Batalkan bid yang baru saja dibuat supaya tidak ada bid yatim.
        if is_new:
            await db.bids.delete_one({"_id": result.upserted_id})
        raise ApiError(409, "OFFER_NOT_OPEN", "Tawaran sudah tidak menerima penawaran")

    bid = await db.bids.find_one(
        {"offer_id": oid, "technician_id": user["_id"], "status": "PENDING"}
    )
    return _bid_response(bid)


async def accept(user: dict, bid_id: str) -> dict:
    bid_oid = bid_id_or_404(bid_id)
    now = utcnow()

    bid = await db.bids.find_one({"_id": bid_oid})
    if bid is None:
        raise ApiError(404, "BID_NOT_FOUND", "Penawaran tidak ditemukan")

    offer_oid = bid["offer_id"]
    offer = await db.offers.find_one({"_id": offer_oid})
    if offer is None:
        raise ApiError(404, "OFFER_NOT_FOUND", "Tawaran tidak ditemukan")

    if offer["requester_id"] != user["_id"]:
        raise ApiError(
            403,
            "NOT_OFFER_OWNER",
            "Hanya pembuat tawaran yang bisa memilih penawaran",
        )

    # Pesan dipisah supaya UI tahu apa yang terjadi, bukan satu "gagal" generik.
    if offer["status"] == "ASSIGNED":
        raise ApiError(
            409, "OFFER_ALREADY_ASSIGNED", "Tawaran sudah diambil teknisi lain"
        )
    if offer["status"] != "NEGOTIATING":
        raise ApiError(409, "OFFER_NOT_OPEN", "Tawaran tidak sedang dalam negosiasi")

    expires_at = offer.get("expires_at")
    if expires_at is not None and as_utc(expires_at) <= now:
        raise ApiError(409, "OFFER_EXPIRED", "Tawaran sudah kedaluwarsa")

    if bid["status"] != "PENDING":
        raise ApiError(409, "BID_NOT_PENDING", "Penawaran ini sudah tidak aktif")

    # Klaim offer lebih dulu. Filter status + accepted_bid_id dievaluasi saat
    # penulisan, jadi dua request accept bersamaan hanya satu yang menang.
    claimed = await db.offers.find_one_and_update(
        {"_id": offer_oid, "status": "NEGOTIATING", "accepted_bid_id": None},
        {
            "$set": {
                "status": "ASSIGNED",
                "accepted_bid_id": bid_oid,
                "technician_id": bid["technician_id"],
                # spec §4: agreed_price = bids.amount, tanpa sos_fee.
                "agreed_price": bid["amount"],
                "assigned_at": now,
                "updated_at": now,
            }
        },
        return_document=ReturnDocument.AFTER,
    )
    if claimed is None:
        raise ApiError(
            409, "OFFER_ALREADY_ASSIGNED", "Tawaran sudah diambil teknisi lain"
        )

    accepted = await db.bids.find_one_and_update(
        {"_id": bid_oid, "status": "PENDING"},
        {"$set": {"status": "ACCEPTED", "accepted_at": now, "updated_at": now}},
        return_document=ReturnDocument.AFTER,
    )
    if accepted is None:
        # Bid berubah status di antara cek dan klaim -> kembalikan offer,
        # jangan tinggalkan offer ASSIGNED tanpa bid pemenang.
        await db.offers.update_one(
            {"_id": offer_oid, "accepted_bid_id": bid_oid},
            {
                "$set": {
                    "status": "NEGOTIATING",
                    "accepted_bid_id": None,
                    "technician_id": None,
                    "agreed_price": None,
                    "assigned_at": None,
                    "updated_at": now,
                }
            },
        )
        raise ApiError(409, "BID_NOT_PENDING", "Penawaran ini sudah tidak aktif")

    # Sisa bid aktif untuk offer ini kalah.
    await db.bids.update_many(
        {"offer_id": offer_oid, "_id": {"$ne": bid_oid}, "status": "PENDING"},
        {"$set": {"status": "REJECTED", "updated_at": now}},
    )

    return await offer_service.get(str(offer_oid))
