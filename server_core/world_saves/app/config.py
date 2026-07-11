import secrets
from functools import lru_cache
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    DATABASE_URL: str = "sqlite+aiosqlite:///./messenger.db"
    SECRET_KEY: str = secrets.token_hex(32)
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440

    # AES-256 key — must be exactly 32 bytes (pad/truncate applied)
    ENCRYPTION_KEY: str = "default-32-byte-key-change-me!!"

    # SMTP — leave empty for dev-mode (codes printed to console)
    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_FROM: str = ""

    APP_HOST: str = "0.0.0.0"
    APP_PORT: int = 8443
    BASE_URL: str = "https://localhost:8443"
    UPLOAD_DIR: str = "static/uploads"
    FILES_DIR: str = "files"

    SSL_CERTFILE: str = "certs/cert.pem"
    SSL_KEYFILE: str = "certs/key.pem"

    # Super-admin password for /admin/* endpoints
    ADMIN_PASSWORD: str = "change-me-admin-password"

    # Media limits
    CHUNK_SIZE: int = 262144         # 128 KB per chunk
    CIRCLE_MAX_SECONDS: int = 30      # max circle-video duration

    class Config:
        env_file = ".env"


@lru_cache()
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
