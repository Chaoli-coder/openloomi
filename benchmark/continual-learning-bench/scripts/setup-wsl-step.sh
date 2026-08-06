#!/usr/bin/env bash
# Step-by-step setup that won't OOM. Run each function separately from WSL.
# Usage inside WSL:
#   bash /mnt/d/openloomi3/openloomi/benchmark/continual-learning-bench/scripts/setup-wsl-step.sh apt
#   bash /mnt/d/openloomi3/openloomi/benchmark/continual-learning-bench/scripts/setup-wsl-step.sh uv
#   bash /mnt/d/openloomi3/openloomi/benchmark/continual-learning-bench/scripts/setup-wsl-step.sh sync
#   bash /mnt/d/openloomi3/openloomi/benchmark/continual-learning-bench/scripts/setup-wsl-step.sh list

set -u

REPO="/mnt/d/clbench-work/continual-learning-bench"

step_apt() {
    echo "==== apt update (cached already, this is fast) ===="
    apt-get update 2>&1 | tail -3

    echo "==== install base packages in small batches to avoid OOM ===="

    # Batch 1: networking + git
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates curl wget git gnupg lsb-release apt-transport-https 2>&1 | tail -3

    # Batch 2: build tools
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        build-essential pkg-config 2>&1 | tail -3

    # Batch 3: python (uv manages its own python; this is for the host fallback)
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        python3 python3-pip python3-venv 2>&1 | tail -3

    # Drop caches to reclaim memory
    apt-get clean
    rm -rf /var/lib/apt/lists/*

    echo "==== disk after apt ===="
    df -h / | tail -1
}

step_uv() {
    export PATH="$HOME/.local/bin:$PATH"
    if command -v uv >/dev/null 2>&1; then
        echo "uv already: $(uv --version)"
        return
    fi
    # Try Aliyun mirror first.
    if curl -fsSL --max-time 20 https://mirrors.aliyun.com/uv/install.sh -o /tmp/uv-install.sh 2>/dev/null; then
        sh /tmp/uv-install.sh
        echo "uv installed via Aliyun"
    else
        curl -LsSf https://astral.sh/uv/install.sh | sh
        echo "uv installed via astral.sh"
    fi
    if ! grep -q '$HOME/.local/bin' ~/.bashrc 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    fi
}

step_sync() {
    export PATH="$HOME/.local/bin:$PATH"
    cd "$REPO" || { echo "repo not found at $REPO"; return 1; }
    export UV_INDEX_URL="https://mirrors.aliyun.com/pypi/simple/"
    echo "==== uv sync --all-extras (this is the long step, ~3-5 min) ===="
    uv sync --all-extras 2>&1 | tail -20
}

step_list() {
    export PATH="$HOME/.local/bin:$PATH"
    cd "$REPO" || { echo "repo not found at $REPO"; return 1; }
    echo "==== clbench list ===="
    uv run clbench list 2>&1 | head -40
}

case "${1:-all}" in
    apt)  step_apt ;;
    uv)   step_uv ;;
    sync) step_sync ;;
    list) step_list ;;
    all)
        step_apt
        step_uv
        step_sync
        step_list
        ;;
    *)
        echo "Usage: $0 {apt|uv|sync|list|all}"
        exit 1
        ;;
esac

echo "==== final free memory ===="
free -h | head -2
