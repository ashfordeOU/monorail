// Draws Signalbox's app icon (assets/signalbox/icon.png, 1024 px) from the chosen design, "B · Low
// horizon" (scripts/design/views-18-station-final.html): mostly navy with a thin band of Monorail's
// pink, two white rings and a pink pulse through the M. On Apple's grid: an 824 px tile in 1024.
//   node scripts/render-signalbox-icon.cjs
const { chromium } = require('playwright');
const path = require('path');
const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="1024" height="1024">
<defs>
  <linearGradient id="top" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FF8A5B"/><stop offset="1" stop-color="#E8437A"/></linearGradient>
  <linearGradient id="bot" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1E2D63"/><stop offset="1" stop-color="#0A102A"/></linearGradient>
  <clipPath id="clip"><rect x="10" y="10" width="80" height="80" rx="18"/></clipPath>
  <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="1.2" stdDeviation="1.4" flood-opacity=".28"/></filter>
</defs>
<g filter="url(#shadow)"><rect x="10" y="10" width="80" height="80" rx="18" fill="#0A102A"/></g>
<g clip-path="url(#clip)">
  <rect x="10" y="10" width="80" height="80" fill="url(#bot)"/>
  <rect x="10" y="10" width="80" height="26" fill="url(#top)"/>
  <rect x="10" y="35" width="80" height="2" fill="#fff" opacity=".08"/>
</g>
${[[34, 4.2, .82], [28, 4.2, .6]].map(([r, w, share]) => { const c = 2 * Math.PI * r;
  return `<circle cx="50" cy="50" r="${r}" fill="none" stroke="#fff" stroke-opacity=".22" stroke-width="${w}"/>
  <circle cx="50" cy="50" r="${r}" fill="none" stroke="#fff" stroke-width="${w}" stroke-linecap="round" stroke-dasharray="${c * share} ${c}" transform="rotate(-90 50 50)"/>`; }).join('')}
${(() => { const s = .66, x = v => 50 + (v - 50) * s, w = v => v * s;
  return `<rect x="${x(33)}" y="${x(32)}" width="${w(9)}" height="${w(36)}" rx="${w(3.6)}" fill="none" stroke="#fff" stroke-width="${w(3)}"/>
  <rect x="${x(58)}" y="${x(32)}" width="${w(9)}" height="${w(36)}" rx="${w(3.6)}" fill="none" stroke="#fff" stroke-width="${w(3)}"/>
  <path d="M${x(24)} ${x(52)} H${x(42)} L${x(45.5)} ${x(42)} L${x(50)} ${x(62)} L${x(54)} ${x(46)} L${x(56)} ${x(52)} H${x(76)}" fill="none" stroke="#FF6FA0" stroke-width="${w(3.2)}" stroke-linecap="round" stroke-linejoin="round"/>`; })()}
</svg>`;
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1024, height: 1024 }, deviceScaleFactor: 1 });
  await page.setContent(`<html><body style="margin:0;background:transparent">${svg}</body></html>`);
  await page.screenshot({ path: path.join(__dirname, '..', 'assets/signalbox/icon.png'), omitBackground: true, clip: { x: 0, y: 0, width: 1024, height: 1024 } });
  await browser.close();
  console.log('assets/signalbox/icon.png');
})();
