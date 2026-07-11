"""HTTP dev server — reads port from .env, hot-reload enabled."""
import uvicorn
from app.config import settings

if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host=settings.APP_HOST,
        port=settings.APP_PORT,
        reload=True,
        log_level="debug",
    )
