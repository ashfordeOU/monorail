// Renders every scene in features.html to assets/features/<name>.webp (800 × 500, drawn at 2×).
//   node scripts/launch/render-features.cjs
const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');
const names = ['say-it', 'smart-slides', 'overview', 'stay-awake', 'evening', 'ai-agents', 'screen-share', 'focus', 'displays',
  'no-chords', 'docking', 'saved-views', 'zones', 'import', 'tags', 'scripting', 'battery', 'every-display', 'clashes', 'setup',
  'agents', 'battery-windows', 'themes'];
(async () => {
  const root = path.resolve(__dirname, '../..');
  const out = path.join(root, 'assets/features');
  fs.mkdirSync(out, { recursive: true });
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 800, height: 500 }, deviceScaleFactor: 2 });
  for (const name of names) {
    await page.goto('file://' + path.join(__dirname, 'features.html') + '?f=' + name);
    await page.waitForTimeout(150);
    await page.screenshot({ path: path.join(out, name + '.png') });
  }
  await browser.close();
  console.log('rendered', names.length);
})();
