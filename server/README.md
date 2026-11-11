# Monorail usage counts server

A Cloudflare Worker with a D1 database. Monorail posts one anonymous heartbeat per Mac per day
(see `Sources/Monorail/Telemetry.swift` for exactly what's in it); the Worker keeps one row per
install per day and never stores IP addresses. It fits in Cloudflare's free plan.

## Deploy (about 5 minutes)

```bash
cd server
npx wrangler login
npx wrangler d1 create monorail-stats        # copy the database_id into wrangler.toml
npx wrangler d1 execute monorail-stats --remote --file schema.sql
npx wrangler secret put STATS_KEY            # any long random string; it guards the dashboard
npx wrangler deploy                          # prints https://monorail-stats.<you>.workers.dev
```

Then point the app at it by committing the URL to `server/endpoint.txt` on main:

```bash
echo "https://monorail-stats.<you>.workers.dev/v1/heartbeat" > server/endpoint.txt
```

Monorail reads that file (cached for a week), so the server can be set up or moved without a new
release. Until the file exists, Monorail sends nothing.

## See the numbers

- Dashboard: `https://monorail-stats.<you>.workers.dev/dashboard?key=STATS_KEY`
- JSON: `https://monorail-stats.<you>.workers.dev/v1/stats?key=STATS_KEY`

It shows active installs today, over 7 and 30 days, and ever, with a 90-day chart, plus breakdowns
by version, macOS, Mac model, chip, memory, displays, country, language, install source, update
channel, settings people change and the most used actions.

## Downloads and website visits

`POST /v1/count` adds one to a day's count of a download (`mac-dmg`, `mac-pkg`, `mac-zip`,
`windows-beta`, `gnome-beta`, `install-script`, with the version) or a page view (the path), with the
site the visitor came from and the country. The website sends these from `site/count.js` (no cookies,
skipped for Do Not Track and Global Privacy Control) and `scripts/install.sh` sends one per install.
They appear on the same dashboard under **Downloads** and **Website visits**.

## Retention

To keep 13 months of data, run this monthly (for example from a Cron Trigger):
`DELETE FROM heartbeats WHERE day < date('now', '-395 days');`
