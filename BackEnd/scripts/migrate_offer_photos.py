"""Ubah foto lama yang tersimpan sebagai data URI/path menjadi id media.

Sebelum endpoint /media ada, `offers.photos` sempat diisi string base64
langsung dari Flutter. String itu tidak bisa dipakai Image.network, membuat
response offer membengkak, dan memakan kuota Atlas. Skrip ini memindahkannya
ke collection `media` tanpa menghapus foto.

Default hanya MELAPORKAN. Untuk benar-benar menulis:

    uv run python scripts/migrate_offer_photos.py --apply
"""

import argparse
import asyncio

from backend.db.mongo import client, db
from backend.services import media_service


def _is_legacy(value: str) -> bool:
    return not media_service.is_media_id(value)


async def migrate(apply: bool) -> None:
    cursor = db.offers.find(
        {"photos": {"$exists": True, "$ne": []}},
        {"photos": 1, "requester_id": 1, "title": 1},
    )

    all_offers = await cursor.to_list(length=5_000)
    # Filter di Python, bukan regex Mongo: daftar offer selalu kecil dan
    # regex di dalam $elemMatch mudah salah tulis.
    offers = [o for o in all_offers if any(_is_legacy(p) for p in o.get("photos") or [])]
    print(f"offer dengan foto lama: {len(offers)} dari {len(all_offers)} offer")

    for offer in offers:
        owner = {"_id": offer["requester_id"]}
        new_photos: list[str] = []
        converted = skipped = 0

        for value in offer.get("photos") or []:
            if not _is_legacy(value):
                new_photos.append(value)
                continue
            if not value.startswith("data:image/"):
                # Path seperti "media/offers/o1.jpg": filenya tidak pernah ada,
                # jadi tidak ada yang bisa diselamatkan.
                skipped += 1
                continue
            try:
                if apply:
                    saved = await media_service.save_image(owner, value)
                else:
                    saved = media_service.probe(value)
            except Exception as exc:  # noqa: BLE001 - laporkan, jangan hentikan batch
                print(f"  ! gagal decode: {exc}")
                skipped += 1
                continue
            if apply:
                new_photos.append(saved["id"])
            else:
                # Dry-run tidak menulis apa pun, jadi id belum ada; hitung
                # seolah berhasil supaya laporan tetap masuk akal.
                new_photos.append(f"<{saved['width']}x{saved['height']} {saved['size']}B>")
            converted += 1

        title = offer.get("title", "")
        print(
            f"- {offer['_id']} {title[:32]!r}: konversi={converted} "
            f"dibuang={skipped} sisa={len(new_photos)}"
        )

        if apply and converted and all(media_service.is_media_id(p) for p in new_photos):
            await db.offers.update_one(
                {"_id": offer["_id"]}, {"$set": {"photos": new_photos}}
            )
            await media_service.mark_used(new_photos)

    if not apply:
        print("\n(dry-run) tidak ada yang ditulis. Jalankan ulang dengan --apply.")


async def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    try:
        await migrate(args.apply)
        print("ringkasan media:", await db.media.count_documents({}))
    finally:
        await client.close()


if __name__ == "__main__":
    asyncio.run(main())
