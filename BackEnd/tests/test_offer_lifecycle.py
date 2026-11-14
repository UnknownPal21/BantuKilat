"""State machine yang belum tertutup: batal, kedaluwarsa, tolak, tarik bid."""

from datetime import timedelta

from bson import ObjectId

from backend.core.timeutils import utcnow
from backend.db.mongo import db
from backend.services import offer_service


def _offer_payload(categories: dict, photo_id: str) -> dict:
    return {
        "category_id": categories["PLUMBING"],
        "title": "Kran wastafel bocor",
        "description": "Air menetes terus sejak pagi, lantai basah.",
        "photos": [photo_id],
        # Surabaya: sama dengan kota tes lain, jadi offer ini muncul di
        # hasil nearby teknisi.
        "lng": 112.7531,
        "lat": -7.2412,
        "address_text": "RT 02 No. 14",
        "initial_budget": 20_000,
    }


async def _offer(api, owner, categories, upload_photo, photo=None) -> dict:
    """Buat offer dengan foto sungguhan (POST /offers butuh id media valid)."""
    media = photo or await upload_photo(owner)
    cats = await categories()
    response = await api.post(
        "/offers",
        headers=owner.headers,
        json=_offer_payload(cats, media["id"]),
    )
    assert response.status_code == 201, response.text
    return response.json()


async def test_cancel_sets_reason_and_withdraws_pending_bids(
    api, make_account, categories, upload_photo
):
    owner = await make_account()
    tech = await make_account(role="TECHNICIAN")
    offer = await _offer(api, owner, categories, upload_photo)

    bid = await api.post(
        f"/offers/{offer['_id']}/bids",
        headers=tech.headers,
        json={"amount": 35_000},
    )
    assert bid.status_code == 200, bid.text

    cancelled = await api.post(
        f"/offers/{offer['_id']}/cancel",
        headers=owner.headers,
        json={"reason": "SALAH_INPUT"},
    )
    assert cancelled.status_code == 200, cancelled.text
    body = cancelled.json()
    assert body["status"] == "CANCELLED"
    assert body["cancel_reason"] == "SALAH_INPUT"
    assert body["cancelled_at"] is not None

    # Bid yang menunggu tidak boleh menggantung.
    saved = await db.bids.find_one(
        {"offer_id": ObjectId(offer["_id"]), "status": "WITHDRAWN"}
    )
    assert saved is not None


async def test_cancel_without_body_uses_default_reason(
    api, make_account, categories, upload_photo
):
    owner = await make_account()
    offer = await _offer(api, owner, categories, upload_photo)

    response = await api.post(f"/offers/{offer['_id']}/cancel", headers=owner.headers)
    assert response.status_code == 200, response.text
    assert response.json()["cancel_reason"] == "LAINNYA"


async def test_cancel_is_idempotent(api, make_account, categories, upload_photo):
    owner = await make_account()
    offer = await _offer(api, owner, categories, upload_photo)

    first = await api.post(f"/offers/{offer['_id']}/cancel", headers=owner.headers)
    second = await api.post(f"/offers/{offer['_id']}/cancel", headers=owner.headers)
    assert first.status_code == 200
    # Menekan dua kali bukan error.
    assert second.status_code == 200
    assert second.json()["status"] == "CANCELLED"


async def test_cancel_rejects_foreign_user(api, make_account, categories, upload_photo):
    owner = await make_account()
    stranger = await make_account()
    offer = await _offer(api, owner, categories, upload_photo)

    response = await api.post(f"/offers/{offer['_id']}/cancel", headers=stranger.headers)
    assert response.status_code == 403
    assert response.json()["code"] == "NOT_OFFER_OWNER"


async def test_cancel_rejects_assigned_offer(
    api, make_account, categories, upload_photo
):
    owner = await make_account()
    tech = await make_account(role="TECHNICIAN")
    offer = await _offer(api, owner, categories, upload_photo)
    bid = await api.post(
        f"/offers/{offer['_id']}/bids", headers=tech.headers, json={"amount": 30_000}
    )
    await api.post(f"/bids/{bid.json()['_id']}/accept", headers=owner.headers)

    response = await api.post(f"/offers/{offer['_id']}/cancel", headers=owner.headers)
    assert response.status_code == 409
    assert response.json()["code"] == "OFFER_ALREADY_ASSIGNED"


async def test_expire_overdue_marks_offer_and_bids(
    api, make_account, categories, upload_photo
):
    owner = await make_account()
    tech = await make_account(role="TECHNICIAN")
    offer = await _offer(api, owner, categories, upload_photo)
    bid = await api.post(
        f"/offers/{offer['_id']}/bids", headers=tech.headers, json={"amount": 30_000}
    )
    assert bid.status_code == 200, bid.text

    # Waktu dimundurkan, bukan menunggu 30 menit.
    await db.offers.update_one(
        {"_id": ObjectId(offer["_id"])},
        {"$set": {"expires_at": utcnow() - timedelta(minutes=1)}},
    )

    changed = await offer_service.expire_overdue()
    assert changed == 1

    saved = await db.offers.find_one({"_id": ObjectId(offer["_id"])})
    assert saved["status"] == "EXPIRED"
    assert saved["cancel_reason"] == "KEDALUWARSA"

    saved_bid = await db.bids.find_one({"_id": ObjectId(bid.json()["_id"])})
    assert saved_bid["status"] == "EXPIRED"

    # Job kedua tidak mengubah apa pun lagi.
    assert await offer_service.expire_overdue() == 0


async def test_expire_overdue_skips_assigned(api, make_account, categories, upload_photo):
    owner = await make_account()
    tech = await make_account(role="TECHNICIAN")
    offer = await _offer(api, owner, categories, upload_photo)
    bid = await api.post(
        f"/offers/{offer['_id']}/bids", headers=tech.headers, json={"amount": 30_000}
    )
    await api.post(f"/bids/{bid.json()['_id']}/accept", headers=owner.headers)

    await db.offers.update_one(
        {"_id": ObjectId(offer["_id"])},
        {"$set": {"expires_at": utcnow() - timedelta(minutes=1)}},
    )

    # Offer yang sudah punya teknisi tidak boleh dimatikan oleh job.
    await offer_service.expire_overdue()
    saved = await db.offers.find_one({"_id": ObjectId(offer["_id"])})
    assert saved["status"] == "ASSIGNED"


async def test_withdraw_bid_returns_offer_to_waiting(
    api, make_account, categories, upload_photo
):
    owner = await make_account()
    tech = await make_account(role="TECHNICIAN")
    offer = await _offer(api, owner, categories, upload_photo)
    bid = await api.post(
        f"/offers/{offer['_id']}/bids", headers=tech.headers, json={"amount": 30_000}
    )

    withdrawn = await api.post(f"/bids/{bid.json()['_id']}/withdraw", headers=tech.headers)
    assert withdrawn.status_code == 200, withdrawn.text
    assert withdrawn.json()["status"] == "WITHDRAWN"

    # Tidak ada bid PENDING lagi -> offer terbuka kembali.
    detail = await api.get(f"/offers/{offer['_id']}", headers=owner.headers)
    assert detail.json()["status"] == "WAITING"
    assert detail.json()["bid_count"] == 0


async def test_withdraw_rejects_other_technician(
    api, make_account, categories, upload_photo
):
    owner = await make_account()
    tech = await make_account(role="TECHNICIAN")
    other = await make_account(role="TECHNICIAN")
    offer = await _offer(api, owner, categories, upload_photo)
    bid = await api.post(
        f"/offers/{offer['_id']}/bids", headers=tech.headers, json={"amount": 30_000}
    )

    response = await api.post(f"/bids/{bid.json()['_id']}/withdraw", headers=other.headers)
    assert response.status_code == 403
    assert response.json()["code"] == "NOT_BID_OWNER"


async def test_withdraw_accepted_bid_blocked(api, make_account, categories, upload_photo):
    owner = await make_account()
    tech = await make_account(role="TECHNICIAN")
    offer = await _offer(api, owner, categories, upload_photo)
    bid = await api.post(
        f"/offers/{offer['_id']}/bids", headers=tech.headers, json={"amount": 30_000}
    )
    await api.post(f"/bids/{bid.json()['_id']}/accept", headers=owner.headers)

    response = await api.post(f"/bids/{bid.json()['_id']}/withdraw", headers=tech.headers)
    assert response.status_code == 409
    assert response.json()["code"] == "BID_ALREADY_ACCEPTED"


async def test_reject_bid_keeps_offer_negotiating_until_all_rejected(
    api, make_account, categories, upload_photo
):
    owner = await make_account()
    tech_a = await make_account(role="TECHNICIAN")
    tech_b = await make_account(role="TECHNICIAN")
    offer = await _offer(api, owner, categories, upload_photo)

    bid_a = await api.post(
        f"/offers/{offer['_id']}/bids", headers=tech_a.headers, json={"amount": 30_000}
    )
    bid_b = await api.post(
        f"/offers/{offer['_id']}/bids", headers=tech_b.headers, json={"amount": 32_000}
    )

    rejected = await api.post(f"/bids/{bid_a.json()['_id']}/reject", headers=owner.headers)
    assert rejected.status_code == 200, rejected.text
    assert rejected.json()["status"] == "REJECTED"

    # Masih ada satu bid PENDING.
    detail = await api.get(f"/offers/{offer['_id']}", headers=owner.headers)
    assert detail.json()["status"] == "NEGOTIATING"
    assert detail.json()["bid_count"] == 1

    await api.post(f"/bids/{bid_b.json()['_id']}/reject", headers=owner.headers)
    detail = await api.get(f"/offers/{offer['_id']}", headers=owner.headers)
    assert detail.json()["status"] == "WAITING"
    assert detail.json()["bid_count"] == 0


async def test_reject_requires_offer_owner(api, make_account, categories, upload_photo):
    owner = await make_account()
    tech = await make_account(role="TECHNICIAN")
    offer = await _offer(api, owner, categories, upload_photo)
    bid = await api.post(
        f"/offers/{offer['_id']}/bids", headers=tech.headers, json={"amount": 30_000}
    )

    response = await api.post(f"/bids/{bid.json()['_id']}/reject", headers=tech.headers)
    assert response.status_code == 403
    assert response.json()["code"] == "NOT_OFFER_OWNER"
