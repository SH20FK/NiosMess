import dotenv from "dotenv";
import { Stagehand } from "@browserbasehq/stagehand";
import { chromium } from "playwright";
import { z } from "zod";

dotenv.config();

const WEB_URL = process.env.NIOSMESS_WEB_URL || "https://ni-os.ru";
const MODEL = process.env.GEMINI_API_KEY
  ? "google/gemini-3-flash-preview"
  : process.env.NVIDIA_MODEL || "openai/gpt-oss-120b";

const USERNAME = "sh20fk";
const PASSWORD = "4562845628Aus11";

async function main() {
  console.log("[login] Запуск Stagehand + Playwright...");

  const stagehand = new Stagehand({
    env: "LOCAL",
    model: MODEL,
    headless: false,
  });
  await stagehand.init();

  const browser = await chromium.connectOverCDP(stagehand.connectURL());
  const page = browser.contexts()[0].pages()[0];

  console.log(`[login] Открываю ${WEB_URL}...`);
  await page.goto(WEB_URL, { waitUntil: "domcontentloaded", timeout: 60000 });
  console.log(`[login] Загружено: ${page.url()}`);

  await stagehand.act(
    `type "${USERNAME}" into the email or username field`,
    { page },
  );
  console.log("[login] Username введён");

  await stagehand.act(
    `type "${PASSWORD}" into the password field`,
    { page },
  );
  console.log("[login] Password введён");

  await stagehand.act(
    "click the submit button (Войти) to log in",
    { page },
  );
  console.log("[login] Кнопка входа нажата");
  await page.waitForTimeout(2000);

  console.log("[login] === 2FA ===");
  console.log("[login] Введи код из email в открытом браузере и нажми Enter в консоли.");
  console.log("[login] Ожидание до 5 минут...");

  const loginDetected = await waitForLogin(page);

  if (loginDetected) {
    console.log("[login] ✅ Вход выполнен успешно!");
    await page.waitForTimeout(2000);

    const pageContent = await stagehand.extract(
      "extract the current page title, visible user information, chat list items, navigation elements, and any buttons visible on the page",
      z.object({
        pageName: z.string(),
        userInfo: z.string().optional(),
        chats: z.array(z.string()),
        navigation: z.array(z.string()),
      }),
      { page },
    );
    console.log("[login] Состояние после входа:", JSON.stringify(pageContent, null, 2));
  } else {
    console.log("[login] ❌ Время ожидания истекло (5 мин). Вход не обнаружен.");
  }

  console.log("[login] Скрипт завершён. Браузер останется открытым.");
}

async function waitForLogin(page: any, timeoutMs = 300000): Promise<boolean> {
  const start = Date.now();

  while (Date.now() - start < timeoutMs) {
    const html = await page.content().catch(() => "");
    const text = html.toLowerCase();

    const hasLoginForm = text.includes("email или username") ||
      text.includes("вход") && text.includes("2fa") ||
      text.includes("код 2fa");
    const hasChatUI = text.includes("чат") ||
      text.includes("niossession") ||
      (text.includes("search") || text.includes("поиск"));

    if (hasChatUI && !hasLoginForm) {
      return true;
    }

    const url = page.url();
    if (url.includes("chat") || url.includes("mess") && !url.includes("ni-os.ru/")) {
      return true;
    }

    await new Promise(resolve => setTimeout(resolve, 2000));
  }

  return false;
}

main().catch((err) => {
  console.error("[login] ОШИБКА:", err);
  process.exit(1);
});
