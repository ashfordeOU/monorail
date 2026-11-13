/* Monorail by Ashforde® · the site's shared behaviour: theme management, menu, tabs, dials, copy buttons, downloads, film. */
(() => {
  const root = document.documentElement;
  const THEMES = window.MONORAIL_THEMES || {};
  const GROUPS = window.MONORAIL_THEME_GROUPS || {};
  const OWN = { t: 'Monorail', p: ['#FF9E62', '#F66270', '#D63A80', '#7C6CF2', '#33CCDB', '#45D18C', '#FFCC40', '#5C8FFF', '#B06BFF'], g: ['#1B0B1F', '#2A0E2B', '#140A26'], l: ['#FF9E62', '#F66270', '#D63A80'] };
  const store = {
    get(k) { try { return localStorage.getItem(k); } catch (e) { return null; } },
    set(k, v) { try { v == null ? localStorage.removeItem(k) : localStorage.setItem(k, v); } catch (e) {} }
  };
  const dark = matchMedia('(prefers-color-scheme: dark)');

  /* ---------- Theme management: appearance (automatic, light, dark) and colour (Monorail's own or any of its 26 themes) */
  const theme = {
    mode: store.get('monorail-mode') || 'auto',
    colour: store.get('monorail-colour') || 'monorail',
    data(key) { return key === 'monorail' ? OWN : THEMES[key] || OWN; },
    apply() {
      const scheme = this.mode === 'auto' ? (dark.matches ? 'dark' : 'light') : this.mode;
      root.dataset.scheme = scheme;
      const t = this.data(this.colour);
      t.l.forEach((c, i) => root.style.setProperty('--l' + (i + 1), c));
      t.g.forEach((c, i) => root.style.setProperty('--g' + (i + 1), c));
      t.p.forEach((c, i) => root.style.setProperty('--w' + (i + 1), c));
      document.querySelectorAll('meta[name="theme-color"]').forEach(m => m.setAttribute('content', scheme === 'dark' ? '#050507' : '#F4F3F1'));
      document.querySelectorAll('[data-theme-name]').forEach(el => { el.textContent = t.t; });
      document.querySelectorAll('.sw').forEach(b => b.setAttribute('aria-checked', String(b.dataset.key === this.colour)));
      document.querySelectorAll('[data-mode-pick] button').forEach(b => b.setAttribute('aria-selected', String(b.dataset.mode === this.mode)));
      document.dispatchEvent(new CustomEvent('monorail-theme', { detail: { key: this.colour, theme: t, scheme } }));
    },
    setMode(m) { this.mode = m; store.set('monorail-mode', m === 'auto' ? null : m); this.apply(); },
    setColour(k) { this.colour = k; store.set('monorail-colour', k === 'monorail' ? null : k); this.apply(); }
  };
  window.MonorailTheme = theme;
  dark.addEventListener('change', () => { if (theme.mode === 'auto') theme.apply(); });

  // A swatch: the theme's backdrop with its glows, like a tiny overview.
  function swatch(key) {
    const t = theme.data(key), b = document.createElement('button');
    b.type = 'button'; b.className = 'sw'; b.dataset.key = key; b.setAttribute('role', 'radio'); b.title = t.t; b.setAttribute('aria-label', t.t);
    b.style.background = `radial-gradient(circle at 28% 30%, ${t.l[0]} 0 22%, transparent 48%), radial-gradient(circle at 74% 70%, ${t.l[1]} 0 20%, transparent 50%), linear-gradient(135deg, ${t.g[0]}, ${t.g[1]} 55%, ${t.g[2]})`;
    b.addEventListener('click', () => theme.setColour(key));
    return b;
  }
  // Fills every [data-theme-picker]: the header's popover and the homepage's "Make it yours".
  function buildPicker(host) {
    host.innerHTML = '';
    const sets = [['Monorail', ['monorail']], ...Object.entries(GROUPS)];
    sets.forEach(([name, keys]) => {
      const h = document.createElement('h2'); h.textContent = name === 'Monorail' ? 'Colour' : name; host.appendChild(h);
      if (name === 'Monorail') { const p = document.createElement('p'); p.className = 'faint'; p.style.cssText = 'font-size:13px;margin:-4px 0 10px'; p.textContent = 'Monorail’s own colours, or any theme from the app.'; host.appendChild(p); }
      const g = document.createElement('div'); g.className = 'swatches'; g.setAttribute('role', 'radiogroup'); g.setAttribute('aria-label', name);
      keys.forEach(k => g.appendChild(swatch(k))); host.appendChild(g);
    });
  }
  document.querySelectorAll('[data-theme-picker]').forEach(buildPicker);
  document.querySelectorAll('[data-mode-pick] button').forEach(b => b.addEventListener('click', () => theme.setMode(b.dataset.mode)));

  const pop = document.getElementById('theme-pop'), popBtn = document.getElementById('theme-btn');
  if (pop && popBtn) {
    const close = () => { pop.hidden = true; popBtn.setAttribute('aria-expanded', 'false'); };
    popBtn.addEventListener('click', e => { e.stopPropagation(); pop.hidden = !pop.hidden; popBtn.setAttribute('aria-expanded', String(!pop.hidden)); });
    document.addEventListener('click', e => { if (!pop.hidden && !pop.contains(e.target)) close(); });
    document.addEventListener('keydown', e => { if (e.key === 'Escape' && !pop.hidden) { close(); popBtn.focus(); } });
  }
  theme.apply();

  /* ---------- Phone menu */
  const top = document.querySelector('.top'), menuBtn = document.getElementById('menu-btn');
  if (top && menuBtn) {
    menuBtn.addEventListener('click', () => { const open = top.classList.toggle('open'); menuBtn.setAttribute('aria-expanded', String(open)); });
    top.querySelectorAll('nav a').forEach(a => a.addEventListener('click', () => { top.classList.remove('open'); menuBtn.setAttribute('aria-expanded', 'false'); }));
  }

  /* ---------- Tabs: [role=tablist] with buttons whose aria-controls name the panels */
  document.querySelectorAll('[role="tablist"]').forEach(list => {
    const tabs = [...list.querySelectorAll('[role="tab"]')];
    const pick = t => {
      tabs.forEach(x => { const on = x === t; x.setAttribute('aria-selected', String(on)); x.tabIndex = on ? 0 : -1; const p = document.getElementById(x.getAttribute('aria-controls')); if (p) p.hidden = !on; });
      list.dispatchEvent(new CustomEvent('tab', { detail: t }));
    };
    tabs.forEach((t, i) => {
      t.addEventListener('click', () => pick(t));
      t.addEventListener('keydown', e => {
        const d = e.key === 'ArrowRight' ? 1 : e.key === 'ArrowLeft' ? -1 : 0; if (!d) return;
        e.preventDefault(); const n = tabs[(i + d + tabs.length) % tabs.length]; n.focus(); pick(n);
      });
    });
  });

  /* ---------- Dials: <div class="dial" data-value="0.15" data-max="100" data-label="…" data-text="…"> */
  const NS = 'http://www.w3.org/2000/svg';
  function drawDial(el) {
    const value = parseFloat(el.dataset.value || '0'), max = parseFloat(el.dataset.max || '100'), frac = Math.max(0, Math.min(1, value / max));
    const n = 72, svg = document.createElementNS(NS, 'svg'); svg.setAttribute('viewBox', '0 0 200 200'); svg.setAttribute('aria-hidden', 'true');
    const lit = Math.max(frac > 0 ? 1 : 0, Math.round(frac * n));
    for (let i = 0; i < n; i++) {
      const a = (i / n) * Math.PI * 2 - Math.PI / 2, long = i % 6 === 0, r1 = long ? 78 : 82, r2 = 92;
      const l = document.createElementNS(NS, 'line');
      l.setAttribute('x1', 100 + Math.cos(a) * r1); l.setAttribute('y1', 100 + Math.sin(a) * r1);
      l.setAttribute('x2', 100 + Math.cos(a) * r2); l.setAttribute('y2', 100 + Math.sin(a) * r2);
      l.setAttribute('stroke-linecap', 'round'); l.setAttribute('stroke-width', long ? 2.4 : 1.6);
      l.setAttribute('stroke', i < lit ? `var(--l${1 + Math.min(2, Math.floor(i / n * 3))})` : 'var(--hair2)');
      if (i < lit) l.style.filter = 'drop-shadow(0 0 3px var(--l2))';
      svg.appendChild(l);
    }
    const c = document.createElementNS(NS, 'circle'); c.setAttribute('cx', 100); c.setAttribute('cy', 100); c.setAttribute('r', 64);
    c.setAttribute('fill', 'none'); c.setAttribute('stroke', 'var(--hair)'); c.setAttribute('stroke-dasharray', '2 5'); svg.appendChild(c);
    el.prepend(svg);
    if (!el.querySelector('.val')) {
      const v = document.createElement('div'); v.className = 'val';
      v.innerHTML = `<b></b><span></span>`; v.querySelector('b').textContent = el.dataset.text || value; v.querySelector('span').textContent = el.dataset.label || '';
      el.appendChild(v);
    }
  }
  document.querySelectorAll('.dial').forEach(drawDial);

  /* ---------- Copy buttons: <button class="copy" data-copy="text"> or next to a <code> in .cmd */
  document.addEventListener('click', e => {
    const b = e.target.closest && e.target.closest('.copy'); if (!b) return;
    const text = b.dataset.copy || (b.closest('.cmd') && b.closest('.cmd').querySelector('code').textContent) || '';
    const done = () => { const old = b.textContent; b.textContent = 'Copied'; b.classList.add('done'); setTimeout(() => { b.textContent = old; b.classList.remove('done'); }, 1600); };
    if (navigator.clipboard) navigator.clipboard.writeText(text).then(done, () => {}); else done();
  });

  /* ---------- Downloads: the latest release, every .dl link, the after-download steps, and the right download for this computer */
  const fmtDate = s => new Date(s).toLocaleDateString(undefined, { day: 'numeric', month: 'long', year: 'numeric' });
  fetch('/releases/latest.json').then(r => r.ok ? r.json() : null).then(rel => {
    if (!rel) return;
    const version = String(rel.tag_name || '').replace(/^v/, ''), assets = rel.assets || [];
    const dmg = assets.find(a => /^Monorail.*\.dmg$/i.test(a.name)) || assets.find(a => /\.dmg$/i.test(a.name));
    const mb = dmg ? (dmg.size / 1048576).toFixed(1) + ' MB' : '';
    const date = rel.published_at ? fmtDate(rel.published_at) : '';
    document.querySelectorAll('[data-version]').forEach(el => { el.textContent = version; });
    // What's new in a version shows once that version is the latest release (or anything newer).
    const atLeast = (a, b) => { const x = a.split('.').map(Number), y = b.split('.').map(Number);
      for (let i = 0; i < 3; i++) { if ((x[i] || 0) !== (y[i] || 0)) return (x[i] || 0) > (y[i] || 0); } return true; };
    document.querySelectorAll('[data-from]').forEach(el => { if (version && atLeast(version, el.dataset.from)) el.classList.add('released'); });
    document.querySelectorAll('[data-release-date]').forEach(el => { el.textContent = date; });
    document.querySelectorAll('[data-size]').forEach(el => { el.textContent = mb; });
    document.querySelectorAll('[data-release-line]').forEach(el => { el.textContent = `Version ${version}${mb ? ' · ' + mb : ''}${date ? ' · ' + date : ''} · macOS 13 or later`; });
    if (dmg) document.querySelectorAll('a.dl').forEach(a => { a.title = `Monorail ${version} · ${mb} · macOS 13 or later`; a.dataset.name = dmg.name; });
  }).catch(() => {});

  const after = document.getElementById('afterdl');
  document.addEventListener('click', e => {
    const a = e.target.closest && e.target.closest('a.dl'); if (!a || !/(\.dmg|\/download\/?)$/i.test(a.href)) return;
    if (/\/download\/?$/i.test(a.href) && !(e.metaKey || e.ctrlKey || e.shiftKey)) { e.preventDefault(); location.href = '/releases/latest/Monorail.dmg'; }
    if (after) { const n = document.getElementById('afterdlname'); if (n) n.textContent = a.dataset.name || 'the Monorail DMG'; after.hidden = false; }
  });
  const afterX = document.getElementById('afterdlclose'); if (afterX) afterX.addEventListener('click', () => { after.hidden = true; });

  // A Mac gets the Mac download; Windows and Linux get their beta; anything else (a phone) sees every platform.
  const ua = navigator.userAgent || '';
  const plat = (navigator.userAgentData && navigator.userAgentData.platform) || navigator.platform || ua;
  const touchMac = /mac/i.test(plat) && navigator.maxTouchPoints > 1;
  const isMac = /mac/i.test(plat) ? !touchMac : !/win|linux|android|iphone|ipad|ipod|ios|cros|x11/i.test(plat + ' ' + ua);
  root.dataset.os = isMac ? 'mac' : 'other';
  const system = /win/i.test(plat) && !/darwin/i.test(plat) ? 'windows' : /linux|x11/i.test(plat + ' ' + ua) && !/android|cros/i.test(ua) ? 'linux' : null;
  if (!isMac) document.querySelectorAll('[data-smartdl]').forEach(a => {
    a.classList.remove('dl'); a.removeAttribute('title');
    const label = a.querySelector('[data-dl-label]'), sub = a.querySelector('[data-dl-sub]');
    a.href = system ? '/download/' + system + '/' : '/#get';
    if (label) label.textContent = system === 'windows' ? (a.dataset.short ? 'Windows beta' : 'Download the Windows beta') : system === 'linux' ? (a.dataset.short ? 'Linux beta' : 'Download the GNOME beta') : 'Get Monorail';
    if (sub) sub.textContent = system ? 'Free · beta · no admin rights needed' : 'For Mac, with Windows and Linux betas';
  });

  /* ---------- Product Hunt welcome (?ref=producthunt or a Product Hunt referrer) */
  const ph = document.getElementById('phbar');
  if (ph) {
    const fromPH = /(^|[?&])ref=producthunt/i.test(location.search) || /producthunt\.com/i.test(document.referrer);
    if (fromPH && store.get('monorail-ph-closed') !== '1') ph.classList.add('show');
    const x = document.getElementById('phclose'); if (x) x.addEventListener('click', () => { ph.classList.remove('show'); store.set('monorail-ph-closed', '1'); });
  }

  /* ---------- The film */
  const film = document.getElementById('film'), filmOpen = document.querySelectorAll('[data-film]');
  if (film) {
    const v = film.querySelector('video');
    filmOpen.forEach(b => b.addEventListener('click', () => {
      if (typeof film.showModal !== 'function') { location.href = '/assets/launch/v17/monorail-demo.mp4'; return; }
      film.showModal(); try { v.play(); } catch (e) {}
    }));
    film.addEventListener('close', () => v.pause());
    film.addEventListener('click', e => { if (e.target === film) film.close(); });
  }
})();
