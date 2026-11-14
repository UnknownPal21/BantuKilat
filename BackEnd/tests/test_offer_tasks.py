"""GET /offers/tasks: daftar tugas teknisi.

`/offers/nearby` sengaja hanya berisi offer terbuka (WAITING/NEGOTIATING) untuk
radar bid, jadi tanpa endpoint ini tugas yang sudah ASSIGNED/COMPLETED tidak
pernah bisa ditampilkan di aplikasi teknisi.
"""


async def _offer(api, owner, categories, upload_photo) -> dict:
    media = await upload_photo(owner)
    cats = await categories()
    response = await api.post(
        "/offers",
        headers=owner.headers,
        json={
            "category_id": cats["PLUMBING"],
            "title": "Kran wastafel bocor",
            "description": "Air menetes terus sejak pagi, lantai basah.",
            "photos": [media["id"]],
            "lng": 112.7531,
            "lat": -7.2412,
            "address_text": "RT 02 No. 14",
            "initial_budget": 20_000,
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


async def _assign(api, owner, tech, offer) -> dict:
    bid = await api.post(
        f"/offers/{offer['_id']}/bids",
        headers=tech.headers,
        json={"amount": 30_000},
    )
    assert bid.status_code == 200, bid.text
    accepted = await api.post(
        f"/bids/{bid.json()['_id']}/accept", headers=owner.headers
    )
    assert accepted.status_code == 200, accepted.text
    return accepted.json()


async def test_tasks_contains_assigned_offer(
    api, make_account, categories, upload_photo
):
    owner = await make_account()
    tech = await make_account(role="TECHNICIAN")
    offer = await _offer(api, owner, categories, upload_photo)
    await _assign(api, owner, tech, offer)

    response = await api.get("/offers/tasks", headers=tech.headers)
    assert response.status_code == 200, response.text
    body = response.json()
    assert [item["_id"] for item in body] == [offer["_id"]]
    assert body[0]["status"] == "ASSIGNED"
    # Offer ASSIGNED tidak muncul di nearby; itulah alasan endpoint ini ada.
    nearby = await api.get(
        "/offers/nearby",
        headers=tech.headers,
        params={"lng": 112.7531, "lat": -7.2412},
    )
    assert nearby.status_code == 200
    assert offer["_id"] not in [item["_id"] for item in nearby.json()]


async def test_tasks_contains_completed_offer(
    api, make_account, categories, upload_photo
):
    owner = await make_account()
    tech = await make_account(role="TECHNICIAN")
    offer = await _offer(api, owner, categories, upload_photo)
    await _assign(api, owner, tech, offer)

    completed = await api.post(
        f"/offers/{offer['_id']}/complete", headers=tech.headers
    )
    assert completed.status_code == 200, completed.text

    response = await api.get(
        "/offers/tasks", headers=tech.headers, params={"status": "COMPLETED"}
    )
    assert response.status_code == 200, response.text
    assert [item["_id"] for item in response.json()] == [offer["_id"]]


async def test_tasks_only_returns_own_tasks(
    api, make_account, categories, upload_photo
):
    owner = await make_account()
    tech = await make_account(role="TECHNICIAN")
    other = await make_account(role="TECHNICIAN")
    offer = await _offer(api, owner, categories, upload_photo)
    await _assign(api, owner, tech, offer)

    response = await api.get("/offers/tasks", headers=other.headers)
    assert response.status_code == 200, response.text
    assert response.json() == []


async def test_tasks_rejects_non_technician(
    api, make_account, categories, upload_photo
):
    owner = await make_account()
    offer = await _offer(api, owner, categories, upload_photo)
    assert offer["_id"]

    response = await api.get("/offers/tasks", headers=owner.headers)
    assert response.status_code == 403
    assert response.json()["code"] == "FORBIDDEN"
