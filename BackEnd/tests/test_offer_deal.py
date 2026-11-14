"""Offer → bid → accept → complete: sampel harga DEAL tersimpan sekali."""

from bson import ObjectId

from backend.db.mongo import db


async def test_completed_offer_records_deal_sample_once(
    api, make_account, upload_photo, categories
):
    requester = await make_account()
    technician = await make_account(role="TECHNICIAN")
    media = await upload_photo(requester)
    cat = await categories()

    created = await api.post(
        "/offers",
        headers=requester.headers,
        json={
            "category_id": cat["PLUMBING"],
            "title": "Pipa wastafel bocor deras",
            "description": "Sambungan paralon lepas, air mengalir ke lantai dapur.",
            "photos": [media["url"]],
            "lng": 112.7531,
            "lat": -7.2412,
            "address_text": "RT 02 No. 14",
            "initial_budget": 15000,
        },
    )
    assert created.status_code == 201, created.text
    offer = created.json()
    assert offer["status"] == "WAITING"

    bid = await api.post(
        f"/offers/{offer['_id']}/bids",
        headers=technician.headers,
        json={"amount": 185_000, "message": "bisa sore ini"},
    )
    assert bid.status_code == 200, bid.text
    bid_id = bid.json()["_id"]

    accepted = await api.post(f"/bids/{bid_id}/accept", headers=requester.headers)
    assert accepted.status_code == 200, accepted.text
    assert accepted.json()["agreed_price"] == 185_000

    before = await db.price_samples.count_documents({"source": "DEAL"})
    completed = await api.post(
        f"/offers/{offer['_id']}/complete", headers=technician.headers
    )
    assert completed.status_code == 200, completed.text
    after = await db.price_samples.count_documents({"source": "DEAL"})
    assert after == before + 1

    sample = await db.price_samples.find_one({"offer_id": ObjectId(offer["_id"])})
    assert sample["amount"] == 185_000
    assert sample["city"] == "surabaya"

    # Katalog ikut diperbarui tanpa menunggu script manual.
    catalog = await db.price_catalog.find_one(
        {
            "category_code": "PLUMBING",
            "severity": sample["severity"],
            "city": "surabaya",
        }
    )
    assert catalog is not None
    assert catalog["sample_count"] >= 1

    # Pemanggilan ulang oleh teknisi yang sama = retry idempoten: tidak
    # menggandakan sampel dan tidak menghitung statistik dua kali.
    again = await api.post(
        f"/offers/{offer['_id']}/complete", headers=technician.headers
    )
    assert again.status_code == 200, again.text
    assert await db.price_samples.count_documents({"source": "DEAL"}) == after

    # User lain tetap ditolak.
    stranger = await make_account(role="TECHNICIAN")
    blocked = await api.post(
        f"/offers/{offer['_id']}/complete", headers=stranger.headers
    )
    assert blocked.status_code == 409
    assert blocked.json()["code"] == "OFFER_ALREADY_COMPLETED"
