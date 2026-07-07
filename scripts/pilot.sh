#!/usr/bin/env bash
# RestOS pilot operator script (Git Bash / Linux). Mirror of pilot.ps1.
# PILOT SOFTWARE — synthetic data by default; not a certified production system.
#
# Usage (from restos-platform/):
#   ./scripts/pilot.sh check-env | install | up | down | urls | backup | restore <file> | upgrade
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE="$ROOT/compose/docker-compose.full.yml"
ENV_FILE="$ROOT/.env"
BACKUP_DIR="$ROOT/backups"
DC() { docker compose -f "$COMPOSE" "$@"; }

fail() { echo "ERROR: $*" >&2; exit 1; }
info() { echo ">> $*"; }

load_env() {
  [ -f "$ENV_FILE" ] || fail ".env not found. Copy .env.pilot.example to .env and fill it in."
  set -a; # shellcheck disable=SC1090
  . "$ENV_FILE"; set +a
}

check_env() {
  load_env
  local bad=()
  for k in POSTGRES_PASSWORD JWT_ACCESS_SECRET JWT_REFRESH_SECRET; do
    local v="${!k:-}"
    if [ -z "$v" ] || [[ "$v" == change-me* ]]; then bad+=("$k"); fi
  done
  [ ${#bad[@]} -eq 0 ] || fail "these REQUIRED .env values are missing or still 'change-me': ${bad[*]}"
  info "check-env OK."
}

wait_healthy() {
  info "waiting for services to become healthy (up to 3 min)..."
  local end=$(( $(date +%s) + 180 ))
  while [ "$(date +%s)" -lt "$end" ]; do
    local ps; ps="$(DC ps --format '{{.Name}} {{.Status}}' 2>/dev/null || true)"
    if [ -n "$ps" ] && ! grep -q 'health: starting\|unhealthy' <<<"$ps"; then
      info "all services report healthy."; return 0
    fi
    sleep 5
  done
  echo "WARN: some services did not report healthy in time — check 'docker compose ps'." >&2
}

urls() {
  cat <<'EOF'

RestOS pilot — service URLs:
  restos-web (ordering UI)    http://localhost:8081/
  restos-core API + Swagger   http://localhost:8080/swagger-ui/index.html
  restos-portal API + Swagger http://localhost:3000/docs
  Grafana (dashboards)        http://localhost:3001/  (Pilot health / Live Stack)
  Prometheus (alerts)         http://localhost:9090/alerts

PILOT SOFTWARE — synthetic data by default; not a certified production/POS system.
EOF
}

backup() {
  load_env; mkdir -p "$BACKUP_DIR"
  local out="$BACKUP_DIR/restos-$(date +%Y%m%d-%H%M%S).sql.gz"
  info "backing up '$POSTGRES_DB' -> $out"
  DC exec -T postgres pg_dump --clean --if-exists -U "$POSTGRES_USER" -d "$POSTGRES_DB" | gzip > "$out"
  info "backup written: $out ($(du -h "$out" | cut -f1))"
}

restore() {
  local f="${1:-}"; [ -n "$f" ] && [ -f "$f" ] || fail "restore needs a backup file: pilot.sh restore <file.sql.gz>"
  load_env
  info "restoring '$POSTGRES_DB' from $f (overwrites current data)"
  gunzip -c "$f" | DC exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 >/dev/null
  info "restore complete."
}

case "${1:-help}" in
  check-env) check_env ;;
  install)   check_env; info "building + starting..."; DC up -d --build; wait_healthy; urls ;;
  up)        DC up -d; wait_healthy; urls ;;
  down)      DC down ;;
  urls)      urls ;;
  backup)    backup ;;
  restore)   restore "${2:-}" ;;
  upgrade)   info "upgrade (backup first)..."; backup; DC pull || true; DC up -d --build; wait_healthy; urls
             info "rollback path: pilot.sh restore <the backup just made>, then up." ;;
  *) echo "Commands: check-env | install | up | down | urls | backup | restore <file> | upgrade" ;;
esac
