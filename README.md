# Family Glossary

A small collaborative web app for a family glossary with full audit trail.
Built with Racket, Koyo, and SQLite.

## Prerequisites

- Racket 8.x — https://racket-lang.org/
- The following packages (install once):

```bash
raco pkg install koyo-lib
raco pkg install db-lib
raco pkg install sqlite-native
raco pkg install gregor-lib
raco pkg install threading-lib
```

## Running locally

```bash
# From the project root:
racket main.rkt
```

Then open http://localhost:8080 in your browser.

The SQLite database file (`family-glossary.db`) is created automatically on
first run, and all migrations in `migrations/` are applied in order.

## Configuration

The following environment variables are respected:

| Variable        | Default                | Purpose                        |
|-----------------|------------------------|--------------------------------|
| `DATABASE_PATH` | `family-glossary.db`   | Path to the SQLite file        |
| `SESSION_SECRET`| (insecure default)     | Secret for signing cookies     |
| `PORT`          | `8080`                 | HTTP port to listen on         |

Always set `SESSION_SECRET` to a random string in production:

```bash
export SESSION_SECRET="$(openssl rand -hex 32)"
```

## Project structure

```
family-glossary/
├── info.rkt                    package metadata
├── main.rkt                    entry point + router
├── components/
│   ├── db.rkt                  SQLite component + migration runner
│   └── session.rkt             Cookie session component
├── models/
│   ├── entry.rkt               Entry CRUD + audit trail writes
│   ├── change.rkt              Audit trail reads
│   └── user.rkt                User lookup
├── controllers/
│   ├── entries.rkt             Entry handlers
│   └── auth.rkt                Login / logout handlers
├── views/
│   ├── layout.rkt              Shared HTML shell
│   ├── entries/                Entry views (index, show, form)
│   └── auth/                   Login view
├── migrations/
│   └── 001-initial.sql         Schema
├── tests/
│   └── models-test.rkt         rackunit model tests
├── deploy/
│   ├── family-glossary.service systemd unit
│   ├── family-glossary.env.template  environment variables template
│   ├── Caddyfile               reverse proxy config
│   └── deploy.sh               server-side deploy script
└── static/
    └── style.css
```

## Possible next steps

- **Passwords**: add a `password_hash TEXT` column to `users`, use `crypto-lib`
  for bcrypt hashing, and check it in `controllers/auth.rkt`.
- **Phonetic suggestions**: call the [Wiktionary API](https://en.wiktionary.org/w/api.php)
  or a local `espeak-ng` subprocess to suggest IPA; store the result as a
  pre-filled but editable field.
- **Filtering by creator**: add a `?user=` query parameter to the index handler
  and a `WHERE created_by = ?` clause in `list-entries`.
- **Pagination**: add `LIMIT`/`OFFSET` to `list-entries` once the list grows.
- **Pharo prototype**: the models layer (schema + CRUD + audit trail) maps
  cleanly onto Pharo objects + Voyage or plain PostgreSQL via Glorp.

## Adding a family member

For now, add a row directly to the database:

```bash
sqlite3 family-glossary.db \
  "INSERT INTO users (name, display_name) VALUES ('maria', 'Maria');"
```

Password support can be added later by adding a `password_hash TEXT` column
to `users` and checking it in `controllers/auth.rkt`.

## Deploying (Hetzner + Caddy + systemd)

See deployment notes in the project wiki.  Short version:

1. Copy files to server, set `SESSION_SECRET` and `DATABASE_PATH` in environment.
2. Create a systemd unit that runs `racket /opt/family-glossary/main.rkt`.
3. Put Caddy in front as a reverse proxy with automatic TLS.
