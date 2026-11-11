-- One row per install per day. No IP addresses are stored.
CREATE TABLE IF NOT EXISTS heartbeats (
  id TEXT NOT NULL,
  day TEXT NOT NULL,
  version TEXT, macos TEXT, model TEXT, chip TEXT, arch TEXT,
  cores INTEGER, memory_gb TEXT, displays INTEGER, language TEXT, country TEXT,
  source TEXT, channel TEXT, features TEXT, actions TEXT,
  launches INTEGER, days_installed INTEGER, windows_managed TEXT,
  PRIMARY KEY (id, day)
);
CREATE INDEX IF NOT EXISTS heartbeats_day ON heartbeats(day);

-- Downloads and site visits, counted per day (no IP addresses, no cookies, no per-person IDs).
CREATE TABLE IF NOT EXISTS counts (
  day TEXT NOT NULL,
  kind TEXT NOT NULL,      -- download | visit
  name TEXT NOT NULL,      -- mac-dmg, mac-pkg, mac-zip, windows-beta, gnome-beta, install-script; or a page path
  detail TEXT NOT NULL,    -- the version for downloads
  ref TEXT NOT NULL,       -- where the visitor came from: producthunt, x, google, … or direct
  country TEXT NOT NULL,
  n INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (day, kind, name, detail, ref, country)
);
CREATE INDEX IF NOT EXISTS counts_day ON counts(day);
