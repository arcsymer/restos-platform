<#
  RestOS pilot operator script (Windows / PowerShell).

  PILOT SOFTWARE — synthetic data by default; not a certified production system.

  Usage (run from the restos-platform/ directory):
    ./scripts/pilot.ps1 check-env     # validate .env (fails fast on missing/placeholder values)
    ./scripts/pilot.ps1 install       # check-env -> build+up -> wait healthy -> print URLs
    ./scripts/pilot.ps1 up            # bring the stack up (idempotent)
    ./scripts/pilot.ps1 down          # stop the stack (keeps data volumes)
    ./scripts/pilot.ps1 urls          # print the service URLs
    ./scripts/pilot.ps1 backup        # pg_dump the database to backups\ (gzip)
    ./scripts/pilot.ps1 restore <f>   # restore the database from a backup file
    ./scripts/pilot.ps1 upgrade       # pull/rebuild images and recreate (backup first)

  Idempotent: re-running install/up is safe. All commands act on
  compose/docker-compose.full.yml. A rollback path is: keep the previous backup,
  `down`, restore it, `up`.
#>
[CmdletBinding()]
param(
  [Parameter(Position = 0)][string]$Command = 'help',
  [Parameter(Position = 1)][string]$Arg
)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Compose = Join-Path $Root 'compose\docker-compose.full.yml'
$EnvFile = Join-Path $Root '.env'
$BackupDir = Join-Path $Root 'backups'

function Fail($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }
function Info($msg) { Write-Host $msg -ForegroundColor Cyan }

function Read-DotEnv {
  if (-not (Test-Path $EnvFile)) { Fail ".env not found. Copy .env.pilot.example to .env and fill it in." }
  $map = @{}
  foreach ($line in Get-Content $EnvFile) {
    if ($line -match '^\s*#' -or $line -notmatch '=') { continue }
    $k, $v = $line -split '=', 2
    $map[$k.Trim()] = $v.Trim()
  }
  return $map
}

function Check-Env {
  $env = Read-DotEnv
  $required = @('POSTGRES_PASSWORD', 'JWT_ACCESS_SECRET', 'JWT_REFRESH_SECRET')
  $bad = @()
  foreach ($k in $required) {
    $val = $env[$k]
    if ([string]::IsNullOrWhiteSpace($val) -or $val -like 'change-me*') { $bad += $k }
  }
  if ($bad.Count -gt 0) { Fail "these REQUIRED .env values are missing or still 'change-me': $($bad -join ', ')" }
  Info "check-env OK ($($required.Count) required values set)."
  return $env
}

function Wait-Healthy {
  Info "waiting for services to become healthy (up to 3 min)..."
  $deadline = (Get-Date).AddMinutes(3)
  while ((Get-Date) -lt $deadline) {
    $ps = docker compose -f $Compose ps --format '{{.Name}} {{.Status}}' 2>$null
    $starting = $ps | Select-String 'health: starting'
    $unhealthy = $ps | Select-String 'unhealthy'
    if (-not $starting -and -not $unhealthy -and $ps) { Info "all services report healthy."; return }
    Start-Sleep -Seconds 5
  }
  Write-Host "WARN: some services did not report healthy in time — check 'docker compose ps'." -ForegroundColor Yellow
}

function Show-Urls {
  Write-Host ""
  Write-Host "RestOS pilot — service URLs:" -ForegroundColor Green
  @(
    'restos-web (ordering UI)    http://localhost:8081/',
    'restos-core API + Swagger   http://localhost:8080/swagger-ui/index.html',
    'restos-portal API + Swagger http://localhost:3000/docs',
    'Grafana (dashboards)        http://localhost:3001/  (Pilot health / Live Stack)',
    'Prometheus (alerts)         http://localhost:9090/alerts'
  ) | ForEach-Object { Write-Host "  $_" }
  Write-Host ""
  Write-Host "PILOT SOFTWARE — synthetic data by default; not a certified production/POS system." -ForegroundColor Yellow
}

function Do-Backup {
  $env = Read-DotEnv
  New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $out = Join-Path $BackupDir "restos-$stamp.sql.gz"
  Info "backing up database '$($env.POSTGRES_DB)' -> $out"
  $sql = docker compose -f $Compose exec -T postgres pg_dump --clean --if-exists -U $env.POSTGRES_USER -d $env.POSTGRES_DB
  if ($LASTEXITCODE -ne 0) { Fail "pg_dump failed (is the stack up?)." }
  $bytes = [System.Text.Encoding]::UTF8.GetBytes(($sql -join "`n"))
  $fs = [System.IO.File]::Create($out)
  $gz = New-Object System.IO.Compression.GzipStream($fs, [System.IO.Compression.CompressionMode]::Compress)
  $gz.Write($bytes, 0, $bytes.Length); $gz.Close(); $fs.Close()
  Info "backup written: $out ($([math]::Round((Get-Item $out).Length/1KB,1)) KB)"
}

function Do-Restore($file) {
  if (-not $file -or -not (Test-Path $file)) { Fail "restore needs a backup file: pilot.ps1 restore <file.sql.gz>" }
  $env = Read-DotEnv
  Info "restoring '$($env.POSTGRES_DB)' from $file (this overwrites current data)"
  $fs = [System.IO.File]::OpenRead($file)
  $gz = New-Object System.IO.Compression.GzipStream($fs, [System.IO.Compression.CompressionMode]::Decompress)
  $sr = New-Object System.IO.StreamReader($gz)
  $sql = $sr.ReadToEnd(); $sr.Close(); $gz.Close(); $fs.Close()
  $sql | docker compose -f $Compose exec -T postgres psql -U $env.POSTGRES_USER -d $env.POSTGRES_DB -v ON_ERROR_STOP=1 | Out-Null
  if ($LASTEXITCODE -ne 0) { Fail "restore failed." }
  Info "restore complete."
}

switch ($Command) {
  'check-env' { Check-Env | Out-Null }
  'install' {
    Check-Env | Out-Null
    Info "building + starting the stack..."
    docker compose -f $Compose up -d --build
    if ($LASTEXITCODE -ne 0) { Fail "compose up failed." }
    Wait-Healthy
    Show-Urls
  }
  'up'      { docker compose -f $Compose up -d; Wait-Healthy; Show-Urls }
  'down'    { docker compose -f $Compose down }
  'urls'    { Show-Urls }
  'backup'  { Do-Backup }
  'restore' { Do-Restore $Arg }
  'upgrade' {
    Info "upgrade: backing up first, then rebuilding + recreating..."
    Do-Backup
    docker compose -f $Compose pull 2>$null
    docker compose -f $Compose up -d --build
    Wait-Healthy; Show-Urls
    Info "rollback path if this went wrong: pilot.ps1 restore <the backup just made>, then up."
  }
  default {
    Write-Host "RestOS pilot operator script. Commands: check-env | install | up | down | urls | backup | restore <file> | upgrade"
  }
}
