import os, json
from fastapi import FastAPI, HTTPException, Body
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import JSONResponse, FileResponse
from app.database import init_db
from app.config import settings
from app.routers import auth, profile, chats, messages, search, invite, calls, admin, ai
from pydantic import BaseModel
@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    for sub in ["avatars", "media", "temp", "voices", "circles"]:
        os.makedirs(os.path.join(settings.UPLOAD_DIR, sub), exist_ok=True)
    os.makedirs(settings.FILES_DIR, exist_ok=True)
    yield

app = FastAPI(
    title="Messenger API",
    description="Encrypted async messenger — FastAPI + AES-256-GCM",
    version="2.0.0",
    lifespan=lifespan,
)

app.add_middleware(CORSMiddleware, allow_origins=["*"],
                   allow_credentials=True, allow_methods=["*"], allow_headers=["*"])

# Static media files
app.mount("/static", StaticFiles(directory=settings.UPLOAD_DIR), name="static")

# API routers
for r in [auth.router, profile.router, chats.router, messages.router,
          search.router, calls.router, admin.router, ai.router]:
    app.include_router(r, prefix="/api/v1")

# Invite join routes at root (no /api/v1 prefix — for share links)
app.include_router(invite.router)

# ── Web frontend ──────────────────────────────────────────────────────────────
SAVES_DIR = "world_saves"

if not os.path.exists(SAVES_DIR):
    os.makedirs(SAVES_DIR)

# --- 1. ОБРАБОТЧИК СОХРАНЕНИЯ ---
@app.post("/save")
async def save(request: Request):
    try:
        # Получаем сырой JSON
        payload = await request.json()
        owner_id = payload.get("ownerId")
        
        if not owner_id:
            raise HTTPException(status_code=400, detail="Missing ownerId")

        file_path = os.path.join(SAVES_DIR, f"{owner_id}.json")

        # Если это ПАКЕТНАЯ загрузка (chunkPos есть в запросе)
        if "chunkPos" in payload:
            world_data = {"ownerId": owner_id, "data": "[]"}
            
            # Читаем существующий файл старым добрым open()
            if os.path.exists(file_path):
                with open(file_path, "r", encoding="utf-8") as f:
                    world_data = json.load(f)
            
            chunks = json.loads(world_data["data"])
            
            # Обновляем чанк или добавляем новый
            new_chunk = {
                "p": payload["chunkPos"],
                "s": payload["vSize"],
                "d": payload["data"]
            }
            
            # Ищем, нет ли уже такого чанка, чтобы не плодить дубли
            found = False
            for i, c in enumerate(chunks):
                if c["p"] == payload["chunkPos"]:
                    chunks[i] = new_chunk
                    found = True
                    break
            
            if not found:
                chunks.append(new_chunk)
            
            world_data["data"] = json.dumps(chunks)
            
            # Пишем обратно
            with open(file_path, "w", encoding="utf-8") as f:
                json.dump(world_data, f, indent=4)
                
            return {"status": "success", "mode": "partial"}

        # Если это ПОЛНАЯ перезапись
        else:
            with open(file_path, "w", encoding="utf-8") as f:
                json.dump(payload, f, indent=4)
            return {"status": "success", "mode": "full"}

    except Exception as e:
        print(f"Ошибка сохранения: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# --- 2. ОБРАБОТЧИК ЗАГРУЗКИ ---
@app.get("/load/{owner_id}")
async def load(owner_id: str):
    file_path = os.path.join(SAVES_DIR, f"{owner_id}.json")
    
    if not os.path.exists(file_path):
        # Возвращаем 404, чтобы Lua-скрипт понял, что файла нет
        raise HTTPException(status_code=404, detail="Not Found")
    
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        return data
    except Exception as e:
        raise HTTPException(status_code=500, detail="Read Error")

@app.get("/", include_in_schema=False)
async def serve_index():
    """Serve the web client from files/index.html."""
    index = os.path.join(settings.FILES_DIR, "index.html")
    if os.path.exists(index):
        return FileResponse(index)
    return JSONResponse({"message": "Messenger API v2.0", "docs": "/docs"})

@app.get("/{full_path:path}", include_in_schema=False)
async def serve_spa(full_path: str):
    """Serve any file from files/ or fall back to index.html (SPA routing)."""
    # Don't intercept /api, /docs, /static, /join
    if any(full_path.startswith(p) for p in ("api/", "static/", "join/")):
        return JSONResponse({"message": "дурачок?", "docs": "/docs"})
    filepath = os.path.join(settings.FILES_DIR, full_path)
    if os.path.isfile(filepath):
        return FileResponse(filepath)
    index = os.path.join(settings.FILES_DIR, "index.html")
    if os.path.exists(index):
        return FileResponse(index)
    return JSONResponse({"message": "Messenger API v2.0", "docs": "/docs"})

@app.exception_handler(Exception)
async def global_error(request: Request, exc: Exception):
    return JSONResponse(status_code=500, content={"detail": str(exc)})
