import dotenv from "dotenv";
import { Stagehand } from "@browserbasehq/stagehand";
import { chromium } from "playwright";
import { z } from "zod";

dotenv.config();

async function main() {
  console.log("=== Stagehand debug ===");

  const stagehand = new Stagehand({
    env: "LOCAL",
    model: process.env.NVIDIA_MODEL || "deepseek-ai/deepseek-v4-flash",
    headless: false,
  });
  await stagehand.init();
  console.log("Model:", stagehand.modelName);

  const browser = await chromium.connectOverCDP(stagehand.connectURL());
  const page = browser.contexts()[0].pages()[0];

  await page.goto("https://ni-os.ru", { waitUntil: "domcontentloaded", timeout: 20000 });
  console.log("URL:", page.url());
  console.log("Title:", await page.title());

  const result = await stagehand.extract(
    "extract the page title and a short description of what this page is about",
    z.object({ title: z.string(), description: z.string() }),
    { page },
  );
  console.log("Extract result:", JSON.stringify(result, null, 2));

  await stagehand.close();
  await browser.close();
}

main().catch((e) => {
  console.error("ERROR:", e);
  process.exit(1);
});
