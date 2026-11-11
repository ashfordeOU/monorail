// Monorail usage counts: POST /v1/heartbeat stores one row per install per day,
// POST /v1/count adds one to a day's download or site-visit count,
// GET /v1/stats?key=… returns totals, GET /dashboard?key=… shows them.
// The client's IP address is never stored; only Cloudflare's country code is kept.

const str = (v, max = 64) => (typeof v === "string" ? v.slice(0, max) : null);
const int = (v) => (Number.isFinite(v) ? Math.round(v) : null);

export default {
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
  return {
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
  const d = s.downloads, v = s.visits;
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
${extra}<p style="color:var(--muted)">Downloads and visits are counted as they happen, with no cookies and no IP addresses; a visit is one page view.</p></main>`;
}
