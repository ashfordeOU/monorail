import DASHBOARD_HTML from "./dashboard.html";
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
      const noStore = { "cache-control": "no-store", "x-robots-tag": "noindex" };
      if (url.pathname === "/dashboard")
        return new Response(dashboard(), { headers: { "content-type": "text/html; charset=utf-8", ...noStore } });
      const stats = await summary(env, Number(url.searchParams.get("days")) || 30);
      if (url.searchParams.get("weekly") === "1") return new Response(weeklyText(stats), { headers: { "content-type": "text/plain; charset=utf-8", ...noStore } });
      return Response.json(stats, { headers: noStore });
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

// Everything the dashboard shows, for a range of `days` (1–365) ending today, with the same numbers
// for the period before it so changes can be shown.
async function summary(env, days = 30) {
  days = Math.min(365, Math.max(1, Math.round(days) || 30));
  const q = async (sql, ...args) => (await env.DB.prepare(sql).bind(...args).all()).results;
  const since = (n) => `day >= date('now', '-${n} days')`;
  const inRange = `day >= date('now', '-${days - 1} days')`;
  const inPrev = `day >= date('now', '-${2 * days - 1} days') AND day < date('now', '-${days - 1} days')`;
  const one = async (sql) => ((await q(sql))[0] || {}).n || 0;
  const first = `(SELECT id, min(day) AS fd FROM heartbeats GROUP BY id)`;
  const fd = (cond) => cond.replace(/\bday\b/g, "fd");
  const latest = `(SELECT * FROM heartbeats WHERE ${inRange} AND rowid IN (SELECT max(rowid) FROM heartbeats WHERE ${inRange} GROUP BY id))`;
  const by = (col) => q(`SELECT ${col} AS name, count(*) AS n FROM ${latest} GROUP BY ${col} ORDER BY n DESC LIMIT 25`);
  const countBy = (kind, col) => q(`SELECT ${col} AS name, sum(n) AS n FROM counts WHERE kind = '${kind}' AND ${inRange} GROUP BY ${col} ORDER BY n DESC LIMIT 25`);

  const [active, activePrev, newN, newPrev, dl, dlPrev, visits, visitsPrev, activeToday, ever, dlEver] = await Promise.all([
    one(`SELECT count(DISTINCT id) AS n FROM heartbeats WHERE ${inRange}`),
    one(`SELECT count(DISTINCT id) AS n FROM heartbeats WHERE ${inPrev}`),
    one(`SELECT count(*) AS n FROM ${first} WHERE ${fd(inRange)}`),
    one(`SELECT count(*) AS n FROM ${first} WHERE ${fd(inPrev)}`),
    one(`SELECT sum(n) AS n FROM counts WHERE kind = 'download' AND ${inRange}`),
    one(`SELECT sum(n) AS n FROM counts WHERE kind = 'download' AND ${inPrev}`),
    one(`SELECT sum(n) AS n FROM counts WHERE kind = 'visit' AND ${inRange}`),
    one(`SELECT sum(n) AS n FROM counts WHERE kind = 'visit' AND ${inPrev}`),
    one(`SELECT count(DISTINCT id) AS n FROM heartbeats WHERE day = date('now')`),
    one(`SELECT count(DISTINCT id) AS n FROM heartbeats`),
    one(`SELECT sum(n) AS n FROM counts WHERE kind = 'download'`),
  ]);

  // Day by day, for this period and the one before (to draw it faintly behind).
  const span = `day >= date('now', '-${2 * days - 1} days')`;
  const [aDaily, nDaily, dDaily, vDaily] = await Promise.all([
    q(`SELECT day, count(DISTINCT id) AS n FROM heartbeats WHERE ${span} GROUP BY day`),
    q(`SELECT fd AS day, count(*) AS n FROM ${first} WHERE ${fd(span)} GROUP BY fd`),
    q(`SELECT day, sum(n) AS n FROM counts WHERE kind = 'download' AND ${span} GROUP BY day`),
    q(`SELECT day, sum(n) AS n FROM counts WHERE kind = 'visit' AND ${span} GROUP BY day`),
  ]);
  const map = (rows) => Object.fromEntries(rows.map((r) => [r.day, r.n]));
  const series = { active: map(aDaily), installs: map(nDaily), downloads: map(dDaily), visits: map(vDaily) };

  // Retention: of installs at least N days old (started in the last 180 days), how many came back on day N or later.
  const keptSql = (n) => `SELECT count(*) AS eligible,
      coalesce(sum(EXISTS (SELECT 1 FROM heartbeats h WHERE h.id = f.id AND h.day >= date(f.fd, '+${n} days'))), 0) AS kept
      FROM ${first} f WHERE f.fd <= date('now', '-${n} days') AND f.fd >= date('now', '-180 days')`;
  const [r1, r7, r30] = await Promise.all([q(keptSql(1)), q(keptSql(7)), q(keptSql(30))]);
  const rate = ([r]) => ({ eligible: r.eligible, kept: r.kept, pct: r.eligible ? (r.kept / r.eligible) * 100 : null });
  const cohorts = await q(`SELECT min(f.fd) AS start, count(*) AS size,
      sum(EXISTS (SELECT 1 FROM heartbeats h WHERE h.id = f.id AND h.day >= date(f.fd, '+1 days'))) AS d1,
      sum(EXISTS (SELECT 1 FROM heartbeats h WHERE h.id = f.id AND h.day >= date(f.fd, '+7 days'))) AS d7,
      sum(EXISTS (SELECT 1 FROM heartbeats h WHERE h.id = f.id AND h.day >= date(f.fd, '+14 days'))) AS d14,
      sum(EXISTS (SELECT 1 FROM heartbeats h WHERE h.id = f.id AND h.day >= date(f.fd, '+30 days'))) AS d30,
      CAST((julianday('now') - julianday(min(f.fd))) AS INTEGER) AS age
      FROM ${first} f WHERE f.fd >= date('now', '-84 days') GROUP BY strftime('%Y-%W', f.fd) ORDER BY start DESC`);

  // Features: how many active installs have each on, and whether using it in the first week goes with staying.
  const features = {};
  const actions = {};
  const latestRows = await q(`SELECT features, actions FROM ${latest}`);
  for (const row of latestRows) {
    for (const f of JSON.parse(row.features || "[]")) features[f] = (features[f] || 0) + 1;
    for (const [k, v] of Object.entries(JSON.parse(row.actions || "{}"))) actions[k] = (actions[k] || 0) + v;
  }
  const featureRows = await q(`SELECT f.id, h.features,
      EXISTS (SELECT 1 FROM heartbeats k WHERE k.id = f.id AND k.day >= date(f.fd, '+7 days')) AS stayed
      FROM ${first} f JOIN heartbeats h ON h.id = f.id AND h.day < date(f.fd, '+7 days')
      WHERE f.fd <= date('now', '-7 days') AND f.fd >= date('now', '-180 days')`);
  const perInstall = new Map();
  for (const row of featureRows) {
    const e = perInstall.get(row.id) || { stayed: !!row.stayed, features: new Set() };
    for (const name of JSON.parse(row.features || "[]")) e.features.add(name);
    perInstall.set(row.id, e);
  }
  const stay = {};
  for (const { stayed, features: fs } of perInstall.values())
    for (const name of fs) { const c = (stay[name] ||= { with: 0, stayed: 0 }); c.with++; if (stayed) c.stayed++; }
  const baseStayed = perInstall.size ? ([...perInstall.values()].filter((e) => e.stayed).length / perInstall.size) * 100 : null;
  const featureList = Object.keys({ ...features, ...stay }).map((name) => ({
    name, on: features[name] || 0, share: latestRows.length ? ((features[name] || 0) / latestRows.length) * 100 : 0,
    firstWeek: stay[name]?.with || 0, stayed: stay[name]?.with >= 3 ? (stay[name].stayed / stay[name].with) * 100 : null,
  })).sort((a, b) => b.on - a.on).slice(0, 40);

  const sources = await q(`SELECT ref AS name, sum(CASE WHEN kind = 'visit' THEN n ELSE 0 END) AS visits,
      sum(CASE WHEN kind = 'download' THEN n ELSE 0 END) AS downloads FROM counts WHERE ${inRange} GROUP BY ref ORDER BY visits DESC, downloads DESC LIMIT 25`);

  return {
    days, generated: new Date().toISOString(),
    kpi: { active, activePrev, newInstalls: newN, newPrev, downloads: dl, downloadsPrev: dlPrev, visits, visitsPrev, activeToday, ever, downloadsEver: dlEver },
    series,
    retention: { d1: rate(r1), d7: rate(r7), d30: rate(r30), cohorts, base: baseStayed },
    features: featureList,
    actions: Object.entries(actions).sort((a, b) => b[1] - a[1]).slice(0, 25).map(([name, n]) => ({ name, n })),
    sources,
    downloads: { file: await countBy("download", "name"), version: await countBy("download", "detail"), country: await countBy("download", "country") },
    visits: { page: await countBy("visit", "name"), country: await countBy("visit", "country") },
    breakdown: {
      version: await by("version"), macos: await by("macos"), model: await by("model"), chip: await by("chip"),
      memory: await by("memory_gb"), displays: await by("displays"), country: await by("country"),
      language: await by("language"), source: await by("source"), channel: await by("channel"),
    },
  };
}

function dashboard() {
  return DASHBOARD_HTML;
}

// The week in a few lines: for the Monday email and /v1/stats?weekly=1.
function weeklyText(s) {
  const k = s.kpi, r = s.retention;
  const pct = (x) => (x.pct == null ? "—" : Math.round(x.pct) + "%");
  const change = (now, before) => (before ? ` (${now >= before ? "+" : ""}${Math.round(((now - before) / before) * 100)}% on the week before)` : "");
  const top = (rows, key = "n", n = 5) => rows.slice(0, n).map((x) => `  ${x.name || "—"}: ${x[key]}`).join("\n") || "  —";
  return `Monorail, the last ${s.days} days

Active Macs: ${k.active}${change(k.active, k.activePrev)} · ever: ${k.ever}
New installs: ${k.newInstalls}${change(k.newInstalls, k.newPrev)}
Still using after a day / week / month: ${pct(r.d1)} / ${pct(r.d7)} / ${pct(r.d30)}

Downloads: ${k.downloads}${change(k.downloads, k.downloadsPrev)} · ever: ${k.downloadsEver}
Website visits: ${k.visits}${change(k.visits, k.visitsPrev)}

Where visitors came from:
${top(s.sources, "visits")}

Top versions:
${top(s.breakdown.version)}

Top countries:
${top(s.breakdown.country)}
`;
}

// Sent through Resend when RESEND_API_KEY and REPORT_TO are set (wrangler secrets).
async function weeklyEmail(env) {
  if (!env.RESEND_API_KEY || !env.REPORT_TO) return;
  const text = weeklyText(await summary(env, 7));
  await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { authorization: `Bearer ${env.RESEND_API_KEY}`, "content-type": "application/json" },
    body: JSON.stringify({ from: env.REPORT_FROM || "Monorail stats <stats@ashforde.org>", to: [env.REPORT_TO],
      subject: "Monorail this week", text }),
  });
}
