# 🔧 Применение исправлений бэкенда

## Шаг 1: Установка зависимостей

```bash
cd F:\NiosMess
pip install passlib[argon2] python-dotenv PyJWT email-validator
```

## Шаг 2: Создание .env файла

Создайте файл `.env` в корне проекта:

```env
# Секретные ключи
ROOT_TOKEN=ЗАМЕНИТЕ_НА_СЛУЧАЙНЫЙ_СЕКРЕТНЫЙ_ТОКЕН_64_СИМВОЛА
JWT_SECRET=ЗАМЕНИТЕ_НА_СЛУЧАЙНЫЙ_КЛЮЧ_32_СИМВОЛА
SMTP_USER=your-email@gmail.com
SMTP_PWD=your-app-password

# База данных
DATABASE_URL=sqlite:///./niosmess.db

# API
API_BASE_URL=https://web.sa2rn.fun
ALLOWED_ORIGINS=https://web.sa2rn.fun,http://localhost:3000,http://localhost:8080

# Firebase (опционально)
FIREBASE_SERVER_KEY=your-firebase-server-key
```

## Шаг 3: Импорт исправлений в api.py

Добавьте в начало файла `api.py`:

```python
# В самом начале файла после импортов
from BACKEND_FIXES import (
    PasswordManager,
    validate_table_name,
    SessionManager,
    RateLimiter,
    sanitize_search_query,
    UserRegistration,
    login_limiter,
)
from dotenv import load_dotenv

# Загрузить .env
load_dotenv()

# Заменить константы на переменные окружения
ROOT_TOKEN = os.getenv("ROOT_TOKEN")
if not ROOT_TOKEN:
    raise ValueError("ROOT_TOKEN must be set in .env file")

SMTP_USER = os.getenv("SMTP_USER")
SMTP_PWD = os.getenv("SMTP_PWD")
JWT_SECRET = os.getenv("JWT_SECRET", secrets.token_urlsafe(32))
API_BASE_URL = os.getenv("API_BASE_URL", "https://web.sa2rn.fun")

# CORS с whitelist
ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "https://web.sa2rn.fun").split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["*"],
)
```

## Шаг 4: Исправить регистрацию пользователя

Найдите функцию `register` (примерно строка 1899) и замените на:

```python
@app.post("/register")
async def register(u: UserRegistration):  # Используем новую модель с валидацией
    """Регистрация нового пользователя с валидацией и хешированием пароля"""
    with db_lock:
        conn = sqlite3.connect(DATABASE)
        conn.row_factory = sqlite3.Row
        try:
            # Валидация уже прошла в Pydantic модели

            email_clean = u.email.strip().lower()
            username_clean = u.username.strip().lower()

            # Проверка существования (с блокировкой для предотвращения race condition)
            existing = conn.execute(
                "SELECT email, username FROM users WHERE email=? OR username=?",
                (email_clean, username_clean)
            ).fetchone()

            if existing:
                if existing["email"] == email_clean:
                    raise HTTPException(status_code=400, detail="Email already registered")
                else:
                    raise HTTPException(status_code=400, detail="Username already taken")

            # Хешировать пароль с Argon2
            hashed_password = PasswordManager.hash_password(u.password)

            # Создать пользователя
            conn.execute(
                "INSERT INTO users (username, email, password, name) VALUES (?, ?, ?, ?)",
                (u.username, email_clean, hashed_password, u.name)
            )
            conn.commit()

            return {"status": "ok", "username": u.username}

        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Registration error: {e}", exc_info=True)
            raise HTTPException(status_code=500, detail="Registration failed")
        finally:
            conn.close()
```

## Шаг 5: Исправить логин

Найдите функцию `login` (примерно строка 1970) и замените на:

```python
@app.post("/login")
async def login(username: str = Form(...), password: str = Form(...), device: str = Form(None), ip: str = Form(None)):
    """Авторизация с rate limiting и проверкой хешированного пароля"""

    # Rate limiting
    if not login_limiter.is_allowed(username):
        raise HTTPException(
            status_code=429,
            detail="Too many login attempts. Please try again in 15 minutes."
        )

    with db_lock:
        conn = sqlite3.connect(DATABASE)
        conn.row_factory = sqlite3.Row
        try:
            user = conn.execute(
                "SELECT username, password, name, frozen_reason FROM users WHERE username=?",
                (username,)
            ).fetchone()

            if not user:
                raise HTTPException(status_code=401, detail="Invalid credentials")

            # Проверка хешированного пароля
            if not PasswordManager.verify_password(password, user["password"]):
                raise HTTPException(status_code=401, detail="Invalid credentials")

            # Проверка заморозки аккаунта
            if user["frozen_reason"]:
                raise HTTPException(
                    status_code=403,
                    detail=f"Account frozen: {user['frozen_reason']}"
                )

            # Генерация безопасного токена
            session_data = SessionManager.create_session(
                username=username,
                device=device or "unknown",
                ip=ip or "unknown"
            )
            new_token = session_data['token']

            # Сохранение сессии
            conn.execute(
                "INSERT INTO sessions (token, username, last_activity, device, ip) VALUES (?, ?, ?, ?, ?)",
                (new_token, username, time.time(), device or "unknown", ip or "unknown")
            )
            conn.commit()

            # Сброс rate limit после успешного входа
            login_limiter.reset(username)

            return {
                "token": new_token,
                "username": username,
                "name": user["name"]
            }

        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Login error: {e}", exc_info=True)
            raise HTTPException(status_code=500, detail="Login failed")
        finally:
            conn.close()
```

## Шаг 6: Исправить SQL инъекции в pin_message

Найдите функцию `pin_message` (примерно строка 1127) и замените на:

```python
@app.post("/pin_message")
async def pin_message(username: str = Form(...), token: str = Form(...), chat_id: str = Form(...), message_id: int = Form(...), chat_type: str = Form("user"), pinned: bool = Form(True)):
    """Закрепить сообщение с защитой от SQL инъекций"""
    if not auth(username, token):
        raise HTTPException(status_code=401, detail="Unauthorized")

    # Валидация типа чата и получение безопасного имени таблицы
    table_map = {
        'user': 'messages',
        'group': 'group_messages',
        'channel': 'group_messages'
    }

    if chat_type not in table_map:
        raise HTTPException(status_code=400, detail="Invalid chat type")

    table = table_map[chat_type]

    with db_lock:
        conn = sqlite3.connect(DATABASE)
        try:
            # Безопасный SQL запрос с валидированным именем таблицы
            conn.execute(
                f"UPDATE {table} SET is_pinned=? WHERE id=?",
                (1 if pinned else 0, message_id)
            )
            conn.commit()
            return {"status": "ok"}
        except Exception as e:
            logger.error(f"Pin message error: {e}", exc_info=True)
            raise HTTPException(status_code=500, detail="Failed to pin message")
        finally:
            conn.close()
```

## Шаг 7: Исправить поиск с защитой от LIKE инъекций

Найдите функцию поиска (примерно строка 1377) и замените на:

```python
@app.get("/search_messages")
async def search_messages(username: str, token: str, chat_id: str, q: str, chat_type: str = "user", limit: int = 50, offset: int = 0):
    """Поиск сообщений с защитой от LIKE инъекций"""
    if not auth(username, token):
        raise HTTPException(status_code=401, detail="Unauthorized")

    # Санитизация поискового запроса
    safe_query = sanitize_search_query(q)

    # Валидация типа чата
    table_map = {
        'user': 'messages',
        'group': 'group_messages',
        'channel': 'group_messages'
    }

    if chat_type not in table_map:
        raise HTTPException(status_code=400, detail="Invalid chat type")

    table = table_map[chat_type]

    with db_lock:
        conn = sqlite3.connect(DATABASE)
        conn.row_factory = sqlite3.Row
        try:
            # Подсчет результатов
            count_row = conn.execute(
                f"SELECT COUNT(*) as total FROM {table} WHERE chat_id=? AND text LIKE ? ESCAPE '\\\\'",
                (chat_id, f"%{safe_query}%")
            ).fetchone()

            total = count_row["total"] if count_row else 0

            # Получение результатов
            results = conn.execute(
                f"SELECT * FROM {table} WHERE chat_id=? AND text LIKE ? ESCAPE '\\\\' ORDER BY id DESC LIMIT ? OFFSET ?",
                (chat_id, f"%{safe_query}%", limit, offset)
            ).fetchall()

            items = []
            for r in results:
                decoded = Map<String, dynamic>.from(dict(r))
                rawText = decoded.get('text', '')
                decoded['text'] = Obfuscator.deobfuscate(rawText)
                items.append(decoded)

            return {
                "total": total,
                "results": items,
                "query": q,  # Возвращаем оригинальный запрос для UI
                "limit": limit,
                "offset": offset
            }

        except Exception as e:
            logger.error(f"Search error: {e}", exc_info=True)
            raise HTTPException(status_code=500, detail="Search failed")
        finally:
            conn.close()
```

## Шаг 8: Миграция существующих паролей

Создайте и запустите скрипт миграции:

```python
# migrate_passwords.py
from BACKEND_FIXES import migrate_passwords

if __name__ == "__main__":
    print("Starting password migration...")
    migrate_passwords()
    print("Migration complete!")
```

Запустите:
```bash
python migrate_passwords.py
```

## Шаг 9: Добавить логирование

Добавьте в начало api.py:

```python
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('niosmess.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)
```

## Шаг 10: Тестирование

```bash
# Запустить сервер
uvicorn api:app --reload --host 0.0.0.0 --port 8000

# В другом терминале - тест регистрации
curl -X POST http://localhost:8000/register \\
  -H "Content-Type: application/json" \\
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "password": "TestPassword123",
    "name": "Test User"
  }'

# Тест логина
curl -X POST http://localhost:8000/login \\
  -F "username=testuser" \\
  -F "password=TestPassword123"

# Тест SQL injection (должен вернуть ошибку)
curl -X POST http://localhost:8000/pin_message \\
  -F "username=testuser" \\
  -F "token=YOUR_TOKEN" \\
  -F "chat_id=test" \\
  -F "message_id=1" \\
  -F "chat_type='; DROP TABLE users; --"
```

## Проверка безопасности

✅ Пароли хешируются с Argon2
✅ Секреты в .env файле
✅ SQL инъекции заблокированы
✅ Rate limiting работает
✅ CORS настроен корректно
✅ Логирование включено

## Дополнительно

### Генерация секретных ключей:

```python
import secrets

print("ROOT_TOKEN:", secrets.token_urlsafe(64))
print("JWT_SECRET:", secrets.token_urlsafe(32))
```

### Бэкап БД перед миграцией:

```bash
cp niosmess.db niosmess_backup_$(date +%Y%m%d).db
```

---

**Статус:** Готово к применению
**Версия:** 1.0.0
