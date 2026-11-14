from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    mongo_url: str
    mongo_db_name: str
    jwt_secret: str
    jwt_expire_minutes: int = 1440
    server_selection_timeout_ms: int = 5000

    # Dipakai untuk membangun URL absolut foto di response. Di production isi
    # dengan domain asli (mis. https://xxx.fastapicloud.dev).
    public_base_url: str = "http://localhost:8000"

    # Batas ukuran body upload foto. Cek panjang string dilakukan SEBELUM
    # base64 di-decode supaya request raksasa tidak mengalokasikan memori.
    media_max_input_chars: int = 8_000_000
    media_max_bytes: int = 6_000_000
    # URL foto ditandatangani dan kedaluwarsa. GET /media/{id} tanpa tanda
    # tangan yang sah ditolak, supaya id yang bocor lewat log/riwayat tidak
    # cukup untuk membuka foto. Response selalu membuat tanda tangan baru,
    # jadi umur ini hanya membatasi tautan yang sudah terlanjur dibagikan.
    media_url_ttl_seconds: int = 3600
    # Batas baca/unggah foto per user per hari. Endpoint baca tanpa auth tidak
    # boleh jadi alat scraping; batas unggah mencegah M0 penuh oleh satu akun.
    media_daily_view_limit: int = 600
    media_daily_upload_limit: int = 60

    # Job latar belakang yang mengubah offer lewat expires_at menjadi EXPIRED.
    # Test mematikannya supaya data uji tidak berubah di tengah tes.
    expire_job_enabled: bool = True
    expire_check_seconds: int = 60

    # FastAPI Cloud tidak punya hook pre-start: index, validator, dan seed
    # kategori dipasang saat startup. Aman dijalankan banyak instance karena
    # semua operasi di setup() idempoten (createIndex / upsert per code).
    # Kegagalan di sini dicatat sebagai warning, bukan mematikan server: app
    # tetap bisa melayani endpoint yang tidak butuh collection baru.
    setup_on_startup: bool = True

    # Provider AI apa pun yang bicara protokol OpenAI-compatible. Default
    # Gemini; ganti tiga nilai ini untuk pindah ke OpenAI/OpenRouter/Groq
    # tanpa menyentuh kode.
    ai_base_url: str = "https://generativelanguage.googleapis.com/v1beta/openai"
    ai_api_key: str = ""
    ai_model: str = "gemini-2.5-flash"
    ai_timeout_seconds: float = 30.0
    # Kalau key kosong, server memakai pengklasifikasi kata kunci lokal supaya
    # demo tetap jalan tanpa biaya. Labelnya jujur: model = "local-heuristic".
    ai_allow_local_fallback: bool = True
    ai_daily_message_limit: int = 20
    # /ai/estimate tidak menyimpan pesan, jadi dihitung terpisah. Tanpa batas
    # ini satu akun bisa memanggil provider berbayar tanpa henti.
    ai_daily_estimate_limit: int = 40
    # Kuota di-reset pada tengah malam zona ini (7 = WIB), bukan 00:00 UTC
    # yang jatuh jam 07:00 pagi di Indonesia.
    ai_quota_utc_offset_hours: int = 7
    # Kuota PUTARAN sendiri: satu putaran percakapan bisa memuat beberapa
    # gambar, dan biayanya jauh lebih besar daripada teks saja.
    ai_daily_photo_message_limit: int = 10
    # Jumlah pesan lama yang dikirim ulang sebagai konteks percakapan.
    ai_history_messages: int = 10

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    @field_validator("jwt_secret")
    @classmethod
    def check_secret(cls, v: str) -> str:
        if len(v) < 32:
            raise ValueError("JWT_SECRET minimal 32 karakter")
        return v


settings = Settings()
