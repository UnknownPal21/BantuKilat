from backend.db.mongo import db


def _category_response(doc: dict) -> dict:
    # ObjectId tidak bisa di-serialize FastAPI -> str()
    return {
        "_id": str(doc["_id"]),
        "code": doc["code"],
        "label": doc["label"],
        "skill_label": doc["skill_label"],
        "icon": doc["icon"],
        "short_desc": doc.get("short_desc", ""),
        "color": doc.get("color"),
        "sort": doc.get("sort", 0),
    }


async def list_categories(include_inactive: bool = False) -> list[dict]:
    # CARPENTRY is_active=false tetap tersimpan karena dipakai chip skill
    # teknisi, tapi tidak muncul di bento home user.
    query = {} if include_inactive else {"is_active": True}
    cursor = db.categories.find(query).sort("sort", 1)
    docs = await cursor.to_list(length=100)
    return [_category_response(doc) for doc in docs]
