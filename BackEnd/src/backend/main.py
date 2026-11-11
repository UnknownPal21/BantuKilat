from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from backend.routers.auth import router as auth_router

from fastapi import FastAPI

from backend.core.errors import ApiError, api_error_handler
from backend.db.mongo import client, close_client


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    await client.admin.command("ping")
    yield
    await close_client()


app = FastAPI(lifespan=lifespan, title="BantuKilatAPI", version="0.1.0")
app.add_exception_handler(ApiError, api_error_handler)

app.include_router(auth_router)


@app.get("/health")
def get_health():
    return {"status": "ok"}
