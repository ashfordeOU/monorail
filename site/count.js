// Monorail's site counter: one page view per load, and one download per click on a download.
// No cookies, nothing stored on this computer, no IP addresses kept: only the day, the page or file,
// the version, the site a visitor came from (such as producthunt) and the country.
// Skipped when the browser asks not to be tracked (Do Not Track or Global Privacy Control).
(() => {
  const endpoint = 'https://monorail-stats.talkmeout.workers.dev/v1/count';
  if (navigator.doNotTrack === '1' || navigator.globalPrivacyControl === true) {
    window.monorailDownload = () => {};
    return;
  }
  const ref = (() => {
    const tagged = new URLSearchParams(location.search).get('ref');
    if (tagged && /^[a-z0-9.-]{1,40}$/i.test(tagged)) return tagged.toLowerCase();
    let host = '';
    try { host = new URL(document.referrer).hostname.replace(/^www\./, ''); } catch (e) { return 'direct'; }
    if (!host || host === location.hostname) return 'direct';
    const known = [[/producthunt\.com$/, 'producthunt'], [/(^|\.)(x|twitter)\.com$|^t\.co$/, 'x'], [/google\./, 'google'],
      [/bing\.com$/, 'bing'], [/duckduckgo\.com$/, 'duckduckgo'], [/reddit\.com$/, 'reddit'], [/ycombinator\.com$/, 'hackernews'],
      [/linkedin\.com$|^lnkd\.in$/, 'linkedin'], [/github\.com$/, 'github'], [/(chatgpt|openai)\.com$/, 'chatgpt'],
      [/claude\.ai$/, 'claude'], [/perplexity\.ai$/, 'perplexity'], [/bsky\.app$/, 'bluesky'], [/threads\.net$/, 'threads']];
    for (const [re, name] of known) if (re.test(host)) return name;
    return host.slice(0, 40);
  })();
  const send = (body) => {
    const data = JSON.stringify(Object.assign({ ref }, body));
    try {
      if (navigator.sendBeacon && navigator.sendBeacon(endpoint, new Blob([data], { type: 'text/plain' }))) return;
    } catch (e) {}
    fetch(endpoint, { method: 'POST', body: data, keepalive: true, mode: 'no-cors' }).catch(() => {});
  };
  // The version a download gets: read from the site's own release feed.
  const version = (beta) => fetch(beta ? '/releases/index.json' : '/releases/latest.json').then((r) => r.json())
    .then((d) => {
      const release = beta ? (d || []).find((r) => /^beta-/.test(r.tag_name)) : d;
      return release ? String(release.tag_name).replace(/^(v|beta-)/, '') : '';
    }).catch(() => '');
  const counted = new Set();
  window.monorailDownload = (name) => {
    if (counted.has(name)) return;
    counted.add(name);
    version(/beta/.test(name)).then((detail) => send({ kind: 'download', name, detail }));
  };
  const page = location.pathname.replace(/index\.html$/, '').toLowerCase().slice(0, 60) || '/';
  send({ kind: 'visit', name: /^\/[a-z0-9\/._-]*$/.test(page) ? page : '/' });
  // A download page says which file it starts.
  const own = document.body && document.body.dataset.download;
  if (own) window.monorailDownload(own);
  // Download links and buttons anywhere on the site.
  document.addEventListener('click', (e) => {
    const a = e.target.closest && e.target.closest('a[href]');
    if (!a) return;
    const href = a.getAttribute('href');
    let name = '';
    if (/\.dmg$/i.test(href)) name = 'mac-dmg';
    else if (/\.pkg$/i.test(href)) name = 'mac-pkg';
    else if (/releases\/.*\.zip$/i.test(href)) name = /Windows/i.test(href) ? 'windows-beta' : /shell-extension/i.test(href) ? 'gnome-beta' : 'mac-zip';
    // The home page's download buttons fetch the DMG straight away unless opened in a new tab.
    else if (a.classList.contains('dl') && /(^|\/)download\/?$/.test(href) && !(e.metaKey || e.ctrlKey || e.shiftKey)) name = 'mac-dmg';
    if (name) window.monorailDownload(name);
  }, true);
})();
