import math
from collections import defaultdict

from backend.core.timeutils import utcnow
from backend.db.mongo import db

# Jumlah sampel minimum sebelum sebuah sel dianggap layak dipakai. Di bawah
# angka ini, rentang harga terlalu lebar untuk ditampilkan sebagai perkiraan.
MIN_SAMPLES = 20

ROUND_TO = 5_000


def city_key(value: str | None) -> str | None:
    """Kunci kota selalu lowercase supaya 'Surabaya' dan 'surabaya' satu sel."""
    if not value:
        return None
    key = value.strip().lower()
    return key or None


def round_price(value: float) -> int:
    return max(ROUND_TO, int(math.ceil(value / ROUND_TO) * ROUND_TO))


def percentile(values: list[int], q: float) -> int:
    """Persentil dengan interpolasi linear (metode yang sama dengan numpy)."""
    ordered = sorted(values)
    if not ordered:
        return 0
    if len(ordered) == 1:
        return ordered[0]
    pos = (len(ordered) - 1) * q
    low = math.floor(pos)
    high = math.ceil(pos)
    if low == high:
        return ordered[int(pos)]
    return round(ordered[low] * (high - pos) + ordered[high] * (pos - low))


def _catalog_row(values: list[int], category_code: str, severity: str, city: str | None) -> dict:
    return {
        "category_code": category_code,
        "severity": severity,
        "city": city,
        "min": round_price(percentile(values, 0.25)),
        "median": round_price(percentile(values, 0.50)),
        "max": round_price(percentile(values, 0.75)),
        "absolute_min": min(values),
        "absolute_max": max(values),
        "sample_count": len(values),
        "computed_at": utcnow(),
    }


async def record_sample(
    category_code: str,
    severity: str,
    city: str | None,
    amount: int,
    source: str,
    offer_id=None,
) -> bool:
    """Simpan satu kejadian harga. Return False kalau offer itu sudah tercatat.

    Unique index parsial {offer_id} untuk source DEAL mencegah satu offer
    dihitung dua kali saat tombol complete tidak sengaja ditekan ulang.
    """
    from pymongo.errors import DuplicateKeyError

    doc = {
        "category_code": category_code,
        "severity": severity,
        "city": city_key(city),
        "amount": int(amount),
        "source": source,
        "offer_id": offer_id,
        "created_at": utcnow(),
    }
    try:
        await db.price_samples.insert_one(doc)
    except DuplicateKeyError:
        return False
    return True


async def _group(
    category_code: str | None = None, severity: str | None = None
) -> dict[tuple[str, str, str | None], list[int]]:
    match: dict = {}
    if category_code is not None:
        match["category_code"] = category_code
    if severity is not None:
        match["severity"] = severity

    grouped: dict[tuple[str, str, str | None], list[int]] = defaultdict(list)
    cursor = db.price_samples.find(match, {"category_code": 1, "severity": 1, "city": 1, "amount": 1})
    async for sample in cursor:
        code = sample["category_code"]
        sev = sample["severity"]
        # Baris kota.
        grouped[(code, sev, sample.get("city"))].append(sample["amount"])
        # Baris nasional: gabungan semua sampel lintas kota. Dihitung ulang
        # setiap refresh supaya tidak perlu collection agregat terpisah.
        grouped[(code, sev, None)].append(sample["amount"])
    return grouped


async def refresh(
    category_code: str | None = None, severity: str | None = None
) -> int:
    """Hitung ulang price_catalog dari price_samples.

    Dipanggil setelah seed dan setiap ada deal baru. With category_code +
    severity terisi, hanya sel itu (plus baris nasionalnya) yang dihitung,
    jadi biayanya tetap kecil walau data tumbuh.
    """
    grouped = await _group(category_code, severity)
    computed_at = utcnow()
    written = 0

    for (code, sev, city), amounts in grouped.items():
        row = _catalog_row(amounts, code, sev, city)
        row["computed_at"] = computed_at
        await db.price_catalog.update_one(
            {"category_code": code, "severity": sev, "city": city},
            {"$set": row},
            upsert=True,
        )
        written += 1

    # Baris yang sampelnya sudah tidak ada (mis. seed dihapus) jangan
    # ditinggal jadi harga hantu.
    if category_code is None and severity is None:
        await db.price_catalog.delete_many({"computed_at": {"$lt": computed_at}})
    return written


async def lookup(
    category_code: str, severity: str, city: str | None
) -> dict | None:
    """Pilih band harga: kota (n>=20) -> nasional (n>=20) -> None."""
    key = city_key(city)
    if key is not None:
        row = await db.price_catalog.find_one(
            {"category_code": category_code, "severity": severity, "city": key}
        )
        if row is not None and row.get("sample_count", 0) >= MIN_SAMPLES:
            return row

    row = await db.price_catalog.find_one(
        {"category_code": category_code, "severity": severity, "city": None}
    )
    if row is not None and row.get("sample_count", 0) >= MIN_SAMPLES:
        return row
    return None


async def summary() -> dict:
    return {
        "samples": await db.price_samples.count_documents({}),
        "catalog_rows": await db.price_catalog.count_documents({}),
        "seed_samples": await db.price_samples.count_documents({"source": "SEED"}),
        "deal_samples": await db.price_samples.count_documents({"source": "DEAL"}),
    }
