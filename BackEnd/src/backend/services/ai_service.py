import re
from datetime import datetime, timedelta

from bson import ObjectId
from bson.errors import InvalidId
from pymongo import ReturnDocument
from pymongo.errors import DuplicateKeyError

from backend.core.config import settings
from backend.core.errors import ApiError
from backend.core.timeutils import as_utc, iso_utc, utcnow
from backend.db.mongo import db
from backend.models.ai import (
    ChatCreateIn,
    EstimateIn,
    MessageIn,
)
from backend.services import ai_client, media_service, price_service

TITLE_LENGTH = 60

_SEVERITY_TEXT = {
    "RINGAN": "ringan dan cepat",
    "SEDANG": "sedang",
    "BERAT": "serius",
}

# Error yang layak dicoba ulang tanpa user mengetik ulang pesan: gangguan
# sesaat pada provider, bukan kesalahan input user.
_RETRYABLE_ERRORS = {"AI_UNAVAILABLE", "AI_BAD_RESPONSE"}

# Baris keselamatan hanya untuk dua kategori ini; kategori lain tidak punya
# risiko yang cukup jelas untuk diberi instruksi umum.
_SAFETY = {
    "ELECTRICAL": "Kalau ada korsleting atau kabel terbuka, matikan MCB dulu.",
    "PLUMBING": "Kalau air meluap deras, tutup keran utama dulu.",
}


def chat_id_or_404(value: str) -> ObjectId:
    try:
        return ObjectId(value)
    except (InvalidId, TypeError) as exc:
        raise ApiError(404, "CHAT_NOT_FOUND", "Percakapan tidak ditemukan") from exc


def _rupiah(value: int) -> str:
    return "Rp" + f"{int(value):,}".replace(",", ".")


def _fallback_narrative(label: str, severity: str) -> str:
    return (
        f"Kerusakan terlihat pada area {label.lower()}. Dari cerita dan foto "
        f"yang dikirim, kasus ini kemungkinan perlu penanganan "
        f"{_SEVERITY_TEXT.get(severity, 'sedang')}. Teknisi akan memastikan "
        f"penyebabnya saat melihat langsung."
    )


def _clean_narrative(raw, label: str, severity: str) -> str:
    text = raw.strip() if isinstance(raw, str) else ""
    text = re.sub(r"\s+", " ", text)

    # Jaring kedua: kalau model tetap menyelipkan angka, narasinya dibuang.
    # Menghapus digit dari kalimat menghasilkan bahasa rusak ("perlu  orang"),
    # jadi lebih baik diganti kalimat netral milik server.
    if len(text) < 20 or ai_client.has_digits(text):
        return _fallback_narrative(label, severity)
    return text[:600]


def _estimate_block(
    row: dict, category: dict, severity: str, city: str | None, confidence: float
) -> dict:
    scope = "city" if row.get("city") else "national"
    return {
        "category_code": category["code"],
        "category_label": category.get("label", category["code"]),
        "severity": severity,
        "min": int(row["min"]),
        "median": int(row["median"]),
        "max": int(row["max"]),
        "sample_count": int(row.get("sample_count", 0)),
        "scope": scope,
        "city": city if scope == "city" else None,
        "confidence": round(confidence, 2),
        "rough": confidence < 0.4,
    }


def _compose_text(
    narrative: str,
    block: dict | None,
    city: str | None,
    severity: str,
    category_code: str,
    safety_flag: bool,
    *,
    photo_relevant: bool | None,
    has_photos: bool,
) -> str:
    parts = [narrative]

    safety_line = None
    if safety_flag or (category_code in _SAFETY and severity == "BERAT"):
        safety_line = _SAFETY.get(
            category_code, "Hati-hati dan jangan memaksakan alat."
        )

    # Foto tidak relevan: harga tidak ditampilkan sama sekali. Menempelkan
    # rentang rupiah pada foto yang bukan kerusakan membuat jawaban terdengar
    # yakin padahal tidak ada yang dianalisis.
    if photo_relevant is False:
        # Kalau model sudah meminta foto ulang, jangan mengulanginya lagi;
        # dua kalimat permintaan berturut-turut terbaca seperti robot.
        if not re.search(r"kirim|unggah", narrative, re.IGNORECASE):
            parts.append(
                "Coba kirim foto yang lebih dekat ke bagian yang rusak, atau "
                "sebutkan bagian mana yang bermasalah."
            )
        # Risiko keselamatan berasal dari cerita user, bukan dari foto, jadi
        # tetap disampaikan walau fotonya tidak bisa dipakai.
        if safety_line:
            parts.append(safety_line)
        return "\n\n".join(parts)

    if block is not None:
        if block["scope"] == "city" and city:
            header = f"Perkiraan biaya di {city}: "
        else:
            header = "Perkiraan biaya (nasional): "
        parts.append(
            f"{header}{_rupiah(block['min'])} - {_rupiah(block['max'])}\n"
            f"(median {_rupiah(block['median'])}, dari {block['sample_count']} "
            f"kasus serupa)"
        )
        if block["scope"] == "national" and city:
            parts.append(
                f"Data untuk {city} belum tersedia, jadi angka ini memakai "
                "rentang nasional."
            )
        # "Kasar" berarti model belum yakin, bukan berarti datanya sedikit.
        if block["rough"]:
            parts.append(
                "Angka ini masih kasar karena jenis kerusakannya belum bisa "
                "dipastikan."
            )
    else:
        parts.append(
            "Belum ada cukup data harga untuk kasus seperti ini, jadi aku belum "
            "bisa memberi rentang angka. Coba sebutkan bagian yang rusak."
        )

    parts.append(
        "Yang memengaruhi: tingkat kerusakan, akses ke lokasi, dan part yang "
        "perlu diganti."
    )

    if safety_line:
        parts.append(safety_line)

    # Disclaimer harga hanya masuk kalau memang ada angka yang ditampilkan.
    if block is not None:
        parts.append(
            "Ini perkiraan awal, bukan harga pasti. Teknisi akan memberi "
            "penawaran setelah melihat langsung."
        )
    return "\n\n".join(parts)


def _effective_confidence(result: dict, category: dict) -> float:
    confidence = ai_client.normalize_confidence(result.get("confidence"))
    if category.get("code") == "OTHER":
        # Model cenderung tetap yakin walau tidak menemukan kerusakan apa pun.
        return min(confidence, 0.3)
    return confidence


def _photo_relevant(result: dict, has_photos: bool) -> bool | None:
    if not has_photos:
        # Tidak ada foto -> tidak ada yang bisa dinilai.
        return None

    value = result.get("photo_relevant")
    if isinstance(value, bool):
        return value
    if result.get("model") == "local-heuristic":
        # Mode teks: tidak ada yang melihat foto, jadi jangan mengaku relevan.
        return None
    return True


def _narrative(
    result: dict,
    category: dict,
    severity: str,
    has_photos: bool,
    photo_relevant: bool | None,
) -> str:
    label = category.get("label", category["code"])

    if result.get("model") == "local-heuristic":
        # Jangan pernah menulis "terlihat pada..." kalau tidak ada yang
        # melihat. Itu yang membuat balasan terasa tidak nyambung dengan foto.
        if has_photos:
            return (
                "Aku belum bisa membaca fotonya karena server berjalan tanpa "
                "model visual. Dari cerita yang kamu kirim, kasus ini paling "
                f"dekat ke {label.lower()}."
            )
        return (
            "Server berjalan tanpa model visual, jadi ini hanya tebakan dari "
            f"kata kunci: paling dekat ke {label.lower()}."
        )

    if photo_relevant is False:
        raw = result.get("narrative")
        text = raw.strip() if isinstance(raw, str) else ""
        text = re.sub(r"\s+", " ", text)
        if len(text) < 20 or ai_client.has_digits(text):
            text = (
                "Fotonya belum menunjukkan kerusakan yang bisa dinilai, jadi "
                "aku belum berani menebak jenis perbaikannya."
            )
        return text[:600]

    return _clean_narrative(result.get("narrative"), label, severity)


async def _reply(
    result: dict,
    category: dict,
    severity: str,
    city: str | None,
    has_photos: bool,
) -> tuple[str, dict | None, bool | None]:
    photo_relevant = _photo_relevant(result, has_photos)
    confidence = _effective_confidence(result, category)

    block = None
    if photo_relevant is not False:
        row = await price_service.lookup(category["code"], severity, city)
        if row is not None:
            block = _estimate_block(row, category, severity, city, confidence)

    narrative = _narrative(result, category, severity, has_photos, photo_relevant)
    text = _compose_text(
        narrative,
        block,
        city,
        severity,
        category["code"],
        bool(result.get("safety_flag")),
        photo_relevant=photo_relevant,
        has_photos=has_photos,
    )
    return text, block, photo_relevant


async def _active_categories() -> list[dict]:
    return await db.categories.find({"is_active": True}).sort("sort", 1).to_list(50)


def _pick_category(raw_code, categories: list[dict]) -> dict:
    if isinstance(raw_code, str):
        code = raw_code.strip().upper()
        for item in categories:
            if item["code"] == code:
                return item
    # Kode asing -> OTHER, bukan error: model boleh salah, jawaban tetap jalan.
    for item in categories:
        if item["code"] == "OTHER":
            return item
    return categories[0]


async def _classify(
    user: dict, text: str, photo_ids: list[str], history: list[dict] | None = None
) -> tuple[dict, dict, dict]:
    """Return (analysis, category, usage_info)."""
    categories = await _active_categories()
    photos: list[bytes] = []
    if photo_ids:
        await media_service.require_owned_photos(user, photo_ids)
        photos = await media_service.load_blobs(photo_ids)

    prompt = text
    if history:
        lines = [
            f"{item['role']}: {item['text']}"
            for item in history
            if item.get("text")
        ]
        if lines:
            prompt = (
                "Riwayat percakapan sebelumnya (untuk konteks, jangan dijawab "
                "ulang):\n" + "\n".join(lines) + "\n\nCerita terbaru user:\n" + text
            )

    result = await ai_client.analyze(
        categories, prompt, photos, (user.get("address") or {}).get("city")
    )
    category = _pick_category(result.get("category_code"), categories)
    severity = ai_client.normalize_severity(result.get("severity"))
    return result, category, severity


async def estimate(user: dict, payload: EstimateIn) -> dict:
    """Coba klasifikasi + harga tanpa menyimpan pesan (untuk menyetel prompt)."""
    # Foto dinormalisasi dulu: id dan URL /media/<id> sama-sama diterima,
    # data URI mentah ditolak sebelum biaya provider keluar.
    photo_ids = await media_service.resolve_photos(user, payload.photos)
    has_photos = bool(photo_ids)

    await _reserve_quota(
        user,
        "estimate",
        settings.ai_daily_estimate_limit,
        label="estimasi",
    )
    result, category, severity = await _classify(user, payload.text, photo_ids)
    if result.get("error"):
        # Kuota dikembalikan: user tidak mendapat jawaban apa pun.
        await _refund_quota(user, "estimate")
        return {
            "text": "Asisten sedang sibuk, coba lagi sebentar lagi.",
            "estimate": None,
            "model": result.get("model") or settings.ai_model,
            "error": result["error"],
            "photo_relevant": None,
        }

    city = (user.get("address") or {}).get("city")
    text, block, photo_relevant = await _reply(
        result, category, severity, city, has_photos
    )
    return {
        "text": text,
        "estimate": block,
        "model": result.get("model") or settings.ai_model,
        "error": None,
        "photo_relevant": photo_relevant,
    }


def _chat_response(doc: dict) -> dict:
    return {
        "_id": str(doc["_id"]),
        "title": doc.get("title") or "Percakapan baru",
        "city": doc.get("city"),
        "status": doc.get("status", "ACTIVE"),
        "message_count": doc.get("message_count", 0),
        "preview": doc.get("last_message_preview"),
        "created_at": iso_utc(doc["created_at"]),
        "updated_at": iso_utc(doc.get("updated_at") or doc["created_at"]),
        "last_message_at": (
            iso_utc(doc["last_message_at"]) if doc.get("last_message_at") else None
        ),
    }


def _message_response(doc: dict) -> dict:
    estimate = doc.get("estimate")
    if estimate and "scope" not in estimate:
        # Dokumen lama / hasil tulis manual: default yang aman.
        estimate = {**estimate, "scope": "national", "rough": False}
    return {
        "_id": str(doc["_id"]),
        "conversation_id": str(doc["conversation_id"]),
        "role": doc["role"],
        "text": doc.get("text", ""),
        # DB menyimpan id; API mengembalikan URL siap pakai untuk Image.network.
        "photos": [
            media_service.public_url(p) if media_service.is_media_id(p) else p
            for p in doc.get("photos") or []
        ],
        "estimate": estimate,
        "photo_relevant": doc.get("photo_relevant"),
        "model": doc.get("model"),
        "error": doc.get("error"),
        # Kegagalan sesaat (provider mati/terpotong) boleh dicoba ulang tanpa
        # mengetik ulang: UI tinggal menekan tombol coba lagi.
        "retryable": doc.get("role") == "ASSISTANT"
        and doc.get("error") in _RETRYABLE_ERRORS,
        "created_at": iso_utc(doc["created_at"]),
    }


async def create_chat(user: dict, payload: ChatCreateIn) -> dict:
    now = utcnow()
    doc = {
        "user_id": user["_id"],
        "title": payload.title or "Percakapan baru",
        "city": (user.get("address") or {}).get("city"),
        "status": "ACTIVE",
        "message_count": 0,
        "last_message_preview": None,
        "created_at": now,
        "updated_at": now,
        "last_message_at": None,
    }
    result = await db.ai_conversations.insert_one(doc)
    doc["_id"] = result.inserted_id
    return _chat_response(doc)


async def list_chats(user: dict, limit: int) -> list[dict]:
    cursor = (
        db.ai_conversations.find({"user_id": user["_id"]})
        .sort("updated_at", -1)
        .limit(limit)
    )
    return [_chat_response(doc) for doc in await cursor.to_list(length=limit)]


async def _owned_chat(user: dict, chat_id: str) -> dict:
    # Filter user_id ikut di query: chat orang lain dibalas 404, bukan 403,
    # supaya keberadaannya tidak bocor.
    doc = await db.ai_conversations.find_one(
        {"_id": chat_id_or_404(chat_id), "user_id": user["_id"]}
    )
    if doc is None:
        raise ApiError(404, "CHAT_NOT_FOUND", "Percakapan tidak ditemukan")
    return doc


def _parse_before(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise ApiError(422, "VALIDATION_ERROR", "before bukan tanggal ISO-8601") from exc
    return as_utc(parsed)


async def get_chat(
    user: dict, chat_id: str, limit: int, before: str | None
) -> dict:
    doc = await _owned_chat(user, chat_id)
    query: dict = {"conversation_id": doc["_id"]}
    moment = _parse_before(before)
    if moment is not None:
        query["created_at"] = {"$lt": moment}

    # Ambil N terbaru, lalu balik urutannya supaya UI tinggal render dari atas.
    cursor = db.ai_messages.find(query).sort("created_at", -1).limit(limit)
    newest_first = await cursor.to_list(length=limit)
    messages = [_message_response(item) for item in reversed(newest_first)]
    return {"conversation": _chat_response(doc), "messages": messages}


def _quota_day() -> str:
    """Tanggal kuota menurut zona user (default WIB), bukan UTC.

    Tanpa offset ini jatah harian baru terbuka jam 07:00 pagi waktu Indonesia.
    """
    offset = timedelta(hours=settings.ai_quota_utc_offset_hours)
    return (utcnow() + offset).strftime("%Y-%m-%d")


async def _reserve_quota(
    user: dict, field: str, limit: int, *, code: str = "AI_RATE_LIMITED", label: str = "pesan"
) -> None:
    """Ambil satu jatah secara atomik, atau 429 kalau sudah habis.

    Increment dilakukan dalam satu operasi supaya dua request bersamaan tidak
    bisa sama-sama lolos seperti pada pola hitung-lalu-insert sebelumnya.
    """
    if limit <= 0:
        return

    now = utcnow()
    try:
        await db.ai_usage.update_one(
            {
                "user_id": user["_id"],
                "day": _quota_day(),
                # $exists: dokumen dibuat oleh jenis kuota lain (mis. chat
                # lebih dulu) tidak punya field ini, dan $lt saja tidak
                # cocok untuk field yang belum ada.
                "$or": [
                    {field: {"$lt": limit}},
                    {field: {"$exists": False}},
                ],
            },
            {
                "$inc": {field: 1},
                "$set": {"updated_at": now},
                "$setOnInsert": {"created_at": now},
            },
            upsert=True,
        )
    except DuplicateKeyError as exc:
        # Filter tidak cocok (kuota penuh) -> upsert mencoba insert dokumen
        # baru -> unique index (user_id, day) menolaknya.
        raise ApiError(
            429, code, f"Batas {limit} {label} per hari sudah tercapai"
        ) from exc


async def _refund_quota(user: dict, field: str) -> None:
    await db.ai_usage.update_one(
        {"user_id": user["_id"], "day": _quota_day(), field: {"$gt": 0}},
        {"$inc": {field: -1}},
    )


async def purge_orphan_media(grace_seconds: int = 24 * 3600, limit: int = 500) -> int:
    """Hapus foto yang diunggah tapi tidak pernah dipakai offer/chat.

    Foto yatim muncul saat user memilih foto lalu batal. `used_at` diisi saat
    offer disimpan atau pesan AI berfoto dikirim, jadi yang masih null setelah
    masa tenggang aman dihapus.
    """
    cutoff = utcnow() - timedelta(seconds=grace_seconds)
    cursor = db.media.find(
        {"used_at": None, "created_at": {"$lt": cutoff}}, {"_id": 1}
    ).limit(limit)
    ids = [doc["_id"] async for doc in cursor]
    if not ids:
        return 0
    result = await db.media.delete_many({"_id": {"$in": ids}, "used_at": None})
    return result.deleted_count


async def _history(conversation_id: ObjectId) -> list[dict]:
    limit = max(1, settings.ai_history_messages)
    cursor = (
        db.ai_messages.find({"conversation_id": conversation_id})
        .sort("created_at", -1)
        .limit(limit)
    )
    newest_first = await cursor.to_list(length=limit)
    return list(reversed(newest_first))


async def send_message(user: dict, chat_id: str, payload: MessageIn) -> dict:
    chat = await _owned_chat(user, chat_id)
    if chat.get("status") == "CLOSED":
        raise ApiError(409, "CHAT_CLOSED", "Percakapan sudah ditutup")

    # Foto dinormalisasi & divalidasi SEBELUM kuota diambil: request yang
    # fotonya salah tidak boleh memakan jatah harian.
    photo_ids = await media_service.resolve_photos(user, payload.photos)
    await _reserve_quota(user, "chat", settings.ai_daily_message_limit)
    if photo_ids:
        # Putaran bergambar dibatasi terpisah: beberapa gambar per pesan
        # membuat biaya provider jauh melampaui chat teks.
        await _reserve_quota(
            user,
            "chat_photo",
            settings.ai_daily_photo_message_limit,
            code="AI_PHOTO_RATE_LIMITED",
            label="pesan berfoto",
        )

    # Diambil SEBELUM pesan baru disimpan, kalau tidak pesan yang sama muncul
    # dua kali di prompt (sekali sebagai riwayat, sekali sebagai cerita baru).
    history = await _history(chat["_id"])

    now = utcnow()
    user_doc = {
        "conversation_id": chat["_id"],
        "user_id": user["_id"],
        "role": "USER",
        "text": payload.text,
        # Hanya id: URL bertanda tangan akan mati saat kedaluwarsa.
        "photos": photo_ids,
        "estimate": None,
        "model": None,
        "error": None,
        "created_at": now,
    }
    user_result = await db.ai_messages.insert_one(user_doc)
    user_doc["_id"] = user_result.inserted_id

    result, category, severity = await _classify(
        user, payload.text, photo_ids, history
    )

    city = chat.get("city") or (user.get("address") or {}).get("city")
    if result.get("error"):
        # User tidak mendapat jawaban -> jatah tidak dipotong.
        await _refund_quota(user, "chat")
        if photo_ids:
            await _refund_quota(user, "chat_photo")
        assistant_text = "Asisten sedang sibuk, coba lagi sebentar lagi."
        block = None
        photo_relevant = None
        model = result.get("model")
    else:
        assistant_text, block, photo_relevant = await _reply(
            result, category, severity, city, bool(photo_ids)
        )
        model = result.get("model")

    assistant_now = utcnow()
    assistant_doc = {
        "conversation_id": chat["_id"],
        "user_id": user["_id"],
        "role": "ASSISTANT",
        "text": assistant_text,
        "photos": [],
        "estimate": block,
        "photo_relevant": photo_relevant,
        "model": model,
        "usage": result.get("usage"),
        "latency_ms": result.get("latency_ms"),
        "error": result.get("error"),
        "created_at": assistant_now,
    }
    assistant_result = await db.ai_messages.insert_one(assistant_doc)
    assistant_doc["_id"] = assistant_result.inserted_id

    updates: dict = {
        "last_message_at": assistant_now,
        "updated_at": assistant_now,
        "last_message_preview": assistant_text[:120],
    }
    update_ops: dict = {"$set": updates, "$inc": {"message_count": 2}}
    # Judul dari pesan pertama, dipotong supaya rapi di daftar percakapan.
    if chat.get("message_count", 0) == 0:
        update_ops["$set"]["title"] = payload.text[:TITLE_LENGTH]

    await db.ai_conversations.update_one({"_id": chat["_id"]}, update_ops)

    return {
        "user_message": _message_response(user_doc),
        "assistant_message": _message_response(assistant_doc),
    }


async def close_chat(user: dict, chat_id: str) -> dict:
    doc = await _owned_chat(user, chat_id)
    now = utcnow()
    updated = await db.ai_conversations.find_one_and_update(
        {"_id": doc["_id"], "status": "ACTIVE"},
        {"$set": {"status": "CLOSED", "updated_at": now}},
        return_document=ReturnDocument.AFTER,
    )
    # Sudah CLOSED -> idempoten, kembalikan dokumen apa adanya.
    return _chat_response(updated or doc)
