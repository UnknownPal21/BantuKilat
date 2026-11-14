import asyncio

from backend.db.mongo import db

# Seed awal. `sort` menentukan urutan tampil di bento home user.
# CARPENTRY sengaja is_active=false: dipakai chip skill teknisi,
# tidak tampil di bento. Ubah flag kalau produk ingin menampilkannya.
CATEGORIES = [
    {
        "code": "ELECTRICAL",
        "label": "Kelistrikan",
        "skill_label": "Kelistrikan & Saklar",
        "icon": "⚡",
        "short_desc": "MCB anjlok, saklar, bohlam",
        "color": "#F59E0B",
        "sort": 1,
        "is_active": True,
    },
    {
        "code": "PLUMBING",
        "label": "Air",
        "skill_label": "Pipa, Kran & Saluran Air",
        "icon": "🚰",
        "short_desc": "Kran patah, toren, bocor",
        "color": "#0EA5E9",
        "sort": 2,
        "is_active": True,
    },
    {
        "code": "VEHICLE",
        "label": "Kendaraan",
        "skill_label": "Mekanik Motor Ringan",
        "icon": "🏍️",
        "short_desc": "Tambal tubeless, jumper aki",
        "color": "#F97316",
        "sort": 3,
        "is_active": True,
    },
    {
        "code": "MOVING",
        "label": "Angkut Barang",
        "skill_label": "Angkut Barang Berat",
        "icon": "📦",
        "short_desc": "Angkat gas, kasur, pindahan",
        "color": "#8B5CF6",
        "sort": 4,
        "is_active": True,
    },
    {
        "code": "TECH",
        "label": "Teknologi",
        "skill_label": "AC & Elektronik Rumah",
        "icon": "💻",
        "short_desc": "Printer error, router reset",
        "color": "#10B981",
        "sort": 5,
        "is_active": True,
    },
    {
        "code": "OTHER",
        "label": "Bantuan Lain",
        "skill_label": "Lainnya",
        "icon": "🔧",
        "short_desc": "Titip warung, kunci pagar",
        "color": "#64748B",
        "sort": 6,
        "is_active": True,
    },
    {
        "code": "CARPENTRY",
        "label": "Pertukangan",
        "skill_label": "Pertukangan & Kunci",
        "icon": "🔨",
        "short_desc": "Kunci pintu, rak, kayu",
        "color": "#EF4444",
        "sort": 7,
        "is_active": False,
    },
]

# `bsonType: "int"` menolak double, jadi uang dan koordinat menerima
# int/long/double sekaligus supaya tidak gagal karena tipe angka Python.
_NUMBER = ["int", "long", "double"]

OFFERS_VALIDATOR = {
    "$jsonSchema": {
        "bsonType": "object",
        "required": [
            "requester_id",
            "category_id",
            "title",
            "description",
            "photos",
            "location",
            "initial_budget",
            "status",
            "created_at",
        ],
        "properties": {
            "title": {"bsonType": "string", "minLength": 5, "maxLength": 100},
            "description": {
                "bsonType": "string",
                "minLength": 10,
                "maxLength": 1000,
            },
            "photos": {
                "bsonType": "array",
                "minItems": 1,
                "maxItems": 5,
                "items": {"bsonType": "string"},
            },
            "initial_budget": {"bsonType": _NUMBER, "minimum": 0},
            "agreed_price": {"bsonType": [*_NUMBER, "null"], "minimum": 0},
            "sos_fee": {"bsonType": _NUMBER, "minimum": 0},
            "status": {
                "enum": [
                    "WAITING",
                    "NEGOTIATING",
                    "ASSIGNED",
                    "COMPLETED",
                    "CANCELLED",
                    "EXPIRED",
                ]
            },
            "location": {
                "bsonType": "object",
                "required": ["type", "coordinates"],
                "properties": {
                    "type": {"enum": ["Point"]},
                    "coordinates": {
                        "bsonType": "array",
                        "minItems": 2,
                        "maxItems": 2,
                        "items": {"bsonType": _NUMBER},
                    },
                },
            },
        },
    }
}


async def ensure_user_indexes() -> None:
    await db.users.create_index("email", unique=True)
    await db.users.create_index(
        "phone", unique=True, partialFilterExpression={"phone": {"$type": "string"}}
    )
    await db.users.create_index(
        "google_sub",
        unique=True,
        partialFilterExpression={"google_sub": {"$type": "string"}},
    )
    await db.users.create_index("password_reset.token_hash", sparse=True)


async def ensure_categories() -> None:
    await db.categories.create_index("code", unique=True)
    await db.categories.create_index([("is_active", 1), ("sort", 1)])

    # Upsert per `code`, bukan insertMany: aman dijalankan berulang dan bisa
    # memperbarui label tanpa migrasi. `code` sendiri jangan pernah diubah.
    for item in CATEGORIES:
        await db.categories.update_one(
            {"code": item["code"]},
            {"$set": item},
            upsert=True,
        )


async def ensure_offers() -> None:
    options = {
        "validator": OFFERS_VALIDATOR,
        "validationLevel": "strict",
        "validationAction": "error",
    }

    if "offers" in await db.list_collection_names():
        # Collection sudah ada (mis. dibuat manual) -> pasang validator tanpa
        # menghapus data.
        await db.command("collMod", "offers", **options)
    else:
        await db.create_collection("offers", **options)

    await db.offers.create_index([("location", "2dsphere")])
    await db.offers.create_index([("status", 1), ("category_id", 1), ("created_at", -1)])
    await db.offers.create_index(
        [("requester_id", 1), ("status", 1), ("created_at", -1)]
    )
    await db.offers.create_index(
        [("technician_id", 1), ("status", 1), ("updated_at", -1)]
    )
    await db.offers.create_index([("is_sos", 1), ("expires_at", 1)])


async def ensure_bids() -> None:
    await db.bids.create_index([("offer_id", 1), ("status", 1), ("amount", 1)])
    # Partial: hanya bid PENDING yang dijaga unik. Teknisi boleh bid ulang
    # setelah bid lamanya REJECTED/WITHDRAWN/EXPIRED.
    await db.bids.create_index(
        [("offer_id", 1), ("technician_id", 1)],
        unique=True,
        partialFilterExpression={"status": "PENDING"},
    )
    await db.bids.create_index([("technician_id", 1), ("created_at", -1)])


async def ensure_media() -> None:
    # Lookup saat offer/chat dibuat selalu lewat _id, jadi index utama tidak
    # diperlukan. Dua index ini untuk daftar foto user dan pembersihan file
    # yatim (used_at masih null).
    await db.media.create_index([("owner_id", 1), ("created_at", -1)])
    await db.media.create_index([("used_at", 1), ("created_at", 1)])


async def ensure_prices() -> None:
    await db.price_samples.create_index(
        [("category_code", 1), ("severity", 1), ("city", 1)]
    )
    await db.price_samples.create_index([("source", 1), ("created_at", 1)])
    # Satu offer hanya boleh menyumbang satu sampel harga, sekalipun endpoint
    # complete dipanggil dua kali.
    await db.price_samples.create_index(
        "offer_id",
        unique=True,
        partialFilterExpression={"source": "DEAL"},
    )
    # city: null ikut tersimpan, jadi index ini sekaligus jadi kunci unik
    # baris nasional.
    await db.price_catalog.create_index(
        [("category_code", 1), ("severity", 1), ("city", 1)], unique=True
    )


async def ensure_ai() -> None:
    await db.ai_conversations.create_index([("user_id", 1), ("updated_at", -1)])
    await db.ai_conversations.create_index(
        [("user_id", 1), ("status", 1), ("last_message_at", -1)]
    )
    await db.ai_messages.create_index([("conversation_id", 1), ("created_at", 1)])
    await db.ai_messages.create_index([("user_id", 1), ("created_at", -1)])
    # Dipakai menghitung kuota harian: role USER per user per hari.
    await db.ai_messages.create_index(
        [("user_id", 1), ("role", 1), ("created_at", -1)]
    )
    # Penghitung kuota atomik: satu dokumen per user per hari (WIB).
    await db.ai_usage.create_index([("user_id", 1), ("day", 1)], unique=True)
    # Dokumen kuota lama tidak perlu disimpan selamanya.
    await db.ai_usage.create_index("created_at", expireAfterSeconds=60 * 60 * 24 * 30)


async def setup() -> None:
    await ensure_user_indexes()
    await ensure_categories()
    await ensure_offers()
    await ensure_bids()
    await ensure_media()
    await ensure_prices()
    await ensure_ai()
    print("categories:", await db.categories.count_documents({}))
    print("offers index:", await db.offers.index_information())
    print("bids index:", await db.bids.index_information())
    print("media index:", await db.media.index_information())
    print("price samples:", await db.price_samples.count_documents({}))
    print("price catalog:", await db.price_catalog.count_documents({}))


if __name__ == "__main__":
    asyncio.run(setup())
