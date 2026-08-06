# find-openloomi-token.ps1
# 帮助定位 OpenLoomi 启动时生成的 auth token。
# 思路：在 OpenLoomi 常见启动位置里 grep 一个看起来像 token 的文件。
# 用法：
#   powershell -ExecutionPolicy Bypass -File D:\openloomi3\openloomi\benchmark\continual-learning-bench\scripts\find-openloomi-token.ps1

[CmdletBinding()]
param(
    [string]$OutputToken = "D:\clbench-work\openloomi.token"
)

$ErrorActionPreference = "Continue"

$candidates = @(
    "D:\openloomi3",
    "D:\openloomi3\openloomi",
    "$env:USERPROFILE\.openloomi",
    "$env:APPDATA\openloomi",
    "$env:LOCALAPPDATA\openloomi"
)

$found = @()
foreach ($dir in $candidates) {
    if (Test-Path $dir) {
        Write-Host "搜索 $dir ..." -ForegroundColor Cyan
        $hits = Get-ChildItem -Path $dir -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match "auth" -or $_.Name -match "token" } |
            Select-Object -First 10
        foreach ($hit in $hits) {
            Write-Host "  -> $($hit.FullName)" -ForegroundColor Yellow
            $found += $hit.FullName
        }
    }
}

if ($found.Count -eq 0) {
    Write-Host "没找到。常见位置：" -ForegroundColor Red
    Write-Host "  - OpenLoomi 启动时控制台会打印 'auth token: <xxx>'"
    Write-Host "  - 或者 OpenLoomi 配置文件里的 auth_token 字段"
    Write-Host "  - 或者通过 openloomi-cli / server --print-token 等子命令"
    Write-Host ""
    Write-Host "拿到后存到文件，CL-bench 即可读 OPENLOOMI_TOKEN_PATH："
    Write-Host "  '$($found | Select-Object -First 1)' | Out-File -FilePath $OutputToken -Encoding utf8"
    exit 1
}

Write-Host ""
Write-Host "要复用哪个？把 token 单独存到：" -ForegroundColor Green
Write-Host "  '$OutputToken'" -ForegroundColor Green
Write-Host "然后在 .env 里设 OPENLOOMI_TOKEN_PATH=$OutputToken" -ForegroundColor Green
