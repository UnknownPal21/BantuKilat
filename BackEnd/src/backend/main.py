from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError

from backend.core.errors import (
    ApiError,
    api_error_handler,
    validation_error_handler,
)
from backend.db.mongo import client, close_client
from backend.routers.auth import router as auth_router
from backend.routers.categories import router as categories_router
from backend.routers.offers import router as offers_router


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    await client.admin.command("ping")
    yield
    await close_client()


app = FastAPI(lifespan=lifespan, title="BantuKilat API", version="0.1.0")
app.add_exception_handler(ApiError, api_error_handler)
app.add_exception_handler(RequestValidationError, validation_error_handler)

app.include_router(auth_router)
app.include_router(categories_router)
app.include_router(offers_router)


@app.get("/health")
def get_health():
    return {"status": "ok"}
