"""Hitung ulang seluruh price_catalog dari price_samples.

Jalankan dari folder BackEnd setelah menambah/menghapus sampel manual:

    uv run python scripts/refresh_price_catalog.py
"""

import asyncio

from backend.db.mongo import client
from backend.services import price_service


async def main() -> None:
    try:
        rows = await price_service.refresh()
        print(f"{rows} baris katalog ditulis")
        print("ringkasan:", await price_service.summary())
    finally:
        await client.close()


if __name__ == "__main__":
    asyncio.run(main())
