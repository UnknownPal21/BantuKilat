"""Chat AI: grounding harga, gerbang photo_relevant, kuota, dan kegagalan provider."""

import pytest
from bson import ObjectId

from backend.core.config import settings
from backend.db.mongo import db
from backend.services import ai_client, ai_service


@pytest.fixture
def offline_provider(monkeypatch):
    """Pastikan tidak ada panggilan ke provider berbayar."""
    monkeypatch.setattr(settings, "ai_api_key", "")
    monkeypatch.setattr(settings, "ai_allow_local_fallback", True)


async def test_estimate_uses_catalog_numbers(api, make_account, offline_provider):
    user = await make_account()
    response = await api.post(
        "/ai/estimate",
        headers=user.headers,
        json={"text": "Kran di bawah wastafel bocor, netes terus sejak pagi"},
    )
    assert response.status_code == 200, response.text
    body = response.json()
    estimate = body["estimate"]
    assert estimate is not None
    assert estimate["category_code"] == "PLUMBING"
    assert estimate["scope"] == "city"
    assert estimate["sample_count"] >= 20
    assert estimate["min"] < estimate["median"] < estimate["max"]
    assert body["photo_relevant"] is None
    # Mode lokal tidak boleh mengaku melihat foto.
    assert "tanpa model visual" in body["text"]
    assert "terlihat pada" not in body["text"]
    # Narasi bebas angka; hanya blok harga yang memuat Rp.
    narrative = body["text"].split("Perkiraan biaya")[0]
    assert not any(char.isdigit() for char in narrative)

    row = await db.price_catalog.find_one(
        {
            "category_code": "PLUMBING",
            "severity": estimate["severity"],
            "city": "surabaya",
        }
    )
    assert (row["min"], row["median"], row["max"]) == (
        estimate["min"],
        estimate["median"],
        estimate["max"],
    )


async def test_neutral_keyword_is_not_moving(api, make_account, offline_provider):
    user = await make_account()
    body = (
        await api.post(
            "/ai/estimate",
            headers=user.headers,
            json={"text": "Ada kerusakan barang di rumah, tolong dicek"},
        )
    ).json()
    assert body["estimate"]["category_code"] == "OTHER"
    assert body["estimate"]["confidence"] <= 0.3
    assert body["estimate"]["rough"] is True


async def test_city_without_data_gets_national_label(
    api, make_account, offline_provider
):
    user = await make_account(city="Tulungagung", district="Kedungwaru")
    body = (
        await api.post(
            "/ai/estimate",
            headers=user.headers,
            json={"text": "Kabel listrik di dapur terbakar dan berasap, MCB anjlok"},
        )
    ).json()
    estimate = body["estimate"]
    assert estimate["scope"] == "national"
    assert estimate["city"] is None
    assert "Perkiraan biaya (nasional)" in body["text"]
    assert "Data untuk Tulungagung belum tersedia" in body["text"]
    assert "di sekitarmu belum banyak" not in body["text"]
    # Baris keselamatan tetap ada untuk listrik BERAT.
    assert "matikan MCB" in body["text"]


async def test_irrelevant_photo_hides_price(
    api, make_account, upload_photo, monkeypatch, offline_provider
):
    user = await make_account()
    media = await upload_photo(user)

    async def fake(categories, text, photos, city):
        return {
            "category_code": "PLUMBING",
            "severity": "SEDANG",
            "narrative": "Foto ini hanya memperlihatkan wajah orang, bukan pipa.",
            "confidence": 0.9,
            "safety_flag": False,
            "photo_relevant": False,
            "model": "fake-vision",
            "usage": None,
            "error": None,
            "latency_ms": 1,
        }

    monkeypatch.setattr(ai_client, "analyze", fake)
    body = (
        await api.post(
            "/ai/estimate",
            headers=user.headers,
            json={"text": "berapa biayanya?", "photos": [media["id"]]},
        )
    ).json()
    assert body["photo_relevant"] is False
    assert body["estimate"] is None
    assert "Rp" not in body["text"]
    assert "Coba kirim foto" in body["text"]


async def test_irrelevant_photo_keeps_safety_line(
    api, make_account, upload_photo, monkeypatch, offline_provider
):
    user = await make_account()
    media = await upload_photo(user)

    async def fake(categories, text, photos, city):
        return {
            "category_code": "ELECTRICAL",
            "severity": "BERAT",
            "narrative": "Foto ini hanya memperlihatkan wajah orang.",
            "confidence": 0.2,
            "safety_flag": True,
            "photo_relevant": False,
            "model": "fake-vision",
            "usage": None,
            "error": None,
            "latency_ms": 1,
        }

    monkeypatch.setattr(ai_client, "analyze", fake)
    body = (
        await api.post(
            "/ai/estimate",
            headers=user.headers,
            json={"text": "kabel terbakar, berapa biayanya?", "photos": [media["id"]]},
        )
    ).json()
    assert body["estimate"] is None
    assert "Rp" not in body["text"]
    assert "matikan MCB" in body["text"]


async def test_chat_turn_and_isolation(api, make_account, upload_photo, offline_provider):
    user = await make_account()
    other = await make_account()
    media = await upload_photo(user)

    chat = (await api.post("/ai/chats", headers=user.headers, json={})).json()
    assert chat["title"] == "Percakapan baru"

    turn = (
        await api.post(
            f"/ai/chats/{chat['_id']}/messages",
            headers=user.headers,
            json={
                "text": "Pipa wastafel di bawah jebol, air merembes ke lemari",
                "photos": [media["id"]],
            },
        )
    ).json()
    assistant = turn["assistant_message"]
    assert assistant["model"] == "local-heuristic"
    assert "belum bisa membaca fotonya" in assistant["text"]
    assert assistant["estimate"] is not None

    detail = (await api.get(f"/ai/chats/{chat['_id']}", headers=user.headers)).json()
    assert detail["conversation"]["message_count"] == 2
    assert [item["role"] for item in detail["messages"]] == ["USER", "ASSISTANT"]
    assert detail["conversation"]["title"] != "Percakapan baru"

    assert (await api.get(f"/ai/chats/{chat['_id']}", headers=other.headers)).status_code == 404
    assert (
        await api.post(
            f"/ai/chats/{chat['_id']}/messages",
            headers=other.headers,
            json={"text": "halo"},
        )
    ).status_code == 404


async def test_chat_close_blocks_messages(api, make_account, offline_provider):
    user = await make_account()
    chat = (await api.post("/ai/chats", headers=user.headers, json={})).json()

    closed = await api.post(f"/ai/chats/{chat['_id']}/close", headers=user.headers)
    assert closed.status_code == 200
    assert closed.json()["status"] == "CLOSED"

    response = await api.post(
        f"/ai/chats/{chat['_id']}/messages",
        headers=user.headers,
        json={"text": "masih bisa?"},
    )
    assert response.status_code == 409
    assert response.json()["code"] == "CHAT_CLOSED"


async def test_chat_daily_quota(api, make_account, monkeypatch, offline_provider):
    user = await make_account()
    chat = (await api.post("/ai/chats", headers=user.headers, json={})).json()
    monkeypatch.setattr(settings, "ai_daily_message_limit", 1)

    first = await api.post(
        f"/ai/chats/{chat['_id']}/messages",
        headers=user.headers,
        json={"text": "kran bocor"},
    )
    assert first.status_code == 200

    second = await api.post(
        f"/ai/chats/{chat['_id']}/messages",
        headers=user.headers,
        json={"text": "kran bocor lagi"},
    )
    assert second.status_code == 429
    assert second.json()["code"] == "AI_RATE_LIMITED"

    assert (
        await db.ai_messages.count_documents({"user_id": ObjectId(user.id)}) == 2
    )


async def test_estimate_daily_quota(api, make_account, monkeypatch, offline_provider):
    user = await make_account()
    monkeypatch.setattr(settings, "ai_daily_estimate_limit", 1)

    first = await api.post(
        "/ai/estimate", headers=user.headers, json={"text": "kran bocor"}
    )
    assert first.status_code == 200
    second = await api.post(
        "/ai/estimate", headers=user.headers, json={"text": "kran bocor"}
    )
    assert second.status_code == 429
    assert second.json()["code"] == "AI_RATE_LIMITED"


async def test_provider_failure_refunds_quota(api, make_account, monkeypatch, offline_provider):
    user = await make_account()
    chat = (await api.post("/ai/chats", headers=user.headers, json={})).json()
    monkeypatch.setattr(settings, "ai_api_key", "kunci-palsu")
    monkeypatch.setattr(settings, "ai_base_url", "http://127.0.0.1:9")
    monkeypatch.setattr(settings, "ai_timeout_seconds", 2)

    body = (
        await api.post("/ai/estimate", headers=user.headers, json={"text": "kran bocor"})
    ).json()
    assert body["error"] == "AI_UNAVAILABLE"
    assert "sedang sibuk" in body["text"]

    # Chat juga tidak boleh memotong jatah saat provider gagal.
    turn = (
        await api.post(
            f"/ai/chats/{chat['_id']}/messages",
            headers=user.headers,
            json={"text": "kran bocor"},
        )
    ).json()
    assert turn["assistant_message"]["error"] == "AI_UNAVAILABLE"

    usage = await db.ai_usage.find_one(
        {"user_id": ObjectId(user.id), "day": ai_service._quota_day()}
    )
    # Tidak ada jawaban -> jatah harian tidak boleh berkurang.
    assert usage is None or usage.get("estimate", 0) == 0
    assert usage is None or usage.get("chat", 0) == 0


async def test_estimate_requires_configured_ai(api, make_account, monkeypatch):
    user = await make_account()
    monkeypatch.setattr(settings, "ai_api_key", "")
    monkeypatch.setattr(settings, "ai_allow_local_fallback", False)

    body = (
        await api.post("/ai/estimate", headers=user.headers, json={"text": "kran bocor"})
    ).json()
    assert body["error"] == "AI_NOT_CONFIGURED"


async def test_photo_message_quota(
    api, make_account, upload_photo, monkeypatch, offline_provider
):
    user = await make_account()
    media = await upload_photo(user)
    chat = (await api.post("/ai/chats", headers=user.headers, json={})).json()
    monkeypatch.setattr(settings, "ai_daily_photo_message_limit", 1)

    first = await api.post(
        f"/ai/chats/{chat['_id']}/messages",
        headers=user.headers,
        json={"text": "pipa bocor", "photos": [media["id"]]},
    )
    assert first.status_code == 200, first.text

    second = await api.post(
        f"/ai/chats/{chat['_id']}/messages",
        headers=user.headers,
        json={"text": "pipa bocor lagi", "photos": [media["id"]]},
    )
    assert second.status_code == 429
    assert second.json()["code"] == "AI_PHOTO_RATE_LIMITED"

    # Pesan tanpa foto tidak terpengaruh kuota foto.
    third = await api.post(
        f"/ai/chats/{chat['_id']}/messages",
        headers=user.headers,
        json={"text": "kalau tanpa foto gimana?"},
    )
    assert third.status_code == 200, third.text


async def test_failed_provider_message_is_retryable(
    api, make_account, monkeypatch, offline_provider
):
    user = await make_account()
    chat = (await api.post("/ai/chats", headers=user.headers, json={})).json()
    monkeypatch.setattr(settings, "ai_api_key", "kunci-palsu")
    monkeypatch.setattr(settings, "ai_base_url", "http://127.0.0.1:9")
    monkeypatch.setattr(settings, "ai_timeout_seconds", 2)

    turn = (
        await api.post(
            f"/ai/chats/{chat['_id']}/messages",
            headers=user.headers,
            json={"text": "kran bocor"},
        )
    ).json()
    assistant = turn["assistant_message"]
    assert assistant["error"] == "AI_UNAVAILABLE"
    # UI bisa menawarkan "coba lagi" tanpa user mengetik ulang.
    assert assistant["retryable"] is True

    # Provider pulih -> percobaan berikutnya berhasil, tanpa sisa status gagal.
    monkeypatch.setattr(settings, "ai_api_key", "")
    ok = (
        await api.post(
            f"/ai/chats/{chat['_id']}/messages",
            headers=user.headers,
            json={"text": "kran bocor"},
        )
    ).json()
    assert ok["assistant_message"]["error"] is None
    assert ok["assistant_message"]["retryable"] is False
