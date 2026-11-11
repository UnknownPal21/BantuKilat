from fastapi import Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse


class ApiError(Exception):
    def __init__(self, status_code: int, code: str, message: str) -> None:
        self.status_code = status_code
        self.code = code
        self.message = message
        super().__init__(message)


async def api_error_handler(request: Request, exc: ApiError) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status_code, content={"code": exc.code, "message": exc.message}
    )


def _clean_errors(exc: RequestValidationError) -> list[dict]:
    # exc.errors() bisa memuat objek Python di ctx (mis. ValueError) yang
    # tidak bisa di-JSON-kan. Ambil tiga field yang aman saja.
    return [
        {
            "loc": [str(part) for part in err.get("loc", [])],
            "msg": err.get("msg", "Nilai tidak valid"),
            "type": err.get("type", ""),
        }
        for err in exc.errors()
    ]


async def validation_error_handler(
    request: Request, exc: RequestValidationError
) -> JSONResponse:
    errors = _clean_errors(exc)
    # Pesan pertama untuk ditampilkan Flutter; `errors` untuk menandai field.
    message = "Data tidak valid"
    if errors:
        loc = ".".join(part for part in errors[0]["loc"] if part != "body")
        message = f"{loc}: {errors[0]['msg']}" if loc else errors[0]["msg"]

    return JSONResponse(
        status_code=422,
        content={"code": "VALIDATION_ERROR", "message": message, "errors": errors},
    )
