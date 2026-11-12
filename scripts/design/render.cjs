// Renders the design mock-ups (light and dark) to assets/design/.  node scripts/design/render.cjs pass1
const { chromium } = require('playwright');
const path = require('path'); const fs = require('fs');
(async () => {
  const name = process.argv[2] || 'pass1';
  const out = path.resolve(__dirname, '../../assets/design'); fs.mkdirSync(out, { recursive: true });
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1500, height: 960 }, deviceScaleFactor: 2 });
  for (const theme of ['light', 'dark']) {
    await p.goto('file://' + path.join(__dirname, name + '.html') + '?theme=' + theme);
    await p.waitForTimeout(200);
    await p.screenshot({ path: path.join(out, `${name}-${theme}.png`) });
  }
  await b.close();
})();
