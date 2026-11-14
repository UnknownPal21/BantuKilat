"""Job periodik ringan yang berjalan di dalam proses API.

Sengaja tanpa Celery/APScheduler: aplikasi ini jalan di satu container, dan
satu `asyncio.Task` cukup untuk pekerjaan yang tidak boleh telat berjam-jam.

Kalau nanti jalan lebih dari satu worker, job ini akan berjalan di tiap
worker. Keduanya aman karena operasinya idempoten (filter status diulang di
penulisan), hanya sedikit boros. Pindahkan ke cron terpisah kalau mau bersih.
"""

import asyncio
import logging

from backend.core.config import settings
from backend.services import offer_service

logger = logging.getLogger(__name__)


async def _loop() -> None:
    interval = max(settings.expire_check_seconds, 5)
    while True:
        try:
            changed = await offer_service.expire_overdue()
            if changed:
                logger.info("expire_overdue: %s tawaran kedaluwarsa", changed)
        except asyncio.CancelledError:
            raise
        except Exception:  # noqa: BLE001
            # Satu kegagalan (mis. Mongo putus sesaat) tidak boleh mematikan
            # job selamanya.
            logger.exception("expire_overdue gagal, dicoba lagi nanti")
        await asyncio.sleep(interval)


async def start() -> asyncio.Task | None:
    if not settings.expire_job_enabled:
        logger.info("job expire dimatikan (EXPIRE_JOB_ENABLED=false)")
        return None
    logger.info(
        "job expire aktif: cek tiap %s detik (EXPIRE_CHECK_SECONDS)",
        max(settings.expire_check_seconds, 5),
    )
    return asyncio.create_task(_loop(), name="expire-job")


async def stop(task: asyncio.Task | None) -> None:
    if task is None:
        return
    task.cancel()
    try:
        await task
    except asyncio.CancelledError:
        pass
