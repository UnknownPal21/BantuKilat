from pymongo import AsyncMongoClient

from backend.core.config import settings

client = AsyncMongoClient(
    settings.mongo_url, serverSelectionTimeoutMS=settings.server_selection_timeout_ms
)


db = client[settings.mongo_db_name]


async def close_client() -> None:
    await client.close()
