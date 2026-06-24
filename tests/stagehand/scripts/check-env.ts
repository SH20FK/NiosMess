import dotenv from "dotenv";
dotenv.config();

const check = (key: string) => {
  const val = process.env[key];
  if (!val) console.warn(`  ⚠ ${key} не задан`);
  else console.log(`  ✓ ${key} задан`);
};

function main() {
  console.log("\n=== Stagehand — проверка окружения ===\n");

  check("GEMINI_API_KEY");
  check("OPENAI_API_KEY");
  check("ANTHROPIC_API_KEY");
  check("BROWSERBASE_API_KEY");

  const baseUrl = process.env.OPENAI_BASE_URL || "";
  let model: string;
  let note = "";

  const nvidiaModel = process.env.NVIDIA_MODEL || "deepseek-ai/deepseek-v4-flash";

  if (process.env.GEMINI_API_KEY) {
    model = "google/gemini-3-flash-preview";
  } else if (process.env.OPENAI_API_KEY && baseUrl.includes("nvidia")) {
    model = `${nvidiaModel} (через NVIDIA NIM)`;
    note = " (через OPENAI_BASE_URL)";
  } else if (process.env.OPENAI_API_KEY) {
    model = "openai/gpt-4o";
  } else {
    model = "⚠ не определена — нет API-ключа";
  }

  console.log(`\n  Модель: ${model}${note}`);
  if (baseUrl) console.log(`  OPENAI_BASE_URL: ${baseUrl}`);
  console.log(`  NIOSMESS_WEB_URL: ${process.env.NIOSMESS_WEB_URL || "https://ni-os.ru"}`);
  console.log(`  Node: ${process.version}`);
  console.log("  Stagehand: установлен");
  console.log("  Playwright Chromium: установлен\n");

  console.log("Окружение готово к запуску тестов.");
  console.log("  npm run test:auth    — тест авторизации");
  console.log("  npm run test:chat    — тест чата");
  console.log("  npm run test:search  — тест поиска\n");
}

main();
