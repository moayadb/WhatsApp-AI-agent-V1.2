# Runs the whole stack as native Windows processes.
#
#   powershell -ExecutionPolicy Bypass -File "server\run-local.ps1"
#
# Why this exists: the Docker stack in WSL works fine, but a WireGuard tunnel on
# this machine captures traffic to WSL's virtual subnet, so the browser cannot
# reach it. Native Windows loopback is not affected by that route, so everything
# here runs as an ordinary Windows process on 127.0.0.1.
#
# This is a local-testing workaround, NOT the deployment target. Contabo runs
# the Docker stack, which is what deploy.sh sets up.
#
# Prerequisites, both created by the one-time setup already done:
#   C:\Users\USER\pg17      PostgreSQL 17 binaries (17.11)
#   C:\Users\USER\pg17data  the database cluster
#
# PostgreSQL 18 is deliberately not used: its initdb crashes on this machine.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

$PG_BIN  = 'C:\Users\USER\pg17\pgsql\bin'
$PG_DATA = 'C:\Users\USER\pg17data'
$PG_PORT = 5433          # 5433, so the abandoned PG18 install can never collide
$WEB_PORT = 8081

# ------------------------------------------------------------------ postgres
$running = & "$PG_BIN\pg_ctl.exe" -D $PG_DATA status 2>&1 | Out-String
if ($running -notmatch 'server is running') {
  Write-Host 'starting postgres…'
  & "$PG_BIN\pg_ctl.exe" -D $PG_DATA -o "-p $PG_PORT -c listen_addresses=127.0.0.1" -l "$PG_DATA\server.log" start | Out-Null
  Start-Sleep -Seconds 4
}
# The cluster uses trust auth on loopback only. That keeps a password from
# having to exist on disk for what is throwaway local scaffolding.
$dsn = "postgres://postgres@127.0.0.1:$PG_PORT/analyzer"
Write-Host 'postgres ready' -ForegroundColor Green

# ------------------------------------------------------------------- secrets
# Generated once and reused, so sessions and WhatsApp credentials survive a
# restart. Gitignored.
$secretsFile = Join-Path $root '.secrets.local'
if (-not (Test-Path $secretsFile)) {
  $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  $bytes = New-Object byte[] 32
  $rng.GetBytes($bytes); $jwt = -join ($bytes | ForEach-Object { $_.ToString('x2') })
  $rng.GetBytes($bytes); $internal = -join ($bytes | ForEach-Object { $_.ToString('x2') })
  # Written without a BOM on purpose. PowerShell's `Set-Content -Encoding utf8`
  # prefixes one, which makes the first line unmatchable by anything reading the
  # file with grep or a plain parser — the first key silently goes missing.
  [System.IO.File]::WriteAllText(
    $secretsFile,
    "JWT_SECRET=$jwt`nINTERNAL_TOKEN=$internal`n",
    (New-Object System.Text.UTF8Encoding($false))
  )
}
$secrets = @{}
Get-Content $secretsFile | ForEach-Object {
  if ($_ -match '^([A-Z_]+)=(.*)$') { $secrets[$Matches[1]] = $Matches[2] }
}

# Optional local settings, chiefly the model key for the onboarding interview.
$optional = @{}
$envFile = Join-Path $root '.env.local'
if (Test-Path $envFile) {
  Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*([A-Z_]+)\s*=\s*(.+)$') { $optional[$Matches[1]] = $Matches[2].Trim() }
  }
}

# ------------------------------------------------------------------ services
function Start-Node($name, $dir, $vars, $script) {
  $assignments = ($vars.GetEnumerator() | ForEach-Object { "`$env:$($_.Key)='$($_.Value)'" }) -join '; '
  Start-Process powershell `
    -ArgumentList '-NoExit', '-Command', "$assignments; cd '$dir'; node $script" `
    -WindowStyle Minimized
  Write-Host "started $name" -ForegroundColor Green
}

$common = @{
  DATABASE_URL   = $dsn
  INTERNAL_TOKEN = $secrets['INTERNAL_TOKEN']
  LOG_LEVEL      = 'info'
  NODE_ENV       = 'production'
}

$apiVars = $common.Clone()
$apiVars['PORT'] = '3000'
$apiVars['JWT_SECRET'] = $secrets['JWT_SECRET']
$apiVars['WA_SERVICE_URL'] = 'http://127.0.0.1:3100'
$apiVars['MIGRATIONS_DIR'] = Join-Path $root 'db\migrations'
$apiVars['WORKER_INTERVAL_SECONDS'] = '30'
foreach ($k in @('LLM_API_KEY', 'LLM_BASE_URL', 'LLM_MODEL', 'N8N_WEBHOOK_SECRET', 'N8N_INTAKE_URL')) {
  if ($optional[$k]) { $apiVars[$k] = $optional[$k] }
}
Start-Node 'api' (Join-Path $root 'api') $apiVars 'dist/index.js'
Start-Sleep -Seconds 5

$waVars = $common.Clone()
$waVars['PORT'] = '3100'
$waVars['API_URL'] = 'http://127.0.0.1:3000'
foreach ($k in @('N8N_ANALYZE_URL', 'N8N_WEBHOOK_SECRET')) {
  if ($optional[$k]) { $waVars[$k] = $optional[$k] }
}
Start-Node 'wa (baileys)' (Join-Path $root 'wa') $waVars 'dist/index.js'
Start-Sleep -Seconds 3

Start-Node 'web' $root @{ WEB_PORT = "$WEB_PORT"; API_ORIGIN = 'http://127.0.0.1:3000' } 'serve-web.js'
Start-Sleep -Seconds 5

Write-Host ''
try {
  $health = (Invoke-WebRequest "http://127.0.0.1:$WEB_PORT/api/health" -TimeoutSec 10 -UseBasicParsing).Content
  Write-Host "health: $health" -ForegroundColor Green
  Write-Host ''
  Write-Host "  App running at  http://localhost:$WEB_PORT" -ForegroundColor Cyan
} catch {
  Write-Host 'API did not answer — check the minimised PowerShell windows.' -ForegroundColor Yellow
}
