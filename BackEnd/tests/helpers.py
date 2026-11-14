"""Data uji yang dipakai beberapa modul tes."""

import base64
import io

from PIL import Image


def png_bytes() -> bytes:
    img = Image.new("RGB", (900, 600), (235, 235, 235))
    for x in range(0, 900, 90):
        for y in range(0, 600, 90):
            if (x // 90 + y // 90) % 2 == 0:
                img.paste((30, 90, 200), (x, y, min(x + 90, 900), min(y + 90, 600)))
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


PNG_BYTES = png_bytes()
PNG_DATA_URI = "data:image/png;base64," + base64.b64encode(PNG_BYTES).decode()
