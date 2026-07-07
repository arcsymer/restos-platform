# restos-platform

The DevSecOps backbone for the [RestOS](https://github.com/arcsymer) ecosystem: a **reusable
security workflow** every repo calls, a **security retrofit** (secret + dependency scanning,
Dependabot) across all repos, and an **observability stack** (Postgres + Prometheus + Grafana) that
the services plug into.

[![ci](https://github.com/arcsymer/restos-platform/actions/workflows/ci.yml/badge.svg)](https://github.com/arcsymer/restos-platform/actions/workflows/ci.yml)
![License: MIT](https://img.shields.io/badge/license-MIT-green)

## What's here

- **`.github/workflows/reusable-security.yml`** — a `workflow_call` security scan (gitleaks +
  Trivy filesystem vuln/config scan). Any RestOS repo runs it with three lines:
  ```yaml
  jobs:
    security:
      uses: arcsymer/restos-platform/.github/workflows/reusable-security.yml@main
  ```
- **`SECURITY.md`** — the ecosystem security policy and what's enforced where.
- **`compose/`** — a runnable observability stack (only public images, no custom builds):
  ```sh
  docker compose -f compose/docker-compose.yml up
  ```
  Brings up **Postgres** (:5432), **Prometheus** (:9090), and **Grafana** (:3000, anonymous
  access, Prometheus datasource pre-provisioned). Point restos-core / restos-portal at this
  Postgres and let Prometheus scrape their metrics (restos-core already exposes Actuator).

## Status — honest scope

The **reusable security workflow, the cross-repo Dependabot/gitleaks retrofit, and the
observability compose stack are done** and CI-validated (`docker compose config` runs in CI).

**Deferred (needs local Docker, which this build machine doesn't have):** actually running
`docker compose up` end-to-end, adding a per-service Dockerfile for P1/P3/P4 so the whole app tier
comes up in one command, and a provisioned Grafana dashboard with live app metrics. Exact steps are
in the ecosystem's `HUMAN_TODO`. The compose file and scrape config here are real and run on any
Docker host; wiring each app container in is the remaining step.

## License

MIT — see [LICENSE](LICENSE). Part of the RestOS portfolio. Built end-to-end with an agentic
workflow (Claude Code), orchestrated, reviewed, and directed by me.
