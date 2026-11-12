// Helpers shared by the design mock-ups.
document.documentElement.dataset.theme = new URLSearchParams(location.search).get('theme') || 'light';
const P = {
  bolt: '<path d="M13 2 4 14h7l-1 8 9-12h-7z"/>', moon: '<path d="M20 14.5A8 8 0 0 1 9.5 4 8 8 0 1 0 20 14.5z"/>',
  cup: '<path d="M4 9h12v5a5 5 0 0 1-5 5H9a5 5 0 0 1-5-5z"/><path d="M16 11h1.5a2.5 2.5 0 0 1 0 5H16"/>',
  scope: '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="3"/>', pause: '<path d="M8 5v14M16 5v14"/>',
  grid: '<rect x="3" y="4" width="7" height="7" rx="2"/><rect x="14" y="4" width="7" height="7" rx="2"/><rect x="3" y="14" width="7" height="7" rx="2"/><rect x="14" y="14" width="7" height="7" rx="2"/>',
  wand: '<path d="m4 20 11-11"/><path d="m14 6 1-3 1 3 3 1-3 1-1 3-1-3-3-1z"/>', layout: '<rect x="3" y="4" width="18" height="16" rx="3"/><path d="M12 4v16M12 12h9"/>',
  gear: '<circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M4.2 4.2l2.1 2.1M17.7 17.7l2.1 2.1M2 12h3M19 12h3M4.2 19.8l2.1-2.1M17.7 6.3l2.1-2.1"/>',
  chev: '<path d="m9 6 6 6-6 6"/>', lines: '<path d="M4 8h16M4 12h16M4 16h16"/>', leaf: '<path d="M5 19c0-8 6-14 15-14 0 9-6 15-14 15"/><path d="M5 19 13 11"/>',
  sparkles: '<path d="m12 3 1.8 4.7L18.5 9.5 13.8 11.3 12 16l-1.8-4.7L5.5 9.5l4.7-1.8z"/>', palette: '<path d="M12 3a9 9 0 1 0 0 18c1.2 0 1.6-.9 1.2-1.8-.5-1-.1-2.2 1.3-2.2H17a4 4 0 0 0 4-4c0-5.5-4-10-9-10z"/>',
  search: '<circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/>', keyboard: '<rect x="2" y="6" width="20" height="13" rx="2"/><path d="M6 10h.01M10 10h.01M14 10h.01M18 10h.01M7 15h10"/>',
  display: '<rect x="2" y="4" width="20" height="13" rx="2"/><path d="M8 21h8M12 17v4"/>', hand: '<path d="M7 11V6a2 2 0 0 1 4 0v5M11 10V4a2 2 0 0 1 4 0v6M15 10V6a2 2 0 0 1 4 0v8a7 7 0 0 1-14 0v-2a2 2 0 0 1 4 0"/>',
  apps: '<rect x="3" y="3" width="8" height="8" rx="2"/><rect x="13" y="3" width="8" height="8" rx="2"/><rect x="3" y="13" width="8" height="8" rx="2"/><path d="M17 13v8M13 17h8"/>',
  code: '<path d="m8 8-5 4 5 4M16 8l5 4-5 4"/>', shield: '<path d="M12 3 4 6v6c0 5 3.5 8 8 9 4.5-1 8-4 8-9V6z"/>',
  chart: '<path d="M4 20V10M10 20V4M16 20v-7M22 20H2"/>', info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7.5v.01"/>',
  window: '<rect x="3" y="4" width="18" height="16" rx="3"/><path d="M3 9h18"/>', person: '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
  x: '<path d="M6 6l12 12M18 6 6 18"/>', check: '<path d="m5 12 5 5 9-10"/>', plus: '<path d="M12 5v14M5 12h14"/>',
  arrow: '<path d="M5 12h14M13 6l6 6-6 6"/>', clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
};
const s = (n, f = '') => `<svg class="s ${f}" viewBox="0 0 24 24">${P[n] || ''}</svg>`;
const C = { Safari: '#1E88E5', Xcode: '#1565C0', Slack: '#4A154B', Chrome: '#FBBC05', Mail: '#2196F3', Claude: '#D97757', Terminal: '#2B2B2B',
  Notes: '#FFCC00', Codex: '#222', Figma: '#F24E1E', Music: '#FA233B', Messages: '#34C759', Zoom: '#2D8CFF', Finder: '#4FA3F7', Spotify: '#1DB954' };
const app = (n, sz = 22) => `<span class="app" style="width:${sz}px;height:${sz}px;flex-basis:${sz}px;border-radius:${sz * .23}px;background:linear-gradient(150deg, ${C[n] || '#888'}, color-mix(in srgb, ${C[n] || '#888'} 70%, #000))"></span>`;
const monoIcon = `<svg viewBox="0 0 18 14" width="17" height="13"><rect x="1" y="1" width="4" height="12" rx="1.5" fill="currentColor"/><rect x="13" y="1" width="4" height="12" rx="1.5" fill="currentColor"/><rect x="7" y="3.5" width="4" height="7" rx="1.2" fill="none" stroke="currentColor" stroke-width="1.3"/></svg>`;
const ring = (pct, col, size = 46, w = 5) => { const r = size / 2 - w / 2 - 1, c = 2 * Math.PI * r; return `<svg viewBox="0 0 ${size} ${size}" width="${size}" height="${size}" style="transform:rotate(-90deg)"><circle cx="${size / 2}" cy="${size / 2}" r="${r}" fill="none" stroke="var(--off)" stroke-width="${w}"/><circle cx="${size / 2}" cy="${size / 2}" r="${r}" fill="none" stroke="${col}" stroke-width="${w}" stroke-linecap="round" stroke-dasharray="${c * pct / 100} ${c}"/></svg>`; };
const win = (x, y, w, h, title, appName, extra = '') => `<div style="position:absolute;left:${x}px;top:${y}px;width:${w}px;height:${h}px;border-radius:10px;background:var(--win-content);box-shadow:0 10px 30px rgba(0,0,0,.25),0 0 0 .5px var(--sep);overflow:hidden;${extra}">
  <div style="height:26px;display:flex;align-items:center;gap:6px;padding:0 9px;background:var(--win);font-size:11px;color:var(--ink-2)"><i style="width:9px;height:9px;border-radius:50%;background:#FF5F57"></i><i style="width:9px;height:9px;border-radius:50%;background:#FEBC2E"></i><i style="width:9px;height:9px;border-radius:50%;background:#28C840"></i><span style="margin-left:6px">${title}</span></div>
  <div style="padding:12px;display:grid;gap:7px"><b style="display:block;height:9px;width:50%;border-radius:5px;background:${C[appName] || '#888'};opacity:.7"></b>${'<i style="display:block;height:6px;border-radius:3px;background:var(--off)"></i>'.repeat(Math.max(2, Math.floor((h - 60) / 14)))}</div></div>`;
const menubar = (right = '') => `<div class="menubar"><b>Finder</b><span>File</span><span>Edit</span><span>View</span><span>Go</span><span>Window</span><div class="r">${right}<span>Wed 12 Nov&nbsp;&nbsp;21:54</span></div></div>`;
// Three concentric rings, like Activity: each [percent, colour], outside in. A thin gap between rings, rounded ends.
const rings3 = (rs, size = 112, w = 11, gap = 3) => {
  const c = size / 2;
  return `<svg viewBox="0 0 ${size} ${size}" width="${size}" height="${size}" style="transform:rotate(-90deg);flex:0 0 ${size}px">${rs.map(([p, col], i) => {
    const r = c - w / 2 - i * (w + gap), len = 2 * Math.PI * r;
    return `<circle cx="${c}" cy="${c}" r="${r}" fill="none" stroke="${col}" stroke-opacity=".18" stroke-width="${w}"/>
      <circle cx="${c}" cy="${c}" r="${r}" fill="none" stroke="${col}" stroke-width="${w}" stroke-linecap="round" stroke-dasharray="${len * Math.min(p, 100) / 100} ${len}"/>`;
  }).join('')}</svg>`;
};
// A legend row for the rings: colour bar, label, value and a short note.
const ringRow = (col, label, value, note) => `<div style="display:flex;gap:8px;align-items:flex-start"><span style="width:3px;height:30px;border-radius:2px;background:${col};margin-top:1px"></span>
  <div><div class="t3" style="font-weight:600;color:${col}">${label}</div><div class="row" style="gap:5px;align-items:baseline"><span class="num" style="font-size:17px;font-weight:600;line-height:20px">${value}</span><span class="t3">${note}</span></div></div></div>`;

// A Mac chip drawn as Apple shows it in keynotes: a dark glossy package with the core clusters laid
// out as on the die, each core glowing by its value. mode 'load' (0-100%) or 'heat' (°C).
const chipArt = (mode, p, e, g, opts = {}) => {
  const w = opts.width || 316, name = opts.name || 'M3 Pro';
  const colOf = (v) => mode === 'heat'
    ? (v < 55 ? '#0A84FF' : v < 70 ? '#30D158' : v < 85 ? '#FFD60A' : '#FF453A')
    : (v < 40 ? '#30D158' : v < 75 ? '#FFD60A' : '#FF453A');
  const amt = (v) => mode === 'heat' ? Math.min(1, Math.max(0.15, (v - 35) / 55)) : Math.max(0.12, v / 100);
  const core = (v, label, cw, ch) => { const c = colOf(v), a = amt(v);
    return `<div style="width:${cw}px;height:${ch}px;border-radius:5px;position:relative;background:color-mix(in srgb, ${c} ${Math.round(18 + a * 62)}%, #16161a);box-shadow:0 0 ${Math.round(4 + a * 14)}px color-mix(in srgb, ${c} ${Math.round(a * 70)}%, transparent), inset 0 0 0 .5px rgba(255,255,255,.14), inset 0 1px 0 rgba(255,255,255,.18);display:grid;place-items:center;color:#fff;font:600 9px/1.1 'SF Pro Text',sans-serif;text-align:center;text-shadow:0 1px 2px rgba(0,0,0,.5)">${label}<span style="font-weight:500;opacity:.85;font-size:8.5px">${mode === 'heat' ? v + '°' : v + '%'}</span></div>`; };
  const cl = (items, cols, cw, ch) => `<div style="display:grid;grid-template-columns:repeat(${cols},${cw}px);gap:4px">${items.map(([v, l]) => core(v, l, cw, ch)).join('')}</div>`;
  const label = (t) => `<div style="font:600 8px 'SF Pro Text',sans-serif;letter-spacing:.6px;color:rgba(255,255,255,.42);margin-bottom:4px">${t}</div>`;
  const gpu = `<div style="display:grid;grid-template-columns:repeat(6,14px);gap:3px">${g.map((v) => `<div style="width:14px;height:14px;border-radius:3px;background:color-mix(in srgb, ${colOf(v)} ${Math.round(18 + amt(v) * 62)}%, #16161a);box-shadow:0 0 ${Math.round(3 + amt(v) * 8)}px color-mix(in srgb, ${colOf(v)} ${Math.round(amt(v) * 60)}%, transparent), inset 0 0 0 .5px rgba(255,255,255,.12)"></div>`).join('')}</div>`;
  const cache = `<div style="height:16px;border-radius:4px;background:repeating-linear-gradient(90deg, rgba(255,255,255,.07) 0 3px, transparent 3px 6px);box-shadow:inset 0 0 0 .5px rgba(255,255,255,.1)"></div>`;
  return `<div style="width:${w}px;border-radius:20px;padding:6px;background:linear-gradient(145deg,#3a3a40,#121215 55%,#26262b);box-shadow:0 14px 32px rgba(0,0,0,.35), inset 0 1px 0 rgba(255,255,255,.18)">
    <div style="border-radius:15px;padding:12px;background:radial-gradient(120% 90% at 20% 0%, #26262c, #0b0b0e 70%);box-shadow:inset 0 0 0 1px rgba(255,255,255,.07)">
      <div style="display:flex;align-items:baseline;gap:6px;margin-bottom:10px"><span style="font:600 13px 'SF Pro Display',sans-serif;color:#f5f5f7;letter-spacing:.2px">${name}</span><span style="font:500 9.5px 'SF Pro Text',sans-serif;color:rgba(255,255,255,.45)">${mode === 'heat' ? 'heat per core' : 'load per core'}</span></div>
      <div style="display:flex;gap:12px">
        <div>${label('PERFORMANCE')}${cl(p.map((v, i) => [v, 'P' + (i + 1)]), 3, 40, 34)}
             <div style="height:8px"></div>${label('EFFICIENCY')}${cl(e.map((v, i) => [v, 'E' + (i + 1)]), 3, 40, 26)}</div>
        <div style="flex:1">${label('GRAPHICS')}${gpu}<div style="height:8px"></div>${label('CACHE')}${cache}
          <div style="height:8px"></div>${label('NEURAL ENGINE · MEDIA')}
          <div style="display:flex;gap:4px">${core(mode === 'heat' ? 48 : 6, 'Neural', 66, 26)}${core(mode === 'heat' ? 52 : 18, 'Video', 34, 26)}</div></div>
      </div>
    </div></div>`;
};
