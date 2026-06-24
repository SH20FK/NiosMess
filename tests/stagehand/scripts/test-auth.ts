import dotenv from "dotenv";
import { Stagehand } from "@browserbasehq/stagehand";
import { chromium } from "playwright";
import { z } from "zod";

dotenv.config();

const WEB_URL = process.env.NIOSMESS_WEB_URL || "https://ni-os.ru";
const MODEL = process.env.GEMINI_API_KEY
  ? "google/gemini-3-flash-preview"
  : process.env.NVIDIA_MODEL || "deepseek-ai/deepseek-v4-flash";

async function main() {
  console.log("[auth] Запуск Stagehand + Playwright...");

  // 1. Инициализируем Stagehand (без env:LOCAL — он сам не будет запускать браузер)
  const stagehand = new Stagehand({
    env: "LOCAL",
    model: MODEL,
    headless: false,
  });
  await stagehand.init();

  // 2. Подключаем Playwright к браузеру Stagehand через CDP
  const browser = await chromium.connectOverCDP(stagehand.connectURL());
  const context = browser.contexts()[0];
  const page = context.pages()[0];

  console.log(`[auth] Открываю ${WEB_URL}...`);
  await page.goto(WEB_URL, { waitUntil: "networkidle", timeout: 30000 });
  console.log(`[auth] Загружено: ${page.url()}`);

  // 3. Извлекаем информацию о странице через AI
  console.log("[auth] Пробую extract...");
  const pageInfo = await stagehand.extract(
    "extract the page title and a short description of what this page is about",
    z.object({ title: z.string(), description: z.string() }),
    { page },
  ).catch((err) => {
    console.log("[auth] extract ERROR:", err.message);
    console.log("[auth] extract stack:", err.stack?.split("\n").slice(0, 5).join("\n"));
    return null;
  });
  console.log("[auth] Page info:", JSON.stringify(pageInfo, null, 2));

  // 4. Пробуем найти форму логина
  console.log("[auth] Пробую act...");
  const hasForm = await stagehand.act(
    "find the login or sign-in form and check if it has email and password input fields, then click on the first visible input",
    { page },
  ).then(() => true).catch((err) => {
    console.log("[auth] act error:", err.message);
    return false;
  });
  console.log("[auth] Форма логина:", hasForm ? "найдена" : "не найдена");

  console.log("[auth] Тест завершён.");
  await stagehand.close();
  await browser.close();
}

main().catch((err) => {
  console.error("[auth] ОШИБКА:", err);
  process.exit(1);
});
