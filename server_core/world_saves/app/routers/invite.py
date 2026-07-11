from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import HTMLResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from app.database import get_db
from app.models.models import Chat, ChatMember, User, ChatType, MemberRole
from app.services.utils import static_url, chat_link, share_link
from app.dependencies import get_current_user

router = APIRouter(tags=["Invite"])

@router.get("/join/{slug}", response_class=HTMLResponse)
async def invite_page(slug: str, db: AsyncSession = Depends(get_db)):
    """Рендерим HTML прямо из GET-запроса (без папки templates)"""
    r = await db.execute(select(Chat).where(Chat.username == slug))
    chat = r.scalar_one_or_none()
    
    if not chat or chat.chat_type == ChatType.DIRECT or chat.is_banned:
        html_content = f"""
    <!DOCTYPE html>
    <html lang="ru">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Неизвестный чат</title>
        <style>
            :root {{
                --bg: #0a0b10;
                --surface: rgba(255, 255, 255, 0.03);
                --border: rgba(0, 191, 255, 0.2);
                --accent: #00bfff;
                --accent2: #0077ff;
                --text: #e6edf3;
                --muted: #8b949e;
            }}
            * {{ box-sizing: border-box; margin: 0; padding: 0; font-family: 'Segoe UI', system-ui, sans-serif; }}
            body {{
                background: var(--bg); color: var(--text); display: flex; 
                justify-content: center; align-items: center; height: 100vh; overflow: hidden;
            }}
            .card {{
                background: var(--surface);
                backdrop-filter: blur(15px);
                -webkit-backdrop-filter: blur(15px);
                border: 1px solid var(--border);
                border-radius: 18px;
                padding: 40px;
                text-align: center;
                width: 100%;
                max-width: 340px;
                box-shadow: 0 10px 40px rgba(0, 0, 0, 0.5), inset 0 0 15px rgba(0, 191, 255, 0.05);
            }}
            .av {{
                width: 90px; height: 90px; border-radius: 50%;
                border: 2px solid var(--accent); margin: 0 auto 20px auto;
                object-fit: cover; box-shadow: 0 0 20px rgba(0, 191, 255, 0.2);
            }}
            .placeholder {{
                display: flex; justify-content: center; align-items: center;
                font-size: 2.5rem; font-weight: bold; background: var(--surface);
            }}
            h1 {{ font-size: 1.4rem; font-weight: 700; margin-bottom: 5px; }}
            .count {{ color: var(--accent); font-size: 0.85rem; font-weight: 600; text-transform: uppercase; margin-bottom: 15px; display: block; }}
            .desc {{ color: var(--muted); font-size: 0.9rem; line-height: 1.4; margin-bottom: 30px; }}
            .btn {{
                background: linear-gradient(90deg, var(--accent), var(--accent2));
                color: #fff; border: none; padding: 14px; border-radius: 12px;
                font-size: 1rem; font-weight: 600; cursor: pointer; width: 100%;
                transition: 0.2s; box-shadow: 0 4px 15px rgba(0, 191, 255, 0.3);
            }}
            .btn:hover {{ transform: translateY(-2px); box-shadow: 0 6px 20px rgba(0, 191, 255, 0.5); }}
            .btn:active {{ transform: translateY(0); }}
        </style>
    </head>
    <body>
        <div class="card">
            <h1>Неизвестный чат</h1>
            <span class="count">? участников</span>
            <p class="desc">?</p>
            <button class="btn" id="join-btn">Недоступно</button>
        </div>

        <script>
            document.getElementById('join-btn').addEventListener('click', async () => {{
                alert("Ошибка: " + (data.detail || "Не удалось вступить"));
                btn.disabled = false;
                btn.textContent = "Недоступно";
            }});
        </script>
    </body>
    </html>
    """
        return HTMLResponse(content=html_content)
    
    cnt = await db.execute(select(func.count()).select_from(ChatMember).where(ChatMember.chat_id == chat.id))
    members_count = cnt.scalar()
    avatar = static_url(chat.avatar_path) if chat.avatar_path else ""
    description = chat.description or "Нет описания"
    
    # Если нет аватарки, ставим первую букву названия
    av_html = f'<img src="{avatar}" class="av">' if avatar else f'<div class="av placeholder">{chat.name[0].upper()}</div>'

    html_content = f"""
    <!DOCTYPE html>
    <html lang="ru">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Приглашение в {chat.name}</title>
        <style>
            :root {{
                --bg: #0a0b10;
                --surface: rgba(255, 255, 255, 0.03);
                --border: rgba(0, 191, 255, 0.2);
                --accent: #00bfff;
                --accent2: #0077ff;
                --text: #e6edf3;
                --muted: #8b949e;
            }}
            * {{ box-sizing: border-box; margin: 0; padding: 0; font-family: 'Segoe UI', system-ui, sans-serif; }}
            body {{
                background: var(--bg); color: var(--text); display: flex; 
                justify-content: center; align-items: center; height: 100vh; overflow: hidden;
            }}
            .card {{
                background: var(--surface);
                backdrop-filter: blur(15px);
                -webkit-backdrop-filter: blur(15px);
                border: 1px solid var(--border);
                border-radius: 18px;
                padding: 40px;
                text-align: center;
                width: 100%;
                max-width: 340px;
                box-shadow: 0 10px 40px rgba(0, 0, 0, 0.5), inset 0 0 15px rgba(0, 191, 255, 0.05);
            }}
            .av {{
                width: 90px; height: 90px; border-radius: 50%;
                border: 2px solid var(--accent); margin: 0 auto 20px auto;
                object-fit: cover; box-shadow: 0 0 20px rgba(0, 191, 255, 0.2);
            }}
            .placeholder {{
                display: flex; justify-content: center; align-items: center;
                font-size: 2.5rem; font-weight: bold; background: var(--surface);
            }}
            h1 {{ font-size: 1.4rem; font-weight: 700; margin-bottom: 5px; }}
            .count {{ color: var(--accent); font-size: 0.85rem; font-weight: 600; text-transform: uppercase; margin-bottom: 15px; display: block; }}
            .desc {{ color: var(--muted); font-size: 0.9rem; line-height: 1.4; margin-bottom: 30px; }}
            .btn {{
                background: linear-gradient(90deg, var(--accent), var(--accent2));
                color: #fff; border: none; padding: 14px; border-radius: 12px;
                font-size: 1rem; font-weight: 600; cursor: pointer; width: 100%;
                transition: 0.2s; box-shadow: 0 4px 15px rgba(0, 191, 255, 0.3);
            }}
            .btn:hover {{ transform: translateY(-2px); box-shadow: 0 6px 20px rgba(0, 191, 255, 0.5); }}
            .btn:active {{ transform: translateY(0); }}
        </style>
    </head>
    <body>
        <div class="card">
            {av_html}
            <h1>{chat.name}</h1>
            <span class="count">{members_count} участников</span>
            <p class="desc">{description}</p>
            <button class="btn" id="join-btn">Вступить в чат</button>
        </div>

        <script>
            document.getElementById('join-btn').addEventListener('click', async () => {{
                // Берем именно тот токен, который сохраняет твой index.html
                const token = localStorage.getItem('msng_token');
                
                if (!token) {{
                    alert("Ошибка: Ты не авторизован! Войди в аккаунт на главной странице.");
                    window.location.href = "/";
                    return;
                }}

                const btn = document.getElementById('join-btn');
                btn.disabled = true;
                btn.textContent = "Загрузка...";

                try {{
                    const res = await fetch(window.location.pathname, {{
                        method: 'POST',
                        headers: {{ 
                            'Authorization': 'Bearer ' + token,
                            'Content-Type': 'application/json'
                        }}
                    }});

                    const data = await res.json();

                    if (res.ok) {{
                        // Успех, кидаем обратно в мессенджер
                        window.location.href = "/"; 
                    }} else {{
                        alert("Ошибка: " + (data.detail || "Не удалось вступить"));
                        btn.disabled = false;
                        btn.textContent = "Вступить в чат";
                    }}
                }} catch (e) {{
                    alert("Ошибка сети!");
                    btn.disabled = false;
                    btn.textContent = "Вступить в чат";
                }}
            }});
        </script>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)
@router.get("/{slug}", response_class=HTMLResponse)
async def invite_page(slug: str, db: AsyncSession = Depends(get_db)):
    """Рендерим HTML прямо из GET-запроса (без папки templates)"""
    r = await db.execute(select(Chat).where(Chat.username == slug))
    chat = r.scalar_one_or_none()
    
    if not chat or chat.chat_type == ChatType.DIRECT or chat.is_banned:
        html_content = f"""
    <!DOCTYPE html>
    <html lang="ru">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Неизвестный чат</title>
        <style>
            :root {{
                --bg: #0a0b10;
                --surface: rgba(255, 255, 255, 0.03);
                --border: rgba(0, 191, 255, 0.2);
                --accent: #00bfff;
                --accent2: #0077ff;
                --text: #e6edf3;
                --muted: #8b949e;
            }}
            * {{ box-sizing: border-box; margin: 0; padding: 0; font-family: 'Segoe UI', system-ui, sans-serif; }}
            body {{
                background: var(--bg); color: var(--text); display: flex; 
                justify-content: center; align-items: center; height: 100vh; overflow: hidden;
            }}
            .card {{
                background: var(--surface);
                backdrop-filter: blur(15px);
                -webkit-backdrop-filter: blur(15px);
                border: 1px solid var(--border);
                border-radius: 18px;
                padding: 40px;
                text-align: center;
                width: 100%;
                max-width: 340px;
                box-shadow: 0 10px 40px rgba(0, 0, 0, 0.5), inset 0 0 15px rgba(0, 191, 255, 0.05);
            }}
            .av {{
                width: 90px; height: 90px; border-radius: 50%;
                border: 2px solid var(--accent); margin: 0 auto 20px auto;
                object-fit: cover; box-shadow: 0 0 20px rgba(0, 191, 255, 0.2);
            }}
            .placeholder {{
                display: flex; justify-content: center; align-items: center;
                font-size: 2.5rem; font-weight: bold; background: var(--surface);
            }}
            h1 {{ font-size: 1.4rem; font-weight: 700; margin-bottom: 5px; }}
            .count {{ color: var(--accent); font-size: 0.85rem; font-weight: 600; text-transform: uppercase; margin-bottom: 15px; display: block; }}
            .desc {{ color: var(--muted); font-size: 0.9rem; line-height: 1.4; margin-bottom: 30px; }}
            .btn {{
                background: linear-gradient(90deg, var(--accent), var(--accent2));
                color: #fff; border: none; padding: 14px; border-radius: 12px;
                font-size: 1rem; font-weight: 600; cursor: pointer; width: 100%;
                transition: 0.2s; box-shadow: 0 4px 15px rgba(0, 191, 255, 0.3);
            }}
            .btn:hover {{ transform: translateY(-2px); box-shadow: 0 6px 20px rgba(0, 191, 255, 0.5); }}
            .btn:active {{ transform: translateY(0); }}
        </style>
    </head>
    <body>
        <div class="card">
            <h1>Неизвестный чат</h1>
            <span class="count">? участников</span>
            <p class="desc">?</p>
            <button class="btn" id="join-btn">Недоступно</button>
        </div>

        <script>
            document.getElementById('join-btn').addEventListener('click', async () => {{
                alert("Ошибка: " + (data.detail || "Не удалось вступить"));
                btn.disabled = false;
                btn.textContent = "Недоступно";
            }});
        </script>
    </body>
    </html>
    """
        return HTMLResponse(content=html_content)
    
    cnt = await db.execute(select(func.count()).select_from(ChatMember).where(ChatMember.chat_id == chat.id))
    members_count = cnt.scalar()
    avatar = static_url(chat.avatar_path) if chat.avatar_path else ""
    description = chat.description or "Нет описания"
    
    # Если нет аватарки, ставим первую букву названия
    av_html = f'<img src="{avatar}" class="av">' if avatar else f'<div class="av placeholder">{chat.name[0].upper()}</div>'

    html_content = f"""
    <!DOCTYPE html>
    <html lang="ru">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Приглашение в {chat.name}</title>
        <style>
            :root {{
                --bg: #0a0b10;
                --surface: rgba(255, 255, 255, 0.03);
                --border: rgba(0, 191, 255, 0.2);
                --accent: #00bfff;
                --accent2: #0077ff;
                --text: #e6edf3;
                --muted: #8b949e;
            }}
            * {{ box-sizing: border-box; margin: 0; padding: 0; font-family: 'Segoe UI', system-ui, sans-serif; }}
            body {{
                background: var(--bg); color: var(--text); display: flex; 
                justify-content: center; align-items: center; height: 100vh; overflow: hidden;
            }}
            .card {{
                background: var(--surface);
                backdrop-filter: blur(15px);
                -webkit-backdrop-filter: blur(15px);
                border: 1px solid var(--border);
                border-radius: 18px;
                padding: 40px;
                text-align: center;
                width: 100%;
                max-width: 340px;
                box-shadow: 0 10px 40px rgba(0, 0, 0, 0.5), inset 0 0 15px rgba(0, 191, 255, 0.05);
            }}
            .av {{
                width: 90px; height: 90px; border-radius: 50%;
                border: 2px solid var(--accent); margin: 0 auto 20px auto;
                object-fit: cover; box-shadow: 0 0 20px rgba(0, 191, 255, 0.2);
            }}
            .placeholder {{
                display: flex; justify-content: center; align-items: center;
                font-size: 2.5rem; font-weight: bold; background: var(--surface);
            }}
            h1 {{ font-size: 1.4rem; font-weight: 700; margin-bottom: 5px; }}
            .count {{ color: var(--accent); font-size: 0.85rem; font-weight: 600; text-transform: uppercase; margin-bottom: 15px; display: block; }}
            .desc {{ color: var(--muted); font-size: 0.9rem; line-height: 1.4; margin-bottom: 30px; }}
            .btn {{
                background: linear-gradient(90deg, var(--accent), var(--accent2));
                color: #fff; border: none; padding: 14px; border-radius: 12px;
                font-size: 1rem; font-weight: 600; cursor: pointer; width: 100%;
                transition: 0.2s; box-shadow: 0 4px 15px rgba(0, 191, 255, 0.3);
            }}
            .btn:hover {{ transform: translateY(-2px); box-shadow: 0 6px 20px rgba(0, 191, 255, 0.5); }}
            .btn:active {{ transform: translateY(0); }}
        </style>
    </head>
    <body>
        <div class="card">
            {av_html}
            <h1>{chat.name}</h1>
            <span class="count">{members_count} участников</span>
            <p class="desc">{description}</p>
            <button class="btn" id="join-btn">Вступить в чат</button>
        </div>

        <script>
            document.getElementById('join-btn').addEventListener('click', async () => {{
                // Берем именно тот токен, который сохраняет твой index.html
                const token = localStorage.getItem('msng_token');
                
                if (!token) {{
                    alert("Ошибка: Ты не авторизован! Войди в аккаунт на главной странице.");
                    window.location.href = "/";
                    return;
                }}

                const btn = document.getElementById('join-btn');
                btn.disabled = true;
                btn.textContent = "Загрузка...";

                try {{
                    const res = await fetch(window.location.pathname, {{
                        method: 'POST',
                        headers: {{ 
                            'Authorization': 'Bearer ' + token,
                            'Content-Type': 'application/json'
                        }}
                    }});

                    const data = await res.json();

                    if (res.ok) {{
                        // Успех, кидаем обратно в мессенджер
                        window.location.href = "/"; 
                    }} else {{
                        alert("Ошибка: " + (data.detail || "Не удалось вступить"));
                        btn.disabled = false;
                        btn.textContent = "Вступить в чат";
                    }}
                }} catch (e) {{
                    alert("Ошибка сети!");
                    btn.disabled = false;
                    btn.textContent = "Вступить в чат";
                }}
            }});
        </script>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)
@router.post("/join/{slug}")
async def join_via_link(slug: str, current_user: User = Depends(get_current_user),
                        db: AsyncSession = Depends(get_db)):
    """Join a group/channel via invite link."""
    if current_user.spam_block:
        raise HTTPException(403, "Spam-blocked accounts cannot join public chats.")
    r = await db.execute(select(Chat).where(Chat.username == slug))
    chat = r.scalar_one_or_none()
    if not chat or chat.chat_type == ChatType.DIRECT or chat.is_banned:
        raise HTTPException(404, "Invite link not found")
    ex = await db.execute(select(ChatMember).where(
        ChatMember.chat_id == chat.id, ChatMember.user_id == current_user.id))
    m = ex.scalar_one_or_none()
    if m:
        if m.is_banned: raise HTTPException(403, "You are banned from this chat")
        return {"message": "Already a member", "chat_id": chat.id}
    db.add(ChatMember(chat_id=chat.id, user_id=current_user.id, role=MemberRole.MEMBER))
    # If channel has comments chat, auto-join it too
    if chat.comments_chat_id:
        ex2 = await db.execute(select(ChatMember).where(
            ChatMember.chat_id == chat.comments_chat_id, ChatMember.user_id == current_user.id))
        if not ex2.scalar_one_or_none():
            db.add(ChatMember(chat_id=chat.comments_chat_id, user_id=current_user.id, role=MemberRole.MEMBER))
    return {"message": "Joined successfully", "chat_id": chat.id,
            "name": chat.name, "invite_link": chat_link(slug), "share_link": share_link(slug)}
