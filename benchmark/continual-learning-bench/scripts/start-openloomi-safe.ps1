# start-openloomi-safe.ps1
# Start OpenLoomi dev server with a memory-safe Node.js heap limit.
# Bypasses `pnpm dev` (which forces 16GB old-space, fatal on 16GB hosts).
# Usage (PowerShell):
#   powershell -ExecutionPolicy Bypass -File D:\openloomi3\openloomi\benchmark\continual-learning-bench\scripts\start-openloomi-safe.ps1

[CmdletBinding()]
param(
    [int]$Port = 3515,
    [int]$MaxOldSpaceMB = 4096,
    [string]$WebRoot = "D:\openloomi3\openloomi\apps\web"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "==== OpenLoomi dev server (memory-safe) ====" -ForegroundColor Cyan
Write-Host "Web root : $WebRoot"
Write-Host "Port     : $Port"
Write-Host "Heap     : ${MaxOldSpaceMB} MB (down from the hard-coded 16384)"
Write-Host ""

# Port check
$existing = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue
if ($existing) {
    $procId = $existing.OwningProcess
    $procName = (Get-Process -Id $procId -ErrorAction SilentlyContinue).ProcessName
    Write-Host "Port $Port already in use by $procName (pid $procId)" -ForegroundColor Yellow
    $ans = Read-Host "Kill it? (y/N)"
    if ($ans -eq "y" -or $ans -eq "Y") {
        Stop-Process -Id $procId -Force
        Start-Sleep -Seconds 1
    } else {
        Write-Host "Aborting." -ForegroundColor Red
        exit 1
    }
}

# Sanity
if (-not (Test-Path "$WebRoot\.env")) {
    Write-Host "apps/web/.env missing; run `pnpm dev` once to generate it, or copy from a backup." -ForegroundColor Red
    exit 1
}
if (-not (Test-Path "$WebRoot\node_modules\next\dist\bin\next")) {
    Write-Host "apps/web/node_modules missing; running pnpm install --filter web..." -ForegroundColor Yellow
    Push-Location (Split-Path $WebRoot -Parent)
    try { pnpm install --filter web 2>&1 | Out-Host } catch { Pop-Location; throw }
    Pop-Location
}

Write-Host "Starting Next.js dev with heap=${MaxOldSpaceMB}MB, host=0.0.0.0, port=$Port" -ForegroundColor Cyan
Write-Host "Watch this window for [AgentAPI] logs (each CL-bench model call shows up here)." -ForegroundColor Cyan
Write-Host "Ctrl+C to stop." -ForegroundColor Yellow
Write-Host ""

Push-Location $WebRoot
try {
    # Run the same commands as the package.json dev script, but with a sane
    # --max-old-space-size and without --turbo (Turbopack's Rust side is more
    # memory-hungry than Webpack).
    $env:NODE_OPTIONS = "--max-old-space-size=$MaxOldSpaceSize --require ./scripts/patch-http-timeout.cjs"
    $env:PORT = $Port
    $env:HOSTNAME = "0.0.0.0"

    # Step 1: ensure AUTH_SECRET / ENCRYPTION_KEY exist in .env
    node ./scripts/ensure-secrets.js

    # Step 2: start next dev with the Webpack backend (lighter than --turbo)
    node ./node_modules/next/dist/bin/next dev --webpack
} finally {
    Pop-Location
}
