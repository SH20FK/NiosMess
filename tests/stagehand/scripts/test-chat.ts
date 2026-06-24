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
  console.log("[chat] Запуск Stagehand + Playwright...");

  const stagehand = new Stagehand({
    env: "LOCAL",
    model: MODEL,
    headless: false,
  });
  await stagehand.init();

  const browser = await chromium.connectOverCDP(stagehand.connectURL());
  const page = browser.contexts()[0].pages()[0];

  console.log(`[chat] Открываю ${WEB_URL}...`);
  await page.goto(WEB_URL, { waitUntil: "networkidle", timeout: 30000 });
  console.log(`[chat] Загружено: ${page.url()}`);

  // Пробуем авторизоваться через AI
  await stagehand.act({
    action: "click on the login tab and fill in the email or username field with a test username, fill in the password field with a test password, then click the login button",
    page,
  }).catch(() => console.log("[chat] Авторизация не удалась (ожидаемо без тестовых кредов)"));

  // Извлекаем результат — список чатов или ошибку
  const result = await stagehand.extract(
    "extract any chat list items visible on the page, or error messages from a login attempt",
    z.object({
      items: z.array(z.string()).describe("visible chat names or error messages"),
      hasChats: z.boolean(),
    }),
    { page },
  ).catch(() => null);
  console.log("[chat] Результат:", JSON.stringify(result, null, 2));

  console.log("[chat] Тест завершён.");
  await stagehand.close();
  await browser.close();
}

main().catch((err) => {
  console.error("[chat] ОШИБКА:", err);
  process.exit(1);
});
