"""Penghitung harian per hari kalender, dengan zona waktu offset UTC.

Dipakai untuk kuota yang tidak mau membebani database (mis. POST /media).
Kuota chat/estimate tetap di MongoDB karena harus benar walau proses
di-restart atau berjalan di beberapa worker.
"""

import time
from collections import defaultdict

from backend.core.errors import ApiError


class DayCounter:
    def __init__(self, offset_hours: int) -> None:
        self.offset_hours = offset_hours
        self._counts: dict[tuple[str, str], int] = defaultdict(int)

    def day_key(self) -> str:
        shifted = time.time() + self.offset_hours * 3600
        return time.strftime("%Y-%m-%d", time.gmtime(shifted))

    def used(self, identity: str) -> int:
        return self._counts.get((self.day_key(), identity), 0)

    def reserve(self, identity: str, limit: int, label: str, code: str) -> None:
        if limit <= 0:
            return
        key = (self.day_key(), identity)
        if self._counts[key] >= limit:
            raise ApiError(
                429, code, f"Batas {limit} {label} per hari sudah tercapai"
            )
        self._counts[key] += 1

    def reset(self) -> None:
        self._counts.clear()
