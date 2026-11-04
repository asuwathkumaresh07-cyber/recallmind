// Exercise and record the actual notes -> study set workflow.
const path = require('path');
const os = require('os');
const fs = require('fs');
const { chromium } = require(path.join(os.homedir(), '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright'));
const notes = `Ecosystems include living organisms and their physical environment. Producers use sunlight to make organic compounds through photosynthesis. Consumers obtain energy by feeding on other organisms. Decomposers break down dead organic material and recycle nutrients into the environment.

Energy flows through trophic levels in a food chain. Much of the energy at each level is used in metabolism or lost as heat. Biomass is the total mass of living material in a population. Food webs show multiple feeding relationships within an ecosystem.

Carbon cycles between the atmosphere and living organisms. Photosynthesis removes carbon dioxide from the atmosphere. Cellular respiration releases carbon dioxide as organisms break down organic compounds. Combustion transfers stored carbon into the atmosphere.`;

(async () => {
  const browser = await chromium.launch({ executablePath: path.join(process.env.PROGRAMFILES || 'C:/Program Files', 'Google/Chrome/Application/chrome.exe'), headless: true });
  const page = await browser.newPage({ viewport: { width: 1280, height: 1000 }, reducedMotion: 'reduce' });
  page.setDefaultTimeout(20000);
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  const click = async (text) => page.getByText(text, { exact: true }).first().evaluate(e => e.click());
  const top = async () => { await page.mouse.move(Math.min(900, page.viewportSize().width - 40), 400); await page.mouse.wheel(0, -10000); await page.waitForTimeout(400); };
  const frameDir = '.tool-data/document-frames';
  fs.mkdirSync(frameDir, { recursive: true });
  fs.mkdirSync('docs/images', { recursive: true });
  let frame = 0;
  const capture = async (count = 3) => { for (let i = 0; i < count; i++) await page.screenshot({ path: `${frameDir}/${String(frame++).padStart(3,'0')}.png` }); };
  try {
    await page.goto(process.env.DEMO_URL || 'http://127.0.0.1:8095/recallmind/');
    await page.waitForTimeout(8000);
    const semantics = page.locator('flt-semantics-placeholder');
    if (await semantics.count()) await semantics.evaluate(e => e.click());
    await page.getByText('Your material. Your study plan.', { exact: true }).waitFor();
    await page.screenshot({ path: 'docs/images/dashboard.png' });
    await capture();
    const choosing = page.waitForEvent('filechooser');
    await click('Upload a document');
    const chooser = await choosing;
    await chooser.setFiles({ name: 'Ecology.txt', mimeType: 'text/plain', buffer: Buffer.from(notes) });
    await page.waitForTimeout(600);
    const input = page.getByRole('textbox', { name: /Your instructions/ });
    await input.fill('Create a 3-day study plan, 4 quiz questions, 5 flashcards and a summary. 20 minutes each day.');
    await input.evaluate(e => e.blur());
    await capture();
    await click('Generate my study set');
    await page.getByText('Change instructions', { exact: true }).waitFor();
    await top();
    await page.screenshot({ path: 'docs/images/study-plan.png' });
    await capture(5);
    await page.mouse.click(408, 495);
    await page.waitForTimeout(300);
    await capture(4);
    await page.mouse.click(495, 495);
    await page.waitForTimeout(300);
    await click('Start quiz');
    await page.getByText('Quiz from your material', { exact: true }).waitFor();
    await page.screenshot({ path: 'docs/images/quiz.png' });
    await capture(5);
    await page.goto(process.env.DEMO_URL || 'http://127.0.0.1:8095/recallmind/');
    await page.waitForTimeout(5000);
    const placeholder = page.locator('flt-semantics-placeholder');
    if (await placeholder.count()) await placeholder.evaluate(e => e.click());
    await page.waitForFunction(() => document.body.innerText.includes('Ecology 4 questions'));
    await page.mouse.move(900, 400);
    await page.mouse.wheel(0, 10000);
    await page.waitForTimeout(400);
    await page.getByRole('button', {name: 'Open study set', exact: true}).evaluate(e => e.click());
    await page.setViewportSize({width:390,height:844});
    await top();
    await page.screenshot({ path: 'docs/images/mobile.png' });
    console.log(JSON.stringify({title: await page.title(), imported:'Ecology.txt', savedAfterReload:true, frames:frame, errors}));
    if (errors.length) process.exitCode = 1;
  } catch (e) {
    await page.screenshot({path:'.tool-data/document-error.png'});
    fs.writeFileSync('.tool-data/document-error.txt', await page.locator('body').innerText());
    throw e;
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exit(1); });
