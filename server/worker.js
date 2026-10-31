// Monorail usage counts: POST /v1/heartbeat stores one row per install per day,
// GET /v1/stats?key=… returns totals, GET /dashboard?key=… shows them.
// The client's IP address is never stored; only Cloudflare's country code is kept.

const str = (v, max = 64) => (typeof v === "string" ? v.slice(0, max) : null);
const int = (v) => (Number.isFinite(v) ? Math.round(v) : null);

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === "POST" && url.pathname === "/v1/heartbeat") return heartbeat(request, env);
    if (request.method === "GET" && (url.pathname === "/v1/stats" || url.pathname === "/dashboard")) {
      if (!env.STATS_KEY || url.searchParams.get("key") !== env.STATS_KEY) return new Response("Not found", { status: 404 });
      const stats = await summary(env);
      if (url.pathname === "/v1/stats") return Response.json(stats);
      return new Response(dashboard(stats), { headers: { "content-type": "text/html; charset=utf-8" } });
    }
    return new Response("Monorail stats", { status: 200 });
  },
};

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
  return {
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
  const max = Math.max(1, ...s.daily.map((d) => d.installs));
  const bars = s.daily.map((d) => `<i title="${d.day}: ${d.installs}" style="height:${(d.installs / max) * 100}%"></i>`).join("");
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
</div><p style="color:var(--muted)">Breakdowns count each install once, using its latest report in the last 30 days.</p></main>`;
}
