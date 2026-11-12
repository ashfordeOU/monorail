// Renders every design view (light and dark) to assets/design/views/.  node scripts/design/render-views.cjs
const { chromium } = require('playwright');
const path = require('path'); const fs = require('fs');
(async () => {
  const dir = __dirname, out = path.resolve(dir, '../../assets/design/views'); fs.mkdirSync(out, { recursive: true });
  const pages = fs.readdirSync(dir).filter(f => /^views-.*\.html$/.test(f)).sort();
  const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: 1500, height: 960 }, deviceScaleFactor: 2 });
  for (const f of pages) for (const theme of ['light', 'dark']) {
    await p.goto('file://' + path.join(dir, f) + '?theme=' + theme); await p.waitForTimeout(250);
    await p.screenshot({ path: path.join(out, f.replace('.html', '') + '-' + theme + '.png') });
  }
  await b.close(); console.log(pages.length * 2, 'rendered');
})();
