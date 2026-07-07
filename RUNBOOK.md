# RUNBOOK — run the whole RestOS stack locally

One `docker compose` command stands up the RestOS ecosystem end to end on your machine:
Postgres-backed **restos-core**, **restos-portal**, the **restos-web** UI, a **Redpanda** broker
with a POS **producer + streaming bronze consumer** (D1), and the **observability spine**
(OpenTelemetry Collector → Prometheus → Grafana).

> Honest scope: a **local developer stack on synthetic data**. No production, no real users.

## Prerequisites

1. **Docker Desktop** running (Engine 24+, Compose v2+). Give it ~4 GB+ RAM.
2. **All RestOS repos checked out as siblings** — the build contexts reach sibling directories:
   ```
   portfolio/
     restos-core/  restos-portal/  restos-web/  restos-data/  restos-platform/  ...
   ```
   Clone what you're missing from https://github.com/arcsymer next to `restos-platform`.

## Run it

From the `restos-platform/` directory:

```sh
docker compose -f compose/docker-compose.full.yml up --build
```

First run builds four images (Maven, two pnpm builds, a Python image) — a few minutes. Add `-d` to
run detached. Watch health with `docker compose -f compose/docker-compose.full.yml ps`.

## What comes up

| Service | URL / port | Check |
|---|---|---|
| restos-core (API) | http://localhost:8080/swagger-ui.html | `GET /actuator/health` → `{"status":"UP"}` |
| restos-core metrics | http://localhost:8080/actuator/prometheus | Micrometer/Prometheus text |
| restos-portal (API) | http://localhost:3000/docs | `GET /health` → `{"status":"ok"}` |
| restos-web (UI) | http://localhost:8081/ | redirects to `/en-US/`, `/pl/` also served |
| Grafana | http://localhost:3001/ | anon viewer; dashboard **RestOS → Live Stack Overview** |
| Prometheus | http://localhost:9090/targets | `restos-core`, `otel-collector-*` targets UP |
| Redpanda | `localhost:19092` (Kafka), http://localhost:9644/public_metrics | broker metrics |
| Postgres | `localhost:5432` (`restos`/`restos`) | backs restos-core |

D1 streaming: `restos-data-producer` sends a burst of synthetic POS events to Redpanda and exits;
`restos-data-streamer` consumes them and appends to a Delta bronze table on the `delta-data` volume.
Inspect what landed:

```sh
docker compose -f compose/docker-compose.full.yml logs restos-data-streamer   # "[streamer] landed batch, total=..."
```

Optional courier UI: `docker compose -f compose/docker-compose.full.yml --profile courier up -d
--build restos-courier` → the Flutter kitchen-display on http://localhost:8082/. The image serves
restos-courier's pre-built `build/web` bundle (tiny nginx, no Flutter toolchain), so run
`flutter build web --release` in restos-courier first — `build/` is gitignored.

## Teardown

```sh
docker compose -f compose/docker-compose.full.yml down          # stop, keep volumes
docker compose -f compose/docker-compose.full.yml down -v       # also drop pgdata/portal-data/delta-data/grafana-data
```

## Troubleshooting

- **A port is in use** — stop the conflicting local service, or edit the `ports:` mapping.
- **restos-core restarts / unhealthy** — it waits for Postgres to be healthy; give it ~45 s on the
  first boot (Flyway migrations + JVM warmup). `docker compose ... logs restos-core`.
- **Build context errors** — you're missing a sibling repo (see Prerequisites) or ran the command
  from the wrong directory (run it from `restos-platform/`).
- **Grafana panels empty** — Prometheus needs a scrape cycle (~15 s) and restos-core must be UP;
  check http://localhost:9090/targets.
- **Low memory** — drop D1 by removing the `redpanda`/`restos-data-*` services, or raise Docker's
  memory in Docker Desktop → Settings → Resources.

The original observability-only stack (`compose/docker-compose.yml`, public images only, no custom
builds) still exists and is what CI validates with `docker compose config`.

---

## Pilot operations (supervised trial)

> **Pilot software. Synthetic data by default. NOT a certified production/POS system** — no real
> payments, no fiscal receipts (KSeF), no compliance certification. See `PILOT_BOUNDARIES.md` and
> the human/legal checklist in the vault's `PILOT_HUMAN.md`.

### One-command install (for a non-developer host)

```powershell
cp .env.pilot.example .env      # then edit .env — set POSTGRES_PASSWORD + the two JWT secrets
./scripts/pilot.ps1 check-env   # fails fast if a REQUIRED value is missing or still "change-me"
./scripts/pilot.ps1 install     # check-env -> build+up -> wait healthy -> print URLs  (idempotent)
```

Git Bash / Linux hosts use `./scripts/pilot.sh <same-commands>`. `install`/`up` are idempotent.

### Load a real venue (real-data readiness)

The demo runs on synthetic data. To load a real venue's menu + tables **without code changes**:

```sh
# 1. copy restos-core/venue.example.json, fill in the real menu/tables/hours/currency
# 2. validate + generate SQL, then apply it to the running Postgres:
node ../restos-core/scripts/load-venue.mjs my-venue.json \
  | docker compose -f compose/docker-compose.full.yml exec -T postgres psql -U restos -d restos
```

`load-venue.mjs` **validates first** and rejects malformed data with clear, row-level errors
(nothing is applied unless the whole file is valid). Verified 2026-07-07: the example venue loads as
2 categories / 4 items / 4 tables; a malformed file is rejected with 5 explicit errors.

### Backups + restore drill

```
./scripts/pilot.ps1 backup            # pg_dump (--clean --if-exists) -> backups\restos-<ts>.sql.gz
./scripts/pilot.ps1 restore <file>    # restore from a backup (into an empty or rebuilt DB)
```

**Restore drill (run 2026-07-07):** `pilot.sh backup` produced a 4 KB gz of the live DB (25 menu
rows); restoring it into a fresh temp database reproduced **25/25 rows** — backup is restorable.
Schedule `backup` daily (Task Scheduler / cron) and keep copies off the pilot machine.

### Upgrade + rollback

```
./scripts/pilot.ps1 upgrade           # backs up first, then rebuild+recreate
# rollback: ./scripts/pilot.ps1 restore <the backup that upgrade just made>, then up
```

### Health + alerting

- **Grafana → "Pilot health — is everything up?"** (http://localhost:3001) — per-service UP/DOWN.
- **Prometheus alert rules** (`compose/alerts.yml`): `ServiceDown`, `CoreHighErrorRate`,
  `NoScrapeTargets` — firing alerts show at http://localhost:9090/alerts. Routing them to a channel
  a human watches (email/Slack/SMS) needs Alertmanager — a `PILOT_HUMAN.md` item, not code.
