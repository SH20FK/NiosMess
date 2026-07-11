import httpx
from enum import Enum
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

# Импортируем твою зависимость для проверки авторизации пользователя
from app.dependencies import get_current_user
from app.models.models import User

router = APIRouter(prefix="/ai", tags=["AI Assistant"])

# Список ключей Mistral. Если первый отвалится (например, лимит запросов 429), пойдет следующий
MISTRAL_API_KEYS: List[str] = [
    "ydbvYyjwYxYgKsKqxJbGLugedWG1BCju",
    "DPdMuZFMS3pUQDKgVfM1LPvOA5KKD3OG"
]

MISTRAL_API_URL = "https://api.mistral.ai/v1/chat/completions"
# Можно использовать 'mistral-tiny' для скорости или 'mistral-small'/'mistral-medium' для качества
MISTRAL_MODEL = "ministral-3b-latest" 

class AITaskType(str, Enum):
    translate = "translate"
    correct = "correct"
    formalize = "formalize"

class AITextRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=4000, description="Текст для обработки")
    action: AITaskType
    target_language: Optional[str] = Field(None, description="Обязательно, если action == translate")

class AITextResponse(BaseModel):
    original_text: str
    result_text: str
    action: str

async def call_mistral_with_fallback(prompt: str) -> str:
    """
    Отправляет запрос к Mistral AI, перебирая ключи в случае ошибок (Rate Limit, Server Error и т.д.)
    """
    async with httpx.AsyncClient() as client:
        for key in MISTRAL_API_KEYS:
            headers = {
                "Authorization": f"Bearer {key}",
                "Content-Type": "application/json"
            }
            payload = {
                "model": MISTRAL_MODEL,
                "messages": [{"role": "user", "content": prompt}],
                "temperature": 0.3, # Низкая температура, чтобы ИИ был точным и не фантазировал
            }
            
            try:
                response = await client.post(MISTRAL_API_URL, json=payload, headers=headers, timeout=15.0)
                response.raise_for_status() # Бросит исключение, если статус не 2xx
                
                data = response.json()
                # Возвращаем сам текст ответа, убирая лишние пробелы по краям
                return data["choices"][0]["message"]["content"].strip()
                
            except (httpx.HTTPStatusError, httpx.RequestError) as e:
                # Если ошибка 400 (Bad Request), то проблема в самом промпте, перебирать ключи нет смысла
                if isinstance(e, httpx.HTTPStatusError) and e.response.status_code == 400:
                    raise HTTPException(status_code=400, detail=f"Mistral API error: {e.response.text}")
                
                # Для остальных ошибок (401, 429, 500+) логируем (тут можно добавить print) и пробуем следующий ключ
                continue
                
    # Если цикл закончился, а return не сработал — значит все ключи невалидны или лежат в бане
    raise HTTPException(status_code=503, detail="Все AI сервера сейчас недоступны. Попробуйте позже.")


@router.post("/process-text", response_model=AITextResponse)
async def process_text(
    body: AITextRequest, 
    current_user: User = Depends(get_current_user) # Защищаем роут, ИИ стоит денег/лимитов
):
    """
    Обрабатывает текст пользователя с помощью ИИ (Перевод, Исправление, Деловой стиль).
    """
    if body.action == AITaskType.translate:
        if not body.target_language:
            raise HTTPException(status_code=400, detail="Для перевода необходимо указать target_language.")
        prompt = (
            f"Переведи следующий текст на язык: {body.target_language}. "
            f"В ответе выдай ТОЛЬКО перевод, без кавычек, без приветствий и без твоих комментариев:\n\n{body.text}"
        )
        
    elif body.action == AITaskType.correct:
        prompt = (
            f"Исправь все грамматические, орфографические и пунктуационные ошибки в следующем тексте. "
            f"Сохрани оригинальный язык текста. В ответе выдай ТОЛЬКО исправленный текст, без кавычек и комментариев:\n\n{body.text}"
        )
        
    elif body.action == AITaskType.formalize:
        prompt = (
            f"Перепиши следующий текст в официально-деловом стиле. Сделай его вежливым и профессиональным. "
            f"Сохрани оригинальный язык. В ответе выдай ТОЛЬКО переписанный текст, без кавычек и комментариев:\n\n{body.text}"
        )

    # Вызываем функцию с перебором ключей
    result = await call_mistral_with_fallback(prompt)
    
    return AITextResponse(
        original_text=body.text,
        result_text=result,
        action=body.action
    )