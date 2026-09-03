# Вход в NiosMess через Nios ID

Этот файл — инструкция для фронтендера NiosMess. В production уже зарегистрирован
public OAuth-клиент:

```text
client_id:    niosmess_web
redirect_uri: https://ni-os.ru/web
scopes:       openid profile email
```

Пароль вводится только на странице Nios ID. Фронтенд NiosMess не должен иметь
полей пароля, собственного логина или прямого доступа к cookie `nios_session`.

## Как выглядит поток

```text
NiosMess /web
    ↓  создаём state + PKCE verifier
Nios ID /oauth/authorize
    ↓  пользователь входит и видит согласие:
       Nios ID + имя профиля + подтверждённый email
NiosMess /web?code=...&state=...
    ↓  POST /oauth/token
access_token (короткоживущий)
    ↓  WebSocket login_nios_id
локальная сессия NiosMess
```

Согласие нельзя пропускать или заменять бесшумным входом по центральной cookie.
После отказа пользователь возвращается в NiosMess с ошибкой и может повторить
вход.

## 1. Константы и PKCE

```js
const NIOS_OAUTH_CLIENT_ID = "niosmess_web";
const NIOS_OAUTH_REDIRECT_URI = `${window.location.origin}/web`;

function base64url(bytes) {
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function randomBase64url(size = 32) {
  const bytes = new Uint8Array(size);
  crypto.getRandomValues(bytes);
  return base64url(bytes);
}

async function pkceChallenge(verifier) {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(verifier),
  );
  return base64url(new Uint8Array(digest));
}
```

`verifier` и `state` хранятся только в `sessionStorage` до callback. Не кладите
их в `localStorage`, URL после callback, аналитику или логи.

## 2. Кнопка входа

На экране авторизации оставьте одну кнопку:

```html
<button type="button" id="nios-login">Войти через Nios ID</button>
```

```js
document.querySelector("#nios-login").addEventListener("click", () => {
  beginNiosIdAuthorization().catch((error) => {
    showToast(error.message || "Не удалось открыть Nios ID", "error");
  });
});
```

## 3. Начало авторизации

Перед редиректом проверьте центральную сессию Nios ID. Если её нет, сначала
отправьте пользователя на обычный вход Nios ID, а после него верните в NiosMess
с флагом `nios_oauth=start`.

```js
async function hasNiosIdSession() {
  try {
    const response = await fetch("/id/api/v1/account", {
      credentials: "same-origin",
    });
    // Только 401 означает, что входа нет. Ошибка сети не должна выбрасывать
    // пользователя из уже работающего NiosMess.
    return response.status !== 401;
  } catch {
    return true;
  }
}

async function beginNiosIdAuthorization() {
  if (!(await hasNiosIdSession())) {
    const next = "/web?nios_oauth=start";
    window.location.assign(`/id/login?next=${encodeURIComponent(next)}`);
    return;
  }

  const verifier = randomBase64url(64);
  const state = randomBase64url(24);
  const nonce = randomBase64url(24);
  const challenge = await pkceChallenge(verifier);

  sessionStorage.setItem("nios_oauth_verifier", verifier);
  sessionStorage.setItem("nios_oauth_state", state);

  const query = new URLSearchParams({
    response_type: "code",
    client_id: NIOS_OAUTH_CLIENT_ID,
    redirect_uri: NIOS_OAUTH_REDIRECT_URI,
    scope: "openid profile email",
    state,
    nonce,
    code_challenge: challenge,
    code_challenge_method: "S256",
  });

  window.location.assign(`/oauth/authorize?${query}`);
}
```

`redirect_uri` должен совпадать с зарегистрированным адресом полностью. Для
production это `https://ni-os.ru/web`; не добавляйте slash, fragment или другой
query string.

## 4. Обработка callback

Обрабатывайте callback до попытки восстановить локальную сессию NiosMess.

```js
async function handleNiosOAuthReturn() {
  const params = new URLSearchParams(window.location.search);

  // Возврат после того, как пользователь вошёл на /id/login.
  if (params.get("nios_oauth") === "start") {
    await beginNiosIdAuthorization();
    return true;
  }

  const code = params.get("code");
  const oauthError = params.get("error");
  if (!code && !oauthError) return false;

  // Убираем code/state из адресной строки до дальнейшей работы приложения.
  history.replaceState({}, document.title, window.location.pathname || "/web");

  const verifier = sessionStorage.getItem("nios_oauth_verifier");
  const expectedState = sessionStorage.getItem("nios_oauth_state");
  sessionStorage.removeItem("nios_oauth_verifier");
  sessionStorage.removeItem("nios_oauth_state");

  if (oauthError) {
    showAuthScreen();
    showToast(
      params.get("error_description") || "Доступ Nios ID не предоставлен.",
      "error",
    );
    return true;
  }

  if (!verifier || !expectedState || params.get("state") !== expectedState) {
    showAuthScreen();
    showToast("Не удалось проверить ответ Nios ID.", "error");
    return true;
  }

  try {
    const tokenResponse = await fetch("/oauth/token", {
      method: "POST",
      credentials: "same-origin",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "authorization_code",
        code,
        client_id: NIOS_OAUTH_CLIENT_ID,
        redirect_uri: NIOS_OAUTH_REDIRECT_URI,
        code_verifier: verifier,
      }),
    });
    const token = await tokenResponse.json();
    if (!tokenResponse.ok || !token.access_token) {
      throw new Error(token.error_description || token.error || "Ошибка токена");
    }

    await loginNiosMessWithOAuthToken(token.access_token);
  } catch (error) {
    showAuthScreen();
    showToast(error.message || "Не удалось войти через Nios ID", "error");
  }
  return true;
}
```

## 5. Передача токена в WebSocket NiosMess

После обмена кода отправьте access token на уже открытый `wss://ni-os.ru/ws`.
Передавать пароль, центральный `nios_session` или OAuth-код запрещено.

```js
async function loginNiosMessWithOAuthToken(oauthAccessToken) {
  await api.connect();

  const response = await api.send(
    "login_nios_id",
    {
      oauth_access_token: oauthAccessToken,
      // Служебное поле совместимости текущего WS API.
      // Название устройства Nios ID определяет автоматически.
      device_info: `${navigator.platform} · ${navigator.userAgent}`.slice(0, 240),
    },
    true,
  );

  if (!response?.payload?.access_token) {
    throw new Error(response?.error || "NiosMess не принял вход Nios ID");
  }

  api.saveToStorage(response.payload);
  await api.setupE2EE();
  await loadMainScreen();
}
```

Успешный ответ WebSocket содержит локальные данные NiosMess:

```json
{
  "access_token": "локальный-токен-NiosMess",
  "user_id": 123,
  "nios_id": "nios_...",
  "username": "nios_...",
  "display_name": "Имя пользователя"
}
```

`oauth_access_token` используется только для первичного обмена и не должен
сохраняться во frontend storage. Локальный NiosMess token также нельзя помещать
в URL или выводить в console/logs.

## 6. Инициализация `/web` и восстановление

Рекомендуемый порядок запуска:

```js
async function init() {
  if (await handleNiosOAuthReturn()) return;

  if (api.loadFromStorage()) {
    if (await hasNiosIdSession()) {
      await resumeStoredSession();
    } else {
      await api.logout();
      showAuthScreen();
      showToast("Сессия Nios ID завершена. Войдите снова.", "error");
    }
  } else {
    showAuthScreen();
  }
}
```

Нельзя считать наличие локального token достаточным: центральная сессия могла
быть завершена на другой вкладке, на сайте Nios ID или с другого устройства.

## 7. Выход и список устройств

Выход из NiosMess должен закрывать локальный WebSocket и локальный token, а затем
завершать центральную сессию Nios ID:

```js
async function logout() {
  try {
    await fetch("/id/api/v1/logout", {
      method: "POST",
      credentials: "same-origin",
    });
  } finally {
    await api.logout();
    window.location.assign("/id/login?next=/web");
  }
}
```

Список устройств и завершение сеансов берите из центрального API:

```text
GET    /id/api/v1/sessions
DELETE /id/api/v1/sessions/{session_id}
POST   /id/api/v1/sessions/revoke-others
```

Если удалена текущая сессия, очистите локальный NiosMess token и направьте
пользователя на `/id/login?next=/web`. Для уже открытого NiosMess полезно раз в
минуту проверять `GET /id/api/v1/account`: ответ 401 означает немедленный выход.

## Чего делать нельзя

- Не добавлять форму email/password в NiosMess.
- Не отправлять `nios_session` из браузера в WebSocket или на свой backend.
- Не принимать `nios_id_token` или произвольный token вместо `oauth_access_token`.
- Не пропускать `state`, PKCE S256 и экран согласия.
- Не хранить OAuth access token в `localStorage`.
- Не писать URL callback, authorization code или token в логи.
- Не связывать профиль по email: идентификатор связи — только `nios_id` (`sub`).

## Проверка перед merge

1. Новый пользователь: вход → согласие → NiosMess открывается.
2. Нажата «Отмена»: NiosMess остаётся на auth screen, ошибок JavaScript нет.
3. Изменённый `state`: callback отклоняется.
4. Повторно использованный `code`: `/oauth/token` возвращает `invalid_grant`.
5. Завершена центральная сессия на другом устройстве: обновление `/web` не
   восстанавливает NiosMess автоматически.
6. В Nios ID → «Устройства» текущий сеанс можно завершить кнопкой «Выйти».
7. В Nios ID → «Подключённые приложения» виден NiosMess; отзыв доступа закрывает
   дальнейшие OAuth-входы.

Полный контракт провайдера находится в
[`docs/NIOS_ID_OAUTH.md`](NIOS_ID_OAUTH.md), а актуальная реализация NiosMess — в
`legacy/niosmess/index.html`.
