"""Production server — uses SSL if certs exist, otherwise HTTP."""
import os
import uvicorn
from app.config import settings

if __name__ == "__main__":
    ssl_args = {}
    if os.path.exists(settings.SSL_CERTFILE) and os.path.exists(settings.SSL_KEYFILE):
        ssl_args["ssl_certfile"] = settings.SSL_CERTFILE
        ssl_args["ssl_keyfile"]  = settings.SSL_KEYFILE
        print(f"[HTTPS] Running on https://{settings.APP_HOST}:{settings.APP_PORT}")
    else:
        print(f"[HTTP]  Running on http://{settings.APP_HOST}:{settings.APP_PORT}")

    uvicorn.run(
        "app.main:app",
        host=settings.APP_HOST,
        port=settings.APP_PORT,
        reload=False,
        log_level="info",
        **ssl_args,
    )
