// Capture the real Flutter web app for the README; run after serving build/web.
const path = require('path');
const os = require('os');
const fs = require('fs');
const { chromium } = require(path.join(os.homedir(), '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright'));

(async () => {
  const browser = await chromium.launch({ executablePath: path.join(process.env.PROGRAMFILES || 'C:/Program Files', 'Google/Chrome/Application/chrome.exe'), headless: true });
  const page = await browser.newPage({ viewport: { width: 1280, height: 1000 }, reducedMotion: 'reduce' });
  page.setDefaultTimeout(15000);
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  await page.goto(process.env.DEMO_URL || 'http://127.0.0.1:8095/recallmind/');
  await page.waitForTimeout(10000);
  const semantics = page.locator('flt-semantics-placeholder');
  if (await semantics.count()) await semantics.evaluate(e => e.click());
  await page.getByText('A little progress, every day.', { exact: true }).waitFor();
  fs.mkdirSync('docs/images', { recursive: true });
  fs.mkdirSync('.tool-data/demo-frames', { recursive: true });
  await page.screenshot({ path: 'docs/images/dashboard.png' });
  let frame = 0;
  const capture = () => page.screenshot({ path: `.tool-data/demo-frames/${String(frame++).padStart(3, '0')}.png` });
  for (let i = 0; i < 5; i++) await capture();
  await page.mouse.click(110, 365);
  await page.waitForTimeout(500);
  await page.screenshot({ path: 'docs/images/knowledge-map.png' });
  await page.getByText('YOUR KNOWLEDGE, CONNECTED', { exact: true }).waitFor();
  await page.getByRole('button', { name: 'Rotate automatically' }).evaluate(e => e.click());
  for (let i = 0; i < 36; i++) { await capture(); await page.waitForTimeout(120); }
  await page.getByRole('button', { name: 'Pause rotation' }).evaluate(e => e.click());
  await page.screenshot({ path: 'docs/images/knowledge-map.png' });
  await page.mouse.click(975, 770);
  for (let i = 0; i < 5; i++) await capture();
  await page.setViewportSize({ width: 390, height: 844 });
  await page.waitForTimeout(500);
  await page.screenshot({ path: 'docs/images/mobile.png' });
  console.log(JSON.stringify({ title: await page.title(), frames: frame, errors }));
  if (errors.length) process.exitCode = 1;
  await browser.close();
})().catch(e => { console.error(e); process.exit(1); });
