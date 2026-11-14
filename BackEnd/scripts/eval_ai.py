"""Generator eval untuk membandingkan dua config AI (model/prompt) tanpa provider.

Dipakai dari folder BackEnd:

    uv run python scripts/eval_ai.py                  # tabel hasil default
    uv run python scripts/eval_ai.py --csv hasil.csv  # simpan untuk diff

Setiap kasus memakai `ai_client.analyze` (tanpa key -> local-heuristic), jadi
script ini gratis. Untuk membandingkan model sungguhan, isi AI_API_KEY lalu
jalankan dengan `--provider`.
"""

import argparse
import asyncio
import csv
import sys
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from backend.core.config import settings  # noqa: E402
from backend.db.mongo import client, db  # noqa: E402
from backend.services import ai_client, ai_service  # noqa: E402

# Kasus minimal yang mencerminkan keluhan nyata. `want` adalah hasil yang
# diterima: kategori, dan severity bila penting.
CASES: list[dict] = [
    {"text": "Kran di bawah wastafel bocor, netes terus sejak pagi", "want": {"PLUMBING", "OTHER"}},
    {"text": "Pipa paralon jebol, air mengalir deras ke lantai dapur", "want": {"PLUMBING"}},
    {"text": "Kabel listrik di dapur terbakar dan berasap, MCB anjlok", "want": {"ELECTRICAL"}, "severity": "BERAT"},
    {"text": "Saklar kamar longgar, lampu kadang mati sendiri", "want": {"ELECTRICAL"}, "severity": "RINGAN"},
    {"text": "Laptop mati mendadak, ada bau gosong dari adaptor", "want": {"TECH"}, "severity": "BERAT"},
    {"text": "AC tidak dingin dan berisik saat dinyalakan", "want": {"TECH", "OTHER"}},
    {"text": "Motor tidak bisa distarter, aki sepertinya lemah", "want": {"VEHICLE", "OTHER"}},
    {"text": "Ban tubeless bocor halus setelah kena paku", "want": {"VEHICLE", "OTHER"}},
    {"text": "Butuh bantuan angkat kasur ke lantai dua", "want": {"MOVING"}},
    {"text": "Ada kerusakan barang di rumah, tolong dicek", "want": {"OTHER"}},
    {"text": "Tolong antar dokumen ke kantor pos", "want": {"OTHER"}},
    {"text": "Pagar besi berkarat dan engsel pintu macet", "want": {"OTHER", "CARPENTRY"}},
]


async def run(provider: bool, csv_path: str | None) -> int:
    if not provider:
        settings.ai_api_key = ""

    categories = await db.categories.find({"is_active": True}).to_list(20)
    city = "Surabaya"

    rows = []
    async def _one(case: dict) -> None:
        result, category, severity = await ai_service._classify(
            {"address": {"city": city}}, case["text"], []
        )
        if result.get("error"):
            rows.append(
                {
                    "text": case["text"],
                    "category": f"ERROR:{result['error']}",
                    "severity": "-",
                    "confidence": "-",
                    "ok": False,
                }
            )
            return

        within = category["code"] in case["want"]
        sev_ok = case.get("severity") in (None, severity)
        rows.append(
            {
                "text": case["text"],
                "category": category["code"],
                "severity": severity,
                "confidence": f"{ai_client.normalize_confidence(result.get('confidence')):.2f}",
                "ok": within and sev_ok,
            }
        )

    for case in CASES:
        await _one(case)

    width = min(52, max(len(row["text"]) for row in rows))
    print(f"model: {settings.ai_model} | provider: {'ya' if provider else 'lokal'}")
    print(f"{'kasus':{width}}  {'kategori':12} {'sev':7} {'conf':5} ok")
    print("-" * (width + 32))
    for row in rows:
        print(
            f"{row['text'][:width]:{width}}  {row['category']:12} "
            f"{row['severity']:7} {row['confidence']:5} {'✓' if row['ok'] else '✗'}"
        )

    passed = sum(1 for row in rows if row["ok"])
    print(f"\n{passed}/{len(rows)} sesuai harapan")

    if csv_path:
        with open(csv_path, "w", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
            writer.writeheader()
            writer.writerows(rows)
        print("csv:", csv_path)

    # Client ditutup di dalam loop yang sama; menutupnya dari loop lain
    # memicu RuntimeError pada AsyncMongoClient.
    await client.close()
    return 0 if passed == len(rows) else 1


def main() -> int:
    parser = argparse.ArgumentParser(description="Eval klasifikasi AI")
    parser.add_argument(
        "--provider",
        action="store_true",
        help="pakai provider sungguhan (butuh AI_API_KEY; berbayar)",
    )
    parser.add_argument("--csv", help="simpan hasil ke file CSV")
    args = parser.parse_args()

    code = asyncio.run(run(args.provider, args.csv))
    print("waktu:", datetime.now().isoformat(timespec="seconds"))
    return code


if __name__ == "__main__":
    raise SystemExit(main())
