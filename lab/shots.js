// Re-shoot every screenshot in shots.json: node shots.js [outdir]
const { chromium } = require('playwright');
const shots = require('./shots.json');
const out = process.argv[2] || 'screenshots';
const base = `http://localhost:8080/${process.env.CMK_SITE || 'hartwell'}/check_mk/`;

(async () => {
  require('fs').mkdirSync(out, { recursive: true });
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2 });
  await page.goto(base + 'login.py');
  await page.fill('input[name=_username]', 'cmkadmin');
  await page.fill('input[name=_password]', process.env.CMK_PASSWORD || 'labpass123');
  await Promise.all([page.waitForNavigation(), page.click('#_login')]);
  for (const s of shots) {
    await page.goto(base + s.path, { waitUntil: 'networkidle' });
    await page.screenshot({ path: `${out}/${s.name}.png`, fullPage: true });
    console.log(`${out}/${s.name}.png`);
  }
  await browser.close();
})().catch((e) => { console.error(e); process.exit(1); });
