# start-openloomi.ps1
# Start the OpenLoomi web server (apps/web Next.js dev mode) on port 3515.
# Usage (PowerShell, NOT inside WSL):
#   powershell -ExecutionPolicy Bypass -File D:\openloomi3\openloomi\benchmark\continual-learning-bench\scripts\start-openloomi.ps1
#
# What it does:
#   1. Verifies port 3515 is free; if not, asks whether to kill the old process.
#   2. Verifies ~/.openloomi/token exists; if not, points out OpenLoomi was never run.
#   3. cd into D:\openloomi3\openloomi, run `pnpm dev` which forwards to apps/web.
#   4. After 5s, probes http://127.0.0.1:3515/ to confirm the server is up.
#   5. Stays attached; Ctrl+C to stop.

[CmdletBinding()]
param(
    [int]$Port = 3515,
    [string]$RepoRoot = "D:\openloomi3\openloomi"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "==== OpenLoomi dev server starter ====" -ForegroundColor Cyan
Write-Host "Repo : $RepoRoot"
Write-Host "Port : $Port"
Write-Host ""

# Sanity: pnpm available?
$pnpm = (Get-Command pnpm -ErrorAction SilentlyContinue)
if (-not $pnpm) {
    Write-Host "pnpm not found in PATH. Install: npm i -g pnpm" -ForegroundColor Red
    exit 1
}
Write-Host "pnpm : $($pnpm.Source)" -ForegroundColor Green

# Sanity: repo layout
if (-not (Test-Path "$RepoRoot\apps\web\package.json")) {
    Write-Host "OpenLoomi repo not found at $RepoRoot\apps\web" -ForegroundColor Red
    exit 1
}
Write-Host "Repo : OK (apps/web/package.json found)" -ForegroundColor Green

# Token file
$tokenFile = Join-Path $env:USERPROFILE ".openloomi\token"
if (Test-Path $tokenFile) {
    $tok = (Get-Content $tokenFile -Raw).Trim()
    Write-Host "Token: $tokenFile ($($tok.Length) chars, first 20: $($tok.Substring(0, [Math]::Min(20, $tok.Length)))...)" -ForegroundColor Green
} else {
    Write-Host "WARNING: token file not found at $tokenFile" -ForegroundColor Yellow
    Write-Host "  -> OpenLoomi has never been run on this machine, or it was deleted." -ForegroundColor Yellow
    Write-Host "  -> Running `pnpm dev` once will create it on first browser visit (or first /api call that requires auth)." -ForegroundColor Yellow
}

# Port check
$existing = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue
if ($existing) {
    $procId = $existing.OwningProcess
    $procName = (Get-Process -Id $procId -ErrorAction SilentlyContinue).ProcessName
    Write-Host "Port $Port is already in use by $procName (pid $procId)" -ForegroundColor Yellow
    $ans = Read-Host "Kill that process? (y/N)"
    if ($ans -eq "y" -or $ans -eq "Y") {
        Stop-Process -Id $procId -Force
        Start-Sleep -Seconds 1
        Write-Host "Killed." -ForegroundColor Green
    } else {
        Write-Host "Aborting." -ForegroundColor Red
        exit 1
    }
}

# Ensure apps/web has a node_modules and .next dir already (otherwise first-run is 5+ min).
$nm = "$RepoRoot\apps\web\node_modules"
$nx = "$RepoRoot\apps\web\.next"
if (-not (Test-Path $nm)) {
    Write-Host "apps/web/node_modules missing; running pnpm install (this may take 2-5 min)..." -ForegroundColor Yellow
    Push-Location $RepoRoot
    try { pnpm install --filter web 2>&1 | Out-Host } catch { Write-Host "pnpm install failed: $_" -ForegroundColor Red; Pop-Location; exit 1 }
    Pop-Location
} else {
    Write-Host "apps/web/node_modules : present" -ForegroundColor Green
}
if (Test-Path $nx) {
    Write-Host "apps/web/.next : present (warm cache)" -ForegroundColor Green
} else {
    Write-Host "apps/web/.next : missing (first dev start will build it; ~30-90s)" -ForegroundColor Yellow
}

# Tell Next.js the port (apps/web/scripts/dev.ts may also read PORT from env).
$env:PORT = $Port
$env:HOSTNAME = "0.0.0.0"   # so WSL can reach us
Write-Host ""
Write-Host "Starting: pnpm dev (port $Port, host 0.0.0.0)" -ForegroundColor Cyan
Write-Host "  Once you see 'Ready in ...ms' and 'Local: http://localhost:$Port' it's up." -ForegroundColor Cyan
Write-Host "  Ctrl+C to stop." -ForegroundColor Yellow
Write-Host ""

Push-Location $RepoRoot
try {
    # pnpm dev is the monorepo entry; it forwards to apps/web dev.
    pnpm dev
} finally {
    Pop-Location
}
