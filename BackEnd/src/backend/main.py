from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
import logging

from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError

from backend.core.config import settings
from backend.core.errors import (
    ApiError,
    api_error_handler,
    validation_error_handler,
)
from backend.core.scheduler import start as start_jobs
from backend.core.scheduler import stop as stop_jobs
from backend.db.mongo import client, close_client
from backend.db.setup import setup
from backend.routers.auth import router as auth_router
from backend.routers.ai import router as ai_router
from backend.routers.bids import router as bids_router
from backend.routers.categories import router as categories_router
from backend.routers.media import router as media_router
from backend.routers.offers import router as offers_router

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    await client.admin.command("ping")
    # Tanpa ini, instance baru di cloud tidak punya index 2dsphere, unique
    # index ai_usage, atau kategori yang di-seed -> /offers/nearby error dan
    # register offer gagal. Dijalankan di sini karena FastAPI Cloud tidak
    # menyediakan pre-start script.
    if settings.setup_on_startup:
        try:
            await setup()
        except Exception:  # noqa: BLE001
            logger.exception("setup database gagal saat startup")

    # Offer lewat expires_at diubah ke EXPIRED di latar belakang, supaya
    # daftar "tawaran saya" dan bid yang menggantung ikut beres.
    job = await start_jobs()
    try:
        yield
    finally:
        await stop_jobs(job)
        await close_client()


app = FastAPI(lifespan=lifespan, title="BantuKilat API", version="0.1.0")
app.add_exception_handler(ApiError, api_error_handler)
app.add_exception_handler(RequestValidationError, validation_error_handler)

app.include_router(auth_router)
app.include_router(ai_router)
app.include_router(bids_router)
app.include_router(categories_router)
app.include_router(media_router)
app.include_router(offers_router)


@app.get("/health")
def get_health():
    return {"status": "ok"}
