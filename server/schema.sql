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
