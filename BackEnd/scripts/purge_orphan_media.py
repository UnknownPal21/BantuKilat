"""Hapus foto yang diunggah tapi tidak pernah dipakai offer/chat.

    uv run python scripts/purge_orphan_media.py              # laporan (dry-run)
    uv run python scripts/purge_orphan_media.py --apply      # hapus sungguhan
    uv run python scripts/purge_orphan_media.py --grace-hours 48

Foto dihitung terpakai setelah offer disimpan atau pesan AI berfoto terkirim
(`used_at` terisi). Foto dari pengguna yang batal di tengah jalan tidak pernah
mendapat `used_at`, dan itulah yang dibersihkan script ini.
"""

import argparse
import asyncio
import sys
from datetime import timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from backend.core.timeutils import as_utc, iso_utc, utcnow  # noqa: E402
from backend.db.mongo import client, db  # noqa: E402
from backend.services import ai_service  # noqa: E402


async def report(grace_hours: int, apply: bool) -> int:
    seconds = grace_hours * 3600
    now = utcnow()
    cutoff = now - timedelta(seconds=seconds)
    query = {"used_at": None, "created_at": {"$lt": cutoff}}

    total = await db.media.count_documents(query)
    size = 0
    ids = []
    async for doc in db.media.find(query, {"size": 1}):
        ids.append(doc["_id"])
        size += int(doc.get("size") or 0)

    print(f"kandidat yatim (> {grace_hours} jam, used_at null): {total}")
    print(f"perkiraan ruang terbuang: {size / 1024 / 1024:.2f} MB")

    oldest = await db.media.find_one(query, sort=[("created_at", 1)])
    if oldest:
        print("tertua:", iso_utc(as_utc(oldest["created_at"])))

    if not apply:
        print("dry-run: tidak ada yang dihapus (tambahkan --apply)")
        return 0

    # Logika penghapusan sama persis dengan job in-process, supaya script
    # tidak punya aturan sendiri yang bisa menyimpang.
    removed = await ai_service.purge_orphan_media(seconds, limit=max(len(ids), 1))
    print(f"dihapus: {removed}")
    return removed


async def main() -> None:
    parser = argparse.ArgumentParser(description="Bersihkan foto yatim")
    parser.add_argument("--apply", action="store_true", help="hapus sungguhan")
    parser.add_argument("--grace-hours", type=int, default=24, help="masa tenggang jam")
    args = parser.parse_args()

    try:
        await report(args.grace_hours, args.apply)
    finally:
        await client.close()


if __name__ == "__main__":
    asyncio.run(main())
