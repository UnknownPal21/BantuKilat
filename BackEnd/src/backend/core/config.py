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
