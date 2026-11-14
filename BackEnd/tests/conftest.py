"""Fixture bersama untuk seluruh tes.

Penting: tes TIDAK menyentuh database aplikasi. Nama database dipaksa ke
`bantukilat_test` (atau `TEST_MONGO_DB_NAME`) SEBELUM modul backend diimpor,
karena `backend.core.config.settings` membaca environment saat import.
"""

import os

TEST_DB = os.environ.get("TEST_MONGO_DB_NAME", "bantukilat_test")
os.environ["MONGO_DB_NAME"] = TEST_DB
# Tes tidak boleh memanggil provider berbayar. Tes yang ingin menguji jalur
# provider memakai base URL lokal yang pasti gagal (127.0.0.1:9).
os.environ["AI_API_KEY"] = ""
# Job latar belakang mengubah offer milik tes di tengah jalan; tes memanggil
# `expire_overdue()` langsung saat ingin mengujinya.
os.environ["EXPIRE_JOB_ENABLED"] = "false"

import itertools  # noqa: E402
import time  # noqa: E402
from dataclasses import dataclass  # noqa: E402

import httpx  # noqa: E402
import pytest  # noqa: E402

from backend.db.mongo import client, db  # noqa: E402
from backend.db.setup import setup  # noqa: E402
from backend.main import app  # noqa: E402
from backend.services import price_service  # noqa: E402
from tests.helpers import PNG_DATA_URI  # noqa: E402


@dataclass
class Account:
    id: str
    email: str
    headers: dict


async def _seed_prices() -> None:
    """Cukup sampel supaya band kota dan nasional sama-sama lolos n>=20."""
    plan = {
        "PLUMBING": ("SEDANG", 120_000, 6_000),
        "TECH": ("BERAT", 250_000, 18_000),
        "ELECTRICAL": ("BERAT", 150_000, 9_000),
        # Kategori netral juga punya data: dipakai tes bahwa kata "barang"
        # tidak lagi memetakan ke MOVING.
        "OTHER": ("SEDANG", 90_000, 4_000),
        # Sengaja ada: kalau "barang" kembali masuk daftar MOVING, tes akan
        # menerima blok harga MOVING dan gagal.
        "MOVING": ("SEDANG", 100_000, 5_000),
    }
    for code, (severity, base, step) in plan.items():
        for index in range(40):
            await price_service.record_sample(
                code, severity, "Surabaya", base + index * step, "SEED"
            )
    await price_service.refresh()


@pytest.fixture(scope="session", autouse=True)
async def prepared_database():
    # Jaring pengaman: jangan pernah menjalankan tes di DB aplikasi.
    assert db.name == TEST_DB and db.name.endswith("_test"), db.name
    await client.drop_database(db.name)
    await setup()
    await _seed_prices()
    yield
    await client.drop_database(db.name)
    await client.close()


@pytest.fixture
async def api():
    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


@pytest.fixture
def make_account(api):
    counter = itertools.count()

    async def _make(
        role: str = "USER",
        city: str = "Surabaya",
        district: str = "Mulyorejo",
    ) -> Account:
        tag = f"{int(time.time() * 1000)}x{next(counter)}"
        payload = {
            "role": role,
            "name": f"Pytest {role} {tag}",
            "email": f"pytest.{tag}@example.com",
            "phone": f"+6289{abs(hash(tag)) % 10**9:09d}",
            "password": "rahasia123",
            "city": city,
            "district": district,
        }
        if role == "TECHNICIAN":
            payload["skills"] = ["PLUMBING"]
            payload["terms_accepted"] = True

        response = await api.post("/auth/register", json=payload)
        assert response.status_code == 201, response.text
        body = response.json()
        return Account(
            id=body["user"]["_id"],
            email=payload["email"],
            headers={"Authorization": f"Bearer {body['access_token']}"},
        )

    return _make


@pytest.fixture
async def upload_photo(api):
    async def _upload(account: Account, data: str = PNG_DATA_URI) -> dict:
        response = await api.post(
            "/media", headers=account.headers, json={"data": data, "kind": "ai"}
        )
        assert response.status_code == 200, response.text
        return response.json()

    return _upload


@pytest.fixture
def categories(api):
    async def _categories() -> dict:
        response = await api.get("/categories")
        assert response.status_code == 200, response.text
        return {item["code"]: item["_id"] for item in response.json()}

    return _categories
