# setup-wsl.ps1
# 在 WSL 2 Ubuntu 内部一次性装好 CL-bench 运行环境。
# 用法（在 Windows PowerShell 里）：
#   powershell -ExecutionPolicy Bypass -File D:\openloomi3\openloomi\benchmark\continual-learning-bench\scripts\setup-wsl.ps1
#
# 该脚本会：
#   1. 确认 WSL 2 + Ubuntu 已装
#   2. 在 Ubuntu 内安装 uv（如果还没有）
#   3. 在 D:\clbench-work\continual-learning-bench 下 uv sync --all-extras
#   4. 在 Windows 侧打印 OpenLoomi 宿主机 IP（供 OPENLOOMI_BASE_URL 使用）

[CmdletBinding()]
param(
    [string]$RepoPath = "D:\clbench-work\continual-learning-bench"
)

$ErrorActionPreference = "Stop"

function Write-Section {
    param([string]$Text)
    Write-Host ""
    Write-Host "==== $Text ====" -ForegroundColor Cyan
}

# 1. 确认 WSL 可用且有发行版
Write-Section "Step 1: 检查 WSL 状态"
$wslList = wsl -l -v 2>&1
Write-Host $wslList
if ($wslList -match "没有安装任何 Linux" -or $wslList -match "no installed distributions") {
    Write-Host "未检测到 WSL 发行版，请先以管理员身份运行：" -ForegroundColor Yellow
    Write-Host "  wsl --install -d Ubuntu" -ForegroundColor Yellow
    exit 1
}

# 2. 确认 Ubuntu 在
$defaultDistro = (wsl -l -q | Select-String -Pattern "Ubuntu" -SimpleMatch -ErrorAction SilentlyContinue | Select-Object -First 1)
if (-not $defaultDistro) {
    Write-Host "未找到 Ubuntu 发行版，可装：" -ForegroundColor Yellow
    Write-Host "  wsl --install -d Ubuntu" -ForegroundColor Yellow
    exit 1
}
Write-Host "默认发行版：$defaultDistro" -ForegroundColor Green

# 3. 装 uv
Write-Section "Step 2: 在 WSL Ubuntu 内确认 uv"
wsl -d $defaultDistro -- bash -lc 'command -v uv || (curl -LsSf https://astral.sh/uv/install.sh | sh; echo "export PATH=\$HOME/.local/bin:\$PATH" >> ~/.bashrc)'

# 4. 同步 Python 依赖
Write-Section "Step 3: uv sync --all-extras"
$wslRepoPath = $RepoPath -replace '\\', '/' -replace '^([A-Z]):', '/mnt/$1'
wsl -d $defaultDistro -- bash -lc "cd '$wslRepoPath' && uv sync --all-extras"

# 5. 装 pre-commit hooks
Write-Section "Step 4: pre-commit install"
wsl -d $defaultDistro -- bash -lc "cd '$wslRepoPath' && uv run pre-commit install || true"

# 6. 跑一次 sanity check
Write-Section "Step 5: clbench list"
wsl -d $defaultDistro -- bash -lc "cd '$wslRepoPath' && uv run clbench list" | Select-Object -First 25

# 7. 提示 Docker
Write-Section "Step 6: Docker"
$dockerCheck = wsl -d $defaultDistro -- bash -lc 'command -v docker && docker --version || echo "no docker"'
Write-Host $dockerCheck
if ($dockerCheck -match "no docker") {
    Write-Host "Docker 未在 WSL 中检测到。" -ForegroundColor Yellow
    Write-Host "请安装 Docker Desktop for Windows（已下载到 D:\downloads\DockerDesktopInstaller.exe），" -ForegroundColor Yellow
    Write-Host "并在 Settings -> Resources -> WSL Integration 里启用你的 Ubuntu 发行版。" -ForegroundColor Yellow
    Write-Host "安装后重启 Docker Desktop，重新跑此脚本即可。" -ForegroundColor Yellow
}

# 8. 打印 Windows 宿主 IP
Write-Section "Step 7: Windows 宿主 IP（用于 OPENLOOMI_BASE_URL）"
$hostIp = wsl -d $defaultDistro -- bash -lc 'cat /etc/resolv.conf | grep nameserver | awk "{print \$2}" | head -n1'
Write-Host "WSL 看 Windows 宿主 IP = $hostIp" -ForegroundColor Green
Write-Host "请确认 OpenLoomi 监听 0.0.0.0 而不是 127.0.0.1，然后把 OPENLOOMI_BASE_URL 设为：" -ForegroundColor Green
Write-Host "  OPENLOOMI_BASE_URL=http://$($hostIp.Trim()):3515" -ForegroundColor Green

Write-Section "完成"
Write-Host "下一步：把 .env.openloomi.example 复制为 D:\clbench-work\continual-learning-bench\.env 并填入 token。" -ForegroundColor Green
Write-Host "然后在 WSL Ubuntu 内执行：" -ForegroundColor Green
Write-Host "  cd $wslRepoPath" -ForegroundColor Green
Write-Host "  uv run clbench setup --all" -ForegroundColor Green
Write-Host "  uv run clbench run exploitable_poker --schedule quick_test --system openloomi --system.model claude-sonnet-4-5" -ForegroundColor Green
