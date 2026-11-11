// Monorail usage counts: POST /v1/heartbeat stores one row per install per day,
// POST /v1/count adds one to a day's download or site-visit count,
// GET /v1/stats?key=… returns totals, GET /dashboard?key=… shows them.
// The client's IP address is never stored; only Cloudflare's country code is kept.

const str = (v, max = 64) => (typeof v === "string" ? v.slice(0, max) : null);
const int = (v) => (Number.isFinite(v) ? Math.round(v) : null);

export default {
  // Every Monday morning: the week's numbers by email (when an email service is set up).
  async scheduled(event, env, ctx) {
    ctx.waitUntil(weeklyEmail(env));
  },
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === "POST" && url.pathname === "/v1/heartbeat") return heartbeat(request, env);
    if (url.pathname === "/v1/count") {
      if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
      if (request.method === "POST") return count(request, env);
    }
    if (request.method === "GET" && (url.pathname === "/v1/stats" || url.pathname === "/dashboard")) {
      if (!env.STATS_KEY || url.searchParams.get("key") !== env.STATS_KEY) return new Response("Not found", { status: 404 });
      const stats = await summary(env);
      if (url.searchParams.get("weekly") === "1") return new Response(weeklyText(stats), { headers: { "content-type": "text/plain; charset=utf-8" } });
      if (url.pathname === "/v1/stats") return Response.json(stats);
      return new Response(dashboard(stats), { headers: { "content-type": "text/html; charset=utf-8" } });
    }
    return new Response("Monorail stats", { status: 200 });
  },
};

const CORS = { "access-control-allow-origin": "*", "access-control-allow-methods": "POST, OPTIONS", "access-control-allow-headers": "content-type" };
const DOWNLOADS = new Set(["mac-dmg", "mac-pkg", "mac-zip", "windows-beta", "gnome-beta", "install-script"]);

// One more download or page visit for today. Sent by the website (a beacon, no cookies) and the
// install script. Only the day, the file or page, the version, where the visitor came from
// (a site name such as producthunt) and Cloudflare's country code are kept.
async function count(request, env) {
  let b;
  try {
    if (Number(request.headers.get("content-length") || 0) > 2048) throw 0;
    b = JSON.parse(await request.text());
  } catch {
    return new Response("Bad request", { status: 400, headers: CORS });
  }
  const kind = b.kind === "download" || b.kind === "visit" ? b.kind : null;
  const name = str(b.name, 60);
  if (!kind || !name || (kind === "download" && !DOWNLOADS.has(name)) || (kind === "visit" && !/^\/[a-z0-9\/._-]*$/.test(name)))
    return new Response("Bad request", { status: 400, headers: CORS });
  const detail = kind === "download" && typeof b.detail === "string" && /^[0-9a-z.+-]{1,20}$/.test(b.detail) ? b.detail : "";
  const ref = typeof b.ref === "string" && /^[a-z0-9.-]{1,40}$/.test(b.ref) ? b.ref : "direct";
  const day = new Date().toISOString().slice(0, 10);
  await env.DB.prepare(
    `INSERT INTO counts (day, kind, name, detail, ref, country, n) VALUES (?1, ?2, ?3, ?4, ?5, ?6, 1)
     ON CONFLICT (day, kind, name, detail, ref, country) DO UPDATE SET n = n + 1`
  ).bind(day, kind, name, detail, ref, str(request.cf?.country, 2) || "").run();
  return new Response(null, { status: 204, headers: CORS });
}

async function heartbeat(request, env) {
  let b;
  try {
    if (Number(request.headers.get("content-length") || 0) > 16384) throw 0;
    b = await request.json();
  } catch {
    return new Response("Bad request", { status: 400 });
  }
  const id = str(b.id, 40);
  if (!id || !/^[0-9a-f-]{36}$/.test(id)) return new Response("Bad request", { status: 400 });
  const day = new Date().toISOString().slice(0, 10);
  const features = Array.isArray(b.features) ? b.features.filter((f) => typeof f === "string").slice(0, 200).map((f) => f.slice(0, 48)) : [];
  const actions = b.actions && typeof b.actions === "object"
    ? Object.fromEntries(Object.entries(b.actions).slice(0, 40).filter(([, v]) => Number.isFinite(v)).map(([k, v]) => [k.slice(0, 48), Math.round(v)]))
    : {};
  await env.DB.prepare(
    `INSERT OR REPLACE INTO heartbeats (id, day, version, macos, model, chip, arch, cores, memory_gb, displays, language, country, source, channel, features, actions, launches, days_installed, windows_managed)
     VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18, ?19)`
  ).bind(
    id, day, str(b.version, 16), str(b.macos, 8), str(b.model, 24), str(b.chip, 40), str(b.arch, 8),
    int(b.cores), str(b.memory_gb, 8), int(b.displays), str(b.language, 4), str(request.cf?.country, 2),
    str(b.source, 12), str(b.channel, 8), JSON.stringify(features), JSON.stringify(actions),
    int(b.launches), int(b.days_installed), str(b.windows_managed, 10)
  ).run();
  return new Response(null, { status: 204 });
}

async function summary(env) {
  const q = async (sql) => (await env.DB.prepare(sql).all()).results;
  const since = (days) => `day >= date('now', '-${days} days')`;
  const latest = `(SELECT * FROM heartbeats WHERE ${since(30)} AND rowid IN (SELECT max(rowid) FROM heartbeats WHERE ${since(30)} GROUP BY id))`;
  const by = (col) => q(`SELECT ${col} AS name, count(*) AS installs FROM ${latest} GROUP BY ${col} ORDER BY installs DESC LIMIT 25`);
  const [[today], [week], [month], [ever]] = await Promise.all([
    q(`SELECT count(DISTINCT id) AS n FROM heartbeats WHERE day = date('now')`),
    q(`SELECT count(DISTINCT id) AS n FROM heartbeats WHERE ${since(7)}`),
    q(`SELECT count(DISTINCT id) AS n FROM heartbeats WHERE ${since(30)}`),
    q(`SELECT count(DISTINCT id) AS n FROM heartbeats`),
  ]);
  const features = {};
  const actions = {};
  for (const row of await q(`SELECT features, actions FROM ${latest}`)) {
    for (const f of JSON.parse(row.features || "[]")) features[f] = (features[f] || 0) + 1;
    for (const [k, v] of Object.entries(JSON.parse(row.actions || "{}"))) actions[k] = (actions[k] || 0) + v;
  }
  const top = (o) => Object.entries(o).sort((a, b) => b[1] - a[1]).slice(0, 30).map(([name, n]) => ({ name, n }));
  const sum = async (kind, days) => (await q(`SELECT coalesce(sum(n), 0) AS n FROM counts WHERE kind = '${kind}'${days ? ` AND ${since(days)}` : ""}`))[0].n;
  const group = (kind, col, days = 30) => q(`SELECT ${col} AS name, sum(n) AS n FROM counts WHERE kind = '${kind}' AND ${since(days)} GROUP BY ${col} ORDER BY n DESC LIMIT 25`);
  const [dlToday, dl7, dl30, dlEver, vToday, v7, v30] = await Promise.all([
    q(`SELECT coalesce(sum(n), 0) AS n FROM counts WHERE kind = 'download' AND day = date('now')`).then((r) => r[0].n),
    sum("download", 7), sum("download", 30), sum("download", 0),
    q(`SELECT coalesce(sum(n), 0) AS n FROM counts WHERE kind = 'visit' AND day = date('now')`).then((r) => r[0].n),
    sum("visit", 7), sum("visit", 30),
  ]);
  const first = `(SELECT id, min(day) AS fd FROM heartbeats GROUP BY id)`;
  const newDaily = await q(`SELECT fd AS day, count(*) AS n FROM ${first} WHERE fd >= date('now', '-90 days') GROUP BY fd ORDER BY fd`);
  const [[newToday], [new7], [new30]] = await Promise.all([
    q(`SELECT count(*) AS n FROM ${first} WHERE fd = date('now')`),
    q(`SELECT count(*) AS n FROM ${first} WHERE fd >= date('now', '-7 days')`),
    q(`SELECT count(*) AS n FROM ${first} WHERE fd >= date('now', '-30 days')`),
  ]);
  // Retention: of the installs at least N days old, how many came back on day N or later.
  const kept = async (n) => (await q(`SELECT count(*) AS eligible,
      coalesce(sum(EXISTS (SELECT 1 FROM heartbeats h WHERE h.id = f.id AND h.day >= date(f.fd, '+${n} days'))), 0) AS kept
      FROM ${first} f WHERE f.fd <= date('now', '-${n} days') AND f.fd >= date('now', '-120 days')`))[0];
  const [r1, r7, r30] = await Promise.all([kept(1), kept(7), kept(30)]);
  const rate = (r) => ({ eligible: r.eligible, kept: r.kept, pct: r.eligible ? Math.round((r.kept / r.eligible) * 100) : null });
  // Weekly cohorts: installs that started each week, and how many came back.
  const cohorts = await q(`SELECT strftime('%Y-W%W', f.fd) AS week, count(*) AS size,
      sum(EXISTS (SELECT 1 FROM heartbeats h WHERE h.id = f.id AND h.day >= date(f.fd, '+1 days'))) AS d1,
      sum(EXISTS (SELECT 1 FROM heartbeats h WHERE h.id = f.id AND h.day >= date(f.fd, '+7 days'))) AS d7,
      sum(EXISTS (SELECT 1 FROM heartbeats h WHERE h.id = f.id AND h.day >= date(f.fd, '+30 days'))) AS d30,
      min(f.fd) AS start
      FROM ${first} f WHERE f.fd >= date('now', '-84 days') GROUP BY week ORDER BY week DESC`);
  // Does using a feature in the first week go with staying? (installs at least 7 days old)
  const featureRows = await q(`SELECT f.id, h.features,
      EXISTS (SELECT 1 FROM heartbeats k WHERE k.id = f.id AND k.day >= date(f.fd, '+7 days')) AS stayed
      FROM ${first} f JOIN heartbeats h ON h.id = f.id AND h.day < date(f.fd, '+7 days')
      WHERE f.fd <= date('now', '-7 days') AND f.fd >= date('now', '-120 days')`);
  const perInstall = new Map();
  for (const row of featureRows) {
    const entry = perInstall.get(row.id) || { stayed: !!row.stayed, features: new Set() };
    for (const name of JSON.parse(row.features || "[]")) entry.features.add(name);
    perInstall.set(row.id, entry);
  }
  const featureCounts = {};
  for (const { stayed, features } of perInstall.values())
    for (const name of features) {
      const c = (featureCounts[name] ||= { with: 0, stayed: 0 });
      c.with++; if (stayed) c.stayed++;
    }
  const baseStayed = [...perInstall.values()].filter((e) => e.stayed).length;
  const base = perInstall.size ? Math.round((baseStayed / perInstall.size) * 100) : null;
  const featureRetention = Object.entries(featureCounts).filter(([, c]) => c.with >= 3)
    .map(([name, c]) => ({ name, installs: c.with, pct: Math.round((c.stayed / c.with) * 100) }))
    .sort((a, b) => b.pct - a.pct || b.installs - a.installs).slice(0, 25);
  // The funnel, day by day: site visits, downloads, new installs.
  const funnelRows = await q(`SELECT day, sum(CASE WHEN kind = 'visit' THEN n ELSE 0 END) AS visits,
      sum(CASE WHEN kind = 'download' THEN n ELSE 0 END) AS downloads FROM counts WHERE ${since(30)} GROUP BY day`);
  const newByDay = Object.fromEntries(newDaily.map((r) => [r.day, r.n]));
  const funnel = funnelRows.map((r) => ({ ...r, installs: newByDay[r.day] || 0 })).sort((a, b) => (a.day < b.day ? 1 : -1));
  const bySource = await q(`SELECT ref AS name, sum(CASE WHEN kind = 'visit' THEN n ELSE 0 END) AS visits,
      sum(CASE WHEN kind = 'download' THEN n ELSE 0 END) AS downloads FROM counts WHERE ${since(30)} GROUP BY ref ORDER BY visits DESC LIMIT 20`);
  return {
    growth: { newToday: newToday.n, new7: new7.n, new30: new30.n, newDaily,
      retention: { d1: rate(r1), d7: rate(r7), d30: rate(r30) }, cohorts,
      featureRetention, featureBase: base, funnel, bySource },
    downloads: { today: dlToday, days7: dl7, days30: dl30, ever: dlEver,
      daily: await q(`SELECT day, sum(n) AS n FROM counts WHERE kind = 'download' AND ${since(90)} GROUP BY day ORDER BY day`),
      file: await group("download", "name"), version: await group("download", "detail"),
      ref: await group("download", "ref"), country: await group("download", "country") },
    visits: { today: vToday, days7: v7, days30: v30,
      daily: await q(`SELECT day, sum(n) AS n FROM counts WHERE kind = 'visit' AND ${since(90)} GROUP BY day ORDER BY day`),
      page: await group("visit", "name"), ref: await group("visit", "ref"), country: await group("visit", "country") },
    active: { today: today.n, days7: week.n, days30: month.n, ever: ever.n },
    daily: await q(`SELECT day, count(*) AS installs FROM heartbeats WHERE ${since(90)} GROUP BY day ORDER BY day`),
    version: await by("version"), macos: await by("macos"), model: await by("model"), chip: await by("chip"),
    arch: await by("arch"), memory: await by("memory_gb"), displays: await by("displays"),
    language: await by("language"), country: await by("country"), source: await by("source"), channel: await by("channel"),
    features: top(features), actions: top(actions),
  };
}

function dashboard(s) {
  const esc = (v) => String(v ?? "—").replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
  const table = (title, rows, key = "installs") => {
    const max = Math.max(1, ...rows.map((r) => r[key] ?? r.n));
    return `<section><h2>${title}</h2>${rows.map((r) => {
      const n = r[key] ?? r.n;
      return `<div class="row"><span>${esc(r.name)}</span><i style="width:${(n / max) * 100}%"></i><b>${n}</b></div>`;
    }).join("") || "<p>No data yet</p>"}</section>`;
  };
  const chart = (rows, key) => {
    const m = Math.max(1, ...rows.map((d) => d[key]));
    return `<div class="chart">${rows.map((d) => `<i title="${d.day}: ${d[key]}" style="height:${(d[key] / m) * 100}%"></i>`).join("")}</div>`;
  };
  const bars = chart(s.daily, "installs").slice('<div class="chart">'.length, -"</div>".length);
  const d = s.downloads, v = s.visits, g = s.growth;
  const pct = (r) => (r.pct == null ? "—" : `${r.pct}%`);
  const growth = `<h1 style="margin-top:28px">Growth</h1>
<div class="kpis"><div class="kpi"><b>${g.newToday}</b><span>New installs today</span></div><div class="kpi"><b>${g.new7}</b><span>New, last 7 days</span></div>
<div class="kpi"><b>${g.new30}</b><span>New, last 30 days</span></div>
<div class="kpi"><b>${pct(g.retention.d1)}</b><span>Back the next day (${g.retention.d1.eligible})</span></div>
<div class="kpi"><b>${pct(g.retention.d7)}</b><span>Still using after a week (${g.retention.d7.eligible})</span></div>
<div class="kpi"><b>${pct(g.retention.d30)}</b><span>Still using after a month (${g.retention.d30.eligible})</span></div></div>
${chart(g.newDaily, "n")}
<div class="grid"><section><h2>Funnel by day (30 days)</h2><table class="t"><tr><th>Day</th><th>Visits</th><th>Downloads</th><th>New installs</th></tr>
${g.funnel.map((r) => `<tr><td>${esc(r.day)}</td><td>${r.visits}</td><td>${r.downloads}</td><td>${r.installs}</td></tr>`).join("") || "<tr><td colspan=4>No data yet</td></tr>"}</table></section>
<section><h2>By source (30 days)</h2><table class="t"><tr><th>Came from</th><th>Visits</th><th>Downloads</th><th>Rate</th></tr>
${g.bySource.map((r) => `<tr><td>${esc(r.name)}</td><td>${r.visits}</td><td>${r.downloads}</td><td>${r.visits ? Math.round((r.downloads / r.visits) * 100) + "%" : "—"}</td></tr>`).join("") || "<tr><td colspan=4>No data yet</td></tr>"}</table></section>
<section><h2>Weekly cohorts: still using after…</h2><table class="t"><tr><th>Week</th><th>New</th><th>1 day</th><th>7 days</th><th>30 days</th></tr>
${g.cohorts.map((c) => `<tr><td>${esc(c.week)}</td><td>${c.size}</td><td>${c.size ? Math.round((c.d1 / c.size) * 100) : 0}%</td><td>${c.size ? Math.round((c.d7 / c.size) * 100) : 0}%</td><td>${c.size ? Math.round((c.d30 / c.size) * 100) : 0}%</td></tr>`).join("") || "<tr><td colspan=5>No data yet</td></tr>"}</table></section>
<section><h2>Features used in the first week → still using after a week (all: ${g.featureBase == null ? "—" : g.featureBase + "%"})</h2>
${g.featureRetention.map((f) => `<div class="row"><span>${esc(f.name)} (${f.installs})</span><i style="width:${f.pct}%"></i><b>${f.pct}%</b></div>`).join("") || "<p>Needs installs at least a week old</p>"}</section></div>`;
  const extra = `<h1 style="margin-top:28px">Downloads</h1>
<div class="kpis"><div class="kpi"><b>${d.today}</b><span>Today</span></div><div class="kpi"><b>${d.days7}</b><span>Last 7 days</span></div>
<div class="kpi"><b>${d.days30}</b><span>Last 30 days</span></div><div class="kpi"><b>${d.ever}</b><span>Ever</span></div></div>
${chart(d.daily, "n")}<div class="grid">${table("File (30 days)", d.file)}${table("Version", d.version)}${table("Came from", d.ref)}${table("Country", d.country)}</div>
<h1 style="margin-top:28px">Website visits</h1>
<div class="kpis"><div class="kpi"><b>${v.today}</b><span>Today</span></div><div class="kpi"><b>${v.days7}</b><span>Last 7 days</span></div>
<div class="kpi"><b>${v.days30}</b><span>Last 30 days</span></div></div>
${chart(v.daily, "n")}<div class="grid">${table("Page (30 days)", v.page)}${table("Came from", v.ref)}${table("Country", v.country)}</div>`;
  return `<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Monorail stats</title>
<style>
.t{width:100%;border-collapse:collapse;font-size:13px}.t th,.t td{text-align:left;padding:4px 6px;border-bottom:1px solid rgba(128,128,128,.2)}.t th{color:var(--muted);font-weight:600}
:root{--bg:#FFF8F3;--card:#fff;--ink:#24112B;--muted:#7A5A70;--accent:#FF6B4A}
@media(prefers-color-scheme:dark){:root{--bg:#120914;--card:#1D1022;--ink:#F6ECF3;--muted:#BFA6B6}}
body{margin:0;padding:24px 16px;background:var(--bg);color:var(--ink);font:15px/1.5 -apple-system,system-ui,sans-serif}
main{max-width:1100px;margin:auto}h1{margin:0 0 16px}.kpis{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px}
.kpi,section{background:var(--card);border-radius:14px;padding:16px}.kpi b{display:block;font-size:30px}.kpi span{color:var(--muted)}
.chart{display:flex;align-items:flex-end;gap:2px;height:120px;margin:12px 0 20px;background:var(--card);border-radius:14px;padding:12px}
.chart i{flex:1;background:var(--accent);border-radius:3px 3px 0 0;min-height:2px}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:12px}h2{font-size:15px;margin:0 0 8px}
.row{display:grid;grid-template-columns:150px 1fr 50px;gap:8px;align-items:center;font-size:13px}.row span{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.row i{height:8px;background:var(--accent);border-radius:4px;opacity:.8}.row b{text-align:right}
</style><main><h1>Monorail installs</h1>
<div class="kpis"><div class="kpi"><b>${s.active.today}</b><span>Active today</span></div><div class="kpi"><b>${s.active.days7}</b><span>Last 7 days</span></div>
<div class="kpi"><b>${s.active.days30}</b><span>Last 30 days</span></div><div class="kpi"><b>${s.active.ever}</b><span>Ever</span></div></div>
<div class="chart">${bars}</div><div class="grid">
${table("Version", s.version)}${table("macOS", s.macos)}${table("Mac model", s.model)}${table("Chip", s.chip)}
${table("Memory", s.memory)}${table("Displays", s.displays)}${table("Country", s.country)}${table("Language", s.language)}
${table("Installed from", s.source)}${table("Channel", s.channel)}${table("Settings changed from default", s.features)}${table("Most used actions (total)", s.actions)}
</div><p style="color:var(--muted)">Breakdowns count each install once, using its latest report in the last 30 days.</p>
${growth}${extra}<p style="color:var(--muted)">Downloads and visits are counted as they happen, with no cookies and no IP addresses; a visit is one page view.</p></main>`;
}

// The week in a few lines: for the Monday email and /v1/stats?weekly=1.
function weeklyText(s) {
  const g = s.growth, r = g.retention, pct = (x) => (x.pct == null ? "—" : x.pct + "%");
  const top = (rows, n = 5) => rows.slice(0, n).map((x) => `  ${x.name || "—"}: ${x.n ?? x.visits}`).join("\n") || "  —";
  return `Monorail, the last 7 days

Active Macs: ${s.active.days7} (30 days: ${s.active.days30}, ever: ${s.active.ever})
New installs: ${g.new7} (30 days: ${g.new30})
Still using after a day / week / month: ${pct(r.d1)} / ${pct(r.d7)} / ${pct(r.d30)}

Downloads: ${s.downloads.days7} (30 days: ${s.downloads.days30}, ever: ${s.downloads.ever})
Website visits: ${s.visits.days7} (30 days: ${s.visits.days30})

Where visitors came from (30 days):
${top(g.bySource.map((x) => ({ name: x.name, n: x.visits })))}

Top versions:
${top(s.version.map((x) => ({ name: x.name, n: x.installs })))}

Top countries:
${top(s.country.map((x) => ({ name: x.name, n: x.installs })))}
`;
}

// Sent through Resend when RESEND_API_KEY and REPORT_TO are set (wrangler secrets).
async function weeklyEmail(env) {
  if (!env.RESEND_API_KEY || !env.REPORT_TO) return;
  const text = weeklyText(await summary(env));
  await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { authorization: `Bearer ${env.RESEND_API_KEY}`, "content-type": "application/json" },
    body: JSON.stringify({ from: env.REPORT_FROM || "Monorail stats <stats@ashforde.org>", to: [env.REPORT_TO],
      subject: "Monorail this week", text }),
  });
}
