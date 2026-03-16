-- migrations/001-initial.sql

CREATE TABLE IF NOT EXISTS users (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  name         TEXT NOT NULL UNIQUE,        -- login handle, e.g. "tim"
  display_name TEXT NOT NULL                -- shown in UI, e.g. "Tim"
);

CREATE TABLE IF NOT EXISTS entries (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  title        TEXT NOT NULL,               -- the word or syllable
  body         TEXT,                        -- definition / notes
  phonetic     TEXT,                        -- IPA or informal phonetic spelling
  created_by   INTEGER NOT NULL REFERENCES users(id),
  created_at   TEXT NOT NULL DEFAULT (datetime('now')),
  deleted_at   TEXT                         -- soft delete; NULL = active
);

CREATE TABLE IF NOT EXISTS entry_changes (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  entry_id     INTEGER NOT NULL REFERENCES entries(id),
  changed_by   INTEGER NOT NULL REFERENCES users(id),
  changed_at   TEXT NOT NULL DEFAULT (datetime('now')),
  field        TEXT NOT NULL,               -- 'title', 'body', 'phonetic'
  old_value    TEXT,
  new_value    TEXT
);

-- Seed a few family members; extend as needed.
INSERT OR IGNORE INTO users (name, display_name) VALUES
  ('tim',   'Tim'),
  ('anna',  'Anna'),
  ('guest', 'Guest');
