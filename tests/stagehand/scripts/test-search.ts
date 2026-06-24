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
  console.log("[search] Запуск Stagehand + Playwright...");

  const stagehand = new Stagehand({
    env: "LOCAL",
    model: MODEL,
    headless: false,
  });
  await stagehand.init();

  const browser = await chromium.connectOverCDP(stagehand.connectURL());
  const page = browser.contexts()[0].pages()[0];

  console.log(`[search] Открываю ${WEB_URL}...`);
  await page.goto(WEB_URL, { waitUntil: "networkidle", timeout: 30000 });
  console.log(`[search] Загружено: ${page.url()}`);

  // Находим поле поиска
  await stagehand.act(
    "find the search bar or search input field and click on it",
    { page },
  ).catch(() => console.log("[search] Поле поиска не найдено"));

  // Вводим запрос
  await stagehand.act(
    "type 'test' into the search field and wait 2 seconds for results to appear",
    { page },
  ).catch(() => console.log("[search] Ввод запроса не удался"));

  // Извлекаем результаты
  const results = await stagehand.extract(
    "extract any search results visible on the page — usernames, chat names, or message previews. If there's a message about no results, extract that too",
    z.object({
      hasResults: z.boolean(),
      items: z.array(z.string()).describe("search results or status messages"),
    }),
    { page },
  ).catch(() => null);

  console.log("[search] Результаты:", JSON.stringify(results, null, 2));

  console.log("[search] Тест завершён.");
  await stagehand.close();
  await browser.close();
}

main().catch((err) => {
  console.error("[search] ОШИБКА:", err);
  process.exit(1);
});
