# Revive Adserver 6.0.8 — Local Docker Setup

Runs [Revive Adserver](https://www.revive-adserver.com/) 6.0.8 locally via
Docker Compose: Apache + PHP 8.1 for the app, MySQL 8 for the database. The
included CLI installer runs automatically on first boot, so there's no
manual web-wizard step. A background `maintenance` service also runs
Revive's Priority Engine on a timer, which real ad delivery depends on (see
[Why is delivery returning a blank pixel?](#why-is-delivery-returning-a-blank-pixel)).

## Prerequisites

- **Docker Desktop for Mac**, installed and running. Works on both Apple
  Silicon and Intel Macs — no extra setup needed.
- Port **8080** free on your machine (change it in `.env` if not).

## Quick start

```bash
git clone <this-repo-url>
cd revive-adserver
docker compose up --build
```

`.env` already ships with working local defaults, so this just works out
of the box — no setup step required. (See [Configuration](#configuration)
below if you want to change anything.)

On the **first run**, watch the `web` container's logs — it waits for
MySQL, then runs Revive's CLI installer (creates the database schema,
admin user, and default plugins):

```bash
docker compose logs -f web
```

You'll see something like:

```
Waiting for database at db:3306...
Database is reachable.
No completed install marker found, running the Revive Adserver CLI installer...
Running checks
Running database
Running configuration
Running jobs
 * plugin:openXBannerTypes: OK
 ...
Running finish
You can now log in at: http://localhost:8080/www/admin
Install complete.
```

On every run **after** that, the installer is skipped (it leaves a marker
file at `revive-adserver-6.0.8/var/.docker-install-complete`), and you'll
just see Apache start up.

## Logging in

Open **http://localhost:8080/www/admin** and log in with the credentials
from `.env`:

| | |
|---|---|
| Username | `ADMIN_USERNAME` (default `admin`) |
| Password | `ADMIN_PASSWORD` (default `Admin1234567!`) |

## Configuration

All settings live in `.env` at the repo root (`.env.example` documents the
same defaults as a reference/reset point):

| Variable | Purpose |
|---|---|
| `MYSQL_ROOT_PASSWORD`, `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD` | Database credentials |
| `APP_PORT` | Host port Revive is served on (default `8080`) |
| `APP_HOST` | Host:port the admin/delivery/image webpaths are installed with (default `localhost:8080`) |
| `ADMIN_USERNAME`, `ADMIN_PASSWORD`, `ADMIN_EMAIL` | Admin account created by the installer |

**Important:** these only take effect on a **fresh** install. Once the
installer has run once, changing `.env` and restarting won't update an
already-installed instance — see [Resetting](#resetting-from-scratch)
below.

Revive enforces a minimum admin password length of **12 characters** — a
shorter `ADMIN_PASSWORD` will cause the installer to fail with an
`adminPassword: Too short` error.

## Common commands

```bash
# Follow logs
docker compose logs -f web

# Stop containers, keep all data (DB + install state)
docker compose down

# Stop and wipe the database volume (see Resetting below for a full reset)
docker compose down -v
```

## Resetting from scratch

`docker compose down -v` wipes the MySQL volume, but the installer also
leaves generated files in `revive-adserver-6.0.8/var/` that make it think
Revive is already installed. To fully reset and force the installer to run
again (e.g. after changing credentials in `.env`):

```bash
docker compose down -v
rm -f revive-adserver-6.0.8/var/.docker-install-complete \
      revive-adserver-6.0.8/var/INSTALLED \
      revive-adserver-6.0.8/var/*.conf.php \
      revive-adserver-6.0.8/var/debug.log \
      revive-adserver-6.0.8/var/install.log
rm -rf revive-adserver-6.0.8/var/cache/* \
       revive-adserver-6.0.8/var/templates_compiled/* \
       revive-adserver-6.0.8/var/plugins/DataObjects \
       revive-adserver-6.0.8/plugins/*/ \
       revive-adserver-6.0.8/www/admin/plugins/*
docker compose up --build
```

(These generated paths are already listed in `.gitignore`, so they won't
show up as changes in `git status` either way.)

## Troubleshooting

- **Port 8080 already in use** — set a different `APP_PORT` in `.env` and
  re-run `docker compose up`.
- **Installer fails with `adminPassword: Too short`** — `ADMIN_PASSWORD`
  in `.env` needs to be 12+ characters.
- **Changed `.env` but nothing changed in the app** — the installer only
  runs once per install; follow [Resetting from scratch](#resetting-from-scratch).

### Why is delivery returning a blank pixel?

If you set up a zone and banner in the admin UI and hit the delivery URL
(e.g. `www/delivery/avw.php?zoneid=1`) but get back a 1×1 transparent GIF
instead of your creative, this is expected for a little while and isn't a
bug in this setup — it's how Revive works:

- Revive doesn't decide what to serve purely from the live campaign/banner
  tables. A separate **Priority Engine** pre-computes a delivery weight per
  ad-zone pairing, and a brand new link starts at weight `0` (never
  delivered) until that engine runs at least once.
- The `maintenance` service in `docker-compose.yml` runs exactly that
  engine (`php scripts/maintenance/maintenance.php localhost`) on a loop,
  every `MAINTENANCE_INTERVAL` seconds (default **300** — 5 minutes).
- Separately, Revive caches "which ads are linked to this zone" to disk
  for 20 minutes (`cacheExpire` in its config) and does **not** invalidate
  that cache when you link a banner via the admin UI. So even once the
  priority is fixed, a stale empty result can keep being served until that
  cache entry expires.

**If you just linked a banner to a zone and want to test immediately**
instead of waiting:

```bash
docker compose exec web php scripts/maintenance/maintenance.php localhost
rm -f revive-adserver-6.0.8/var/cache/deliverycache_*.php
```

Then re-request the delivery URL — it should return the real creative.

## What's in this repo

- `docker-compose.yml` — the `db` (MySQL 8), `web` (Apache/PHP 8.1), and
  `maintenance` (Priority Engine loop) services.
- `docker/Dockerfile` — PHP 8.1 + Apache image with the extensions Revive
  requires (`intl`, `zip`, `mysqli`, `gd`, `opcache`); used to build both
  `web` and `maintenance`.
- `docker/apache-vhost.conf` — Apache vhost config (DocumentRoot +
  `AllowOverride All` so Revive's own `.htaccess` files protect `lib/`,
  `var/`, `etc/`, `plugins/`).
- `docker/entrypoint.sh` — waits for the database, runs Revive's CLI
  installer on first boot, then starts Apache. Used by `web`.
- `docker/maintenance-loop.sh` — waits for the database, then runs
  Revive's Priority Engine on a loop. Used by `maintenance`.
- `revive-adserver-6.0.8/` — the Revive Adserver application source,
  bind-mounted (not copied) into the containers, so edits here are
  reflected live and the folder stays easy to upgrade.
