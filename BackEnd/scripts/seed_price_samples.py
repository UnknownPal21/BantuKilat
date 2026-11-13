"""Isi price_samples dengan data demo, lalu hitung ulang price_catalog.

Jalankan dari folder BackEnd:

    uv run python scripts/seed_price_samples.py

Idempoten: semua dokumen `source: "SEED"` dihapus lebih dulu. Data nyata
(`users`, `offers`, `bids`, sampel `DEAL`) tidak disentuh sama sekali.
Menghapus data demo = `delete_many({"source": "SEED"})` lalu refresh.
"""

import asyncio
import math
import random

from backend.core.timeutils import utcnow
from backend.db.mongo import client, db
from backend.db.setup import ensure_prices
from backend.services import price_service

# (p25, p75) dalam rupiah, dari riset harga jasa ringan di desain §10.
BASE_PRICE: dict[str, dict[str, tuple[int, int]]] = {
    "ELECTRICAL": {
        "RINGAN": (50_000, 100_000),
        "SEDANG": (100_000, 250_000),
        "BERAT": (250_000, 600_000),
    },
    "PLUMBING": {
        "RINGAN": (50_000, 125_000),
        "SEDANG": (125_000, 300_000),
        "BERAT": (300_000, 750_000),
    },
    "VEHICLE": {
        "RINGAN": (40_000, 90_000),
        "SEDANG": (90_000, 200_000),
        "BERAT": (200_000, 500_000),
    },
    "MOVING": {
        "RINGAN": (75_000, 150_000),
        "SEDANG": (150_000, 350_000),
        "BERAT": (350_000, 800_000),
    },
    "TECH": {
        "RINGAN": (75_000, 150_000),
        "SEDANG": (150_000, 400_000),
        "BERAT": (400_000, 900_000),
    },
    "CARPENTRY": {
        "RINGAN": (60_000, 120_000),
        "SEDANG": (120_000, 300_000),
        "BERAT": (300_000, 700_000),
    },
    "OTHER": {
        "RINGAN": (40_000, 100_000),
        "SEDANG": (100_000, 200_000),
        "BERAT": (200_000, 400_000),
    },
}

# Indeks kemahalan kota, cukup untuk membuat band kota berbeda dari nasional.
CITY_FACTOR = {"Surabaya": 1.00, "Jakarta": 1.18, "Bandung": 0.95}

PER_CELL = 40
RANDOM_SEED = 42
BATCH = 1_000

# 1.349 = 2 * 0.6745: jarak p25-p75 dari median pada distribusi normal,
# sehingga lognormal yang dihasilkan benar-benar berpusat di tabel di atas.
_IQR_TO_SIGMA = 1.349


def _samples_for(low: int, high: int, factor: float, rng: random.Random) -> list[int]:
    median = math.sqrt(low * high) * factor
    sigma = math.log(high / low) / _IQR_TO_SIGMA

    values: list[int] = []
    for _ in range(PER_CELL):
        raw = median * math.exp(rng.gauss(0, sigma))
        # Jangan biarkan ekor distribusi keluar jauh dari rentang wajar:
        # satu angka 5 juta akan merusak p75 selamanya.
        clipped = min(max(raw, low * 0.7 * factor), high * 1.4 * factor)
        values.append(price_service.round_price(clipped))
    return values


async def seed() -> int:
    await ensure_prices()

    removed = await db.price_samples.delete_many({"source": "SEED"})
    print(f"hapus sampel SEED lama: {removed.deleted_count}")

    rng = random.Random(RANDOM_SEED)
    now = utcnow()
    docs: list[dict] = []

    for code, per_severity in BASE_PRICE.items():
        for severity, (low, high) in per_severity.items():
            for city, factor in CITY_FACTOR.items():
                for amount in _samples_for(low, high, factor, rng):
                    docs.append(
                        {
                            "category_code": code,
                            "severity": severity,
                            "city": city.lower(),
                            "amount": amount,
                            "source": "SEED",
                            "offer_id": None,
                            "created_at": now,
                        }
                    )

    for start in range(0, len(docs), BATCH):
        await db.price_samples.insert_many(docs[start : start + BATCH])

    rows = await price_service.refresh()
    print(f"insert {len(docs)} sampel, tulis {rows} baris katalog")
    return len(docs)


async def main() -> None:
    try:
        await seed()
        print("ringkasan:", await price_service.summary())
    finally:
        await client.close()


if __name__ == "__main__":
    asyncio.run(main())
