"""Foto: URL bertanda tangan dan normalisasi id/URL di offer & chat."""

import time
from urllib.parse import urlsplit

from bson import ObjectId

from backend.db.mongo import db
from backend.services import media_service
from tests.helpers import PNG_DATA_URI


async def test_upload_returns_signed_url(api, make_account):
    user = await make_account()
    response = await api.post(
        "/media", headers=user.headers, json={"data": PNG_DATA_URI, "kind": "ai"}
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["url"].startswith("http://localhost:8000/media/")
    assert "exp=" in body["url"] and "sig=" in body["url"]

    parts = urlsplit(body["url"])
    fetch = await api.get(f"{parts.path}?{parts.query}")
    assert fetch.status_code == 200, fetch.text
    assert fetch.headers["content-type"] == "image/jpeg"
    # Cache tidak boleh publik: URL membawa tanda tangan pribadi.
    assert fetch.headers["cache-control"].startswith("private")


async def test_media_requires_signature(api, make_account, upload_photo):
    user = await make_account()
    media = await upload_photo(user)

    unsigned = await api.get(f"/media/{media['id']}")
    assert unsigned.status_code == 403
    assert unsigned.json()["code"] == "MEDIA_URL_INVALID"

    parts = urlsplit(media["url"])
    exp = parts.query.split("exp=")[1].split("&")[0]
    tampered = await api.get(f"/media/{media['id']}?exp={exp}&sig={'0' * 40}")
    assert tampered.status_code == 403
    assert tampered.json()["code"] == "MEDIA_URL_INVALID"


async def test_expired_signature_rejected(api, make_account, upload_photo):
    user = await make_account()
    media = await upload_photo(user)

    expired_at = int(time.time()) - 60
    signature = media_service._signature(media["id"], expired_at)
    response = await api.get(
        f"/media/{media['id']}?exp={expired_at}&sig={signature}"
    )
    assert response.status_code == 403
    assert response.json()["code"] == "MEDIA_URL_EXPIRED"


async def test_upload_rejects_invalid_data_uri(api, make_account):
    user = await make_account()
    response = await api.post(
        "/media",
        headers=user.headers,
        json={"data": "data:image/png;base64,bukanbase64valid"},
    )
    assert response.status_code == 422
    assert response.json()["code"] == "INVALID_PHOTO"


async def test_offer_accepts_media_url(api, make_account, upload_photo, categories):
    user = await make_account()
    media = await upload_photo(user)
    cat = await categories()

    response = await api.post(
        "/offers",
        headers=user.headers,
        json={
            "category_id": cat["PLUMBING"],
            "title": "Pipa wastafel bocor",
            "description": "Sambungan paralon lepas, air mengalir ke lantai.",
            "photos": [media["url"]],
            "lng": 112.7531,
            "lat": -7.2412,
            "address_text": "RT 02 No. 14",
            "initial_budget": 20_000,
        },
    )
    assert response.status_code == 201, response.text
    offer = response.json()
    assert "?exp=" in offer["photos"][0]

    doc = await db.offers.find_one({"_id": ObjectId(offer["_id"])})
    # Yang tersimpan hanya id, bukan URL bertanda tangan yang akan mati.
    assert doc["photos"] == [media["id"]]


async def test_message_accepts_media_url(api, make_account, upload_photo):
    user = await make_account()
    media = await upload_photo(user)
    chat = (await api.post("/ai/chats", headers=user.headers, json={})).json()

    response = await api.post(
        f"/ai/chats/{chat['_id']}/messages",
        headers=user.headers,
        json={"text": "Pipa wastafel bocor, air merembes", "photos": [media["url"]]},
    )
    assert response.status_code == 200, response.text
    turn = response.json()
    assert "?exp=" in turn["user_message"]["photos"][0]

    saved = await db.ai_messages.find_one(
        {"_id": ObjectId(turn["user_message"]["_id"])}
    )
    assert saved["photos"] == [media["id"]]


async def test_message_rejects_raw_data_uri(api, make_account):
    user = await make_account()
    chat = (await api.post("/ai/chats", headers=user.headers, json={})).json()

    response = await api.post(
        f"/ai/chats/{chat['_id']}/messages",
        headers=user.headers,
        json={"text": "bocor", "photos": [PNG_DATA_URI]},
    )
    assert response.status_code == 422
    assert response.json()["code"] == "PHOTO_NOT_UPLOADED"


async def test_message_rejects_foreign_photo(
    api, make_account, upload_photo
):
    owner = await make_account()
    other = await make_account()
    media = await upload_photo(owner)
    chat = (await api.post("/ai/chats", headers=other.headers, json={})).json()

    response = await api.post(
        f"/ai/chats/{chat['_id']}/messages",
        headers=other.headers,
        json={"text": "Bocor di dapur", "photos": [media["id"]]},
    )
    assert response.status_code == 422
    assert response.json()["code"] == "PHOTO_NOT_FOUND"


async def test_message_rejects_duplicate_refs(api, make_account, upload_photo):
    user = await make_account()
    media = await upload_photo(user)
    chat = (await api.post("/ai/chats", headers=user.headers, json={})).json()

    response = await api.post(
        f"/ai/chats/{chat['_id']}/messages",
        headers=user.headers,
        json={"text": "Bocor di dapur", "photos": [media["id"], media["url"]]},
    )
    assert response.status_code == 422
    assert response.json()["code"] == "VALIDATION_ERROR"


async def test_upload_daily_limit(api, make_account, monkeypatch):
    user = await make_account()
    monkeypatch.setattr(media_service.settings, "media_daily_upload_limit", 2)
    media_service.media_upload_counter.reset()

    for _ in range(2):
        ok = await api.post(
            "/media", headers=user.headers, json={"data": PNG_DATA_URI}
        )
        assert ok.status_code == 200, ok.text

    blocked = await api.post(
        "/media", headers=user.headers, json={"data": PNG_DATA_URI}
    )
    assert blocked.status_code == 429
    assert blocked.json()["code"] == "MEDIA_RATE_LIMITED"
    media_service.media_upload_counter.reset()


async def test_view_daily_limit(api, make_account, upload_photo, monkeypatch):
    user = await make_account()
    media = await upload_photo(user)
    parts = urlsplit(media["url"])
    monkeypatch.setattr(media_service.settings, "media_daily_view_limit", 1)
    media_service.media_view_counter.reset()

    first = await api.get(f"{parts.path}?{parts.query}")
    assert first.status_code == 200
    second = await api.get(f"{parts.path}?{parts.query}")
    assert second.status_code == 429
    assert second.json()["code"] == "MEDIA_RATE_LIMITED"
    media_service.media_view_counter.reset()


async def test_purge_removes_only_orphans(api, make_account, upload_photo):
    from datetime import timedelta

    from backend.core.timeutils import utcnow
    from backend.services import ai_service

    user = await make_account()
    used = await upload_photo(user)
    orphan = await upload_photo(user)

    old = utcnow() - timedelta(days=3)
    await db.media.update_many(
        {"_id": {"$in": [ObjectId(used["id"]), ObjectId(orphan["id"])]}},
        {"$set": {"created_at": old}},
    )
    await media_service.mark_used([ObjectId(used["id"])])

    removed = await ai_service.purge_orphan_media()
    assert removed >= 1
    assert await db.media.find_one({"_id": ObjectId(used["id"])}) is not None
    assert await db.media.find_one({"_id": ObjectId(orphan["id"])}) is None
