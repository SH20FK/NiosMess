"""Host integration without importing the legacy main module or its credentials."""

from __future__ import annotations

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from .auth import Authenticator
from .devices import create_devices_router
from .mailbox import DeliveryAuthorizer, create_mailbox_router
from .store import ProtocolStore
from .transparency import create_transparency_router


def install(app: FastAPI, store: ProtocolStore, authenticate: Authenticator, *,
            log_signing_key=None, log_id: str = "niosmess-key-log-v1",
            service_capabilities: dict | None = None,
            authorize_delivery: DeliveryAuthorizer | None = None) -> None:
    """Register additive routes. The host supplies central authentication.

    No native relay, independent witness, or MLS capability is inferred merely
    because an SDK is present. Enable extra capabilities after mounting and
    testing their actual service implementation.
    """
    app.include_router(create_devices_router(store, authenticate))
    app.include_router(create_mailbox_router(store, authenticate, authorize_delivery))
    if log_signing_key is not None:
        app.include_router(create_transparency_router(store, authenticate, log_signing_key, log_id=log_id))

    @app.middleware("http")
    async def private_protocol_responses(request: Request, call_next):
        response = await call_next(request)
        if request.url.path.startswith("/v1/"):
            response.headers["Cache-Control"] = "private, no-store"
            response.headers["X-Content-Type-Options"] = "nosniff"
        return response

    @app.get("/v1/protocols")
    async def capabilities(request: Request):
        await authenticate(request)
        result = {"link": [1], "stream": [], "mls": {"versions": [], "suites": []},
                  "ktStatements": [1, 2] if log_signing_key is not None else [],
                  "irohAlpn": [], "independentWitnesses": False,
                  "limits": {"envelopeBytes": 1_500_000, "inboxPage": 100}}
        result.update(service_capabilities or {})
        return JSONResponse(result, headers={"Cache-Control": "no-store"})


def create_app(store: ProtocolStore, authenticate: Authenticator, **configuration) -> FastAPI:
    app = FastAPI(title="NiosMess protocol v1", docs_url=None, redoc_url=None)
    install(app, store, authenticate, **configuration)
    return app
