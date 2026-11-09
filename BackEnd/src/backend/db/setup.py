from backend.db.mongo import db
import asyncio


async def ensure_indexes():
    await db.users.create_index("email", unique=True)
    await db.users.create_index(
        "phone", unique=True, partialFilterExpression={"phone": {"$type": "string"}}
    )
    await db.users.create_index(
        "google_sub",
        unique=True,
        partialFilterExpression={"google_sub": {"$type": "string"}},
    )
    await db.users.create_index("password_reset.token_hash", sparse=True)
    print(await db.users.index_information())


if __name__ == "__main__":
    asyncio.run(ensure_indexes())
