from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    mongo_url: str
    mongo_db_name: str
    jwt_secret: str
    jwt_expire_minutes: int = 1440
    server_selection_timeout_ms: int = 5000

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    @field_validator("jwt_secret")
    @classmethod
    def check_secret(cls, v: str) -> str:
        if len(v) < 32:
            raise ValueError("JWT_SECRET minimal 32 karakter")
        return v


settings = Settings()
