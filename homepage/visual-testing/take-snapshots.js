/*

Serves a built site (the dist/ folder from `npm run build`) and screenshots
every page at each viewport into a folder of PNGs.

Usage:
  SNAPSHOT_OUT=<outputDir> SNAPSHOT_BROWSER=chrome node take-snapshots.js <distDir>

The pages are taken from dist/all-paths.json, which elm-pages writes on build.
/api/next-event (the Netlify function) answers with the fixed event in
next-event.json, so the event card doesn't change when Meetup's next event does.

*/

const { chromium, firefox, webkit } = require("playwright");
const express = require("express");
const fs = require("fs");
const path = require("path");

const [, , distDir] = process.argv;
const outDir = process.env.SNAPSHOT_OUT;
const browserName = process.env.SNAPSHOT_BROWSER || "chrome";

if (!distDir || !outDir) {
  console.error("Usage: SNAPSHOT_OUT=<outputDir> node take-snapshots.js <distDir>");
  process.exit(2);
}

const browserTypes = { chrome: chromium, firefox: firefox, safari: webkit };
const browserType = browserTypes[browserName];
if (!browserType) {
  console.error(`❌ Unknown SNAPSHOT_BROWSER '${browserName}' (expected chrome, firefox or safari)`);
  process.exit(2);
}

const viewports = [
  { name: "mobile", width: 390, height: 844 },
  { name: "desktop", width: 1280, height: 800 },
];

const nextEvent = fs.readFileSync(path.join(__dirname, "next-event.json"), "utf8");

const pagePaths = () => {
  const allPaths = JSON.parse(fs.readFileSync(path.join(distDir, "all-paths.json"), "utf8"));
  return allPaths.filter((p) => path.extname(p) === "");
};

const snapshotName = (pagePath, viewport) => {
  const route = pagePath.replace(/^\/|\/$/g, "").replace(/\//g, "_") || "index";
  return `${route}-${viewport.name}.png`;
};

const serve = () =>
  new Promise((resolve) => {
    const app = express();
    app.get("/api/next-event", (req, res) => res.type("json").send(nextEvent));
    app.use(express.static(path.resolve(distDir)));
    const server = app.listen(0, "127.0.0.1", () => resolve(server));
  });

(async () => {
  fs.mkdirSync(outDir, { recursive: true });
  const server = await serve();
  const origin = `http://127.0.0.1:${server.address().port}`;

  let browser;
  try {
    browser = await browserType.launch();
  } catch (err) {
    console.error(err.message);
    console.error(`\n❌ Couldn't start ${browserName}. Run 'npx playwright install ${browserType.name()}' in visual-testing/.`);
    server.close();
    process.exit(1);
  }

  try {
    for (const viewport of viewports) {
      const context = await browser.newContext({
        viewport: { width: viewport.width, height: viewport.height },
        deviceScaleFactor: 1,
        locale: "en-GB",
        timezoneId: "Europe/Stockholm",
        reducedMotion: "reduce",
      });
      const page = await context.newPage();
      for (const pagePath of pagePaths()) {
        const name = snapshotName(pagePath, viewport);
        await page.goto(origin + pagePath, { waitUntil: "networkidle" });
        await page.evaluate(() => document.fonts.ready);
        // Let Elm render whatever the last response changed.
        await page.evaluate(
          () => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)))
        );
        await page.screenshot({
          path: path.join(outDir, name),
          fullPage: true,
          animations: "disabled",
          caret: "hide",
        });
        console.log(`   📸 ${name}`);
      }
      await context.close();
    }
  } finally {
    await browser.close();
    server.close();
  }
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
