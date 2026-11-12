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
    // Fail loudly if any two pieces of text overlap.
    const clashes = await p.evaluate(() => {
      const boxes = [];
      const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
      for (let n = walker.nextNode(); n; n = walker.nextNode()) {
        if (!n.textContent.trim()) continue;
        const r = document.createRange(); r.selectNodeContents(n);
        for (const b of r.getClientRects()) if (b.width > 1 && b.height > 1) boxes.push({ b, t: n.textContent.trim().slice(0, 30), el: n.parentElement });
      }
      const out = [];
      for (let i = 0; i < boxes.length; i++) for (let j = i + 1; j < boxes.length; j++) {
        const a = boxes[i].b, c = boxes[j].b;
        const w = Math.min(a.right, c.right) - Math.max(a.left, c.left), h = Math.min(a.bottom, c.bottom) - Math.max(a.top, c.top);
        if (w > 2 && h > 3 && boxes[i].el !== boxes[j].el) out.push(boxes[i].t + ' ⟷ ' + boxes[j].t);
      }
      return out;
    });
    if (clashes.length) console.log('OVERLAP in', f, theme, '\n  ' + clashes.slice(0, 12).join('\n  '));
  }
  await b.close(); console.log(pages.length * 2, 'rendered');
})();
