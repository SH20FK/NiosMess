# NiosMess Stagehand E2E-тесты

AI-driven browser automation тесты для веб-версии NiosMess.

## Установка

```bash
npm install
```

## Настройка

Скопируй `.env.example` в `.env` и укажи API-ключи:

```
OPENAI_API_KEY=nvapi-...        # NVIDIA NIM
OPENAI_BASE_URL=https://integrate.api.nvidia.com/v1
NVIDIA_MODEL=openai/gpt-oss-120b
NIOSMESS_WEB_URL=https://ni-os.ru
```

## Stagehand patch

`@ai-sdk/openai@2.x` по умолчанию использует Responses API (`/v1/responses`),
который NVIDIA NIM не поддерживает. В `node_modules` пропатчен
`LLMProvider.js` для использования Chat API (`/v1/chat/completions`):

- `dist/esm/lib/v3/llm/LLMProvider.js`
- `dist/cjs/lib/v3/llm/LLMProvider.js`

Изменения: `provider.chat(modelId)` вместо `provider(modelId)`, и передача
полного имени модели (`openai/gpt-oss-120b` вместо `gpt-oss-120b`).

После `npm install` или `npm update` нужно повторно применить патч.

## Запуск

```bash
npm run check            # проверка окружения
npm run test:auth        # тест страницы логина
npm run test:chat        # тест чата (требуется авторизация)
npm run test:search      # тест поиска
```

## Структура

```
scripts/
├── check-env.ts        # проверка переменных окружения
├── test-auth.ts        # тест страницы авторизации
├── test-chat.ts        # тест отправки сообщения
└── test-search.ts      # тест поиска
```
