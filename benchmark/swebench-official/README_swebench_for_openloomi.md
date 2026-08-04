# SWE-bench Verified on OpenLoomi — End-to-End Guide

本目录是 OpenLoomi 桌面 agent 在 **SWE-bench Verified** 上的端到端测评流水线。
它遵循 JobBench official runner 的最小改动原则：复用 OpenLoomi 现成的
`openloomi-ctl --one-shot` 调用方式，**不**修改任何已有 benchmark 或 OpenLoomi 内部
代码，**不**自己写测试，**不**自己写 judge，**完全**交给 Princeton 官方 Docker
harness 评分。

---

## 0. 目录结构

```
swebench-official/
├── eval/
│   ├── run_benchmark_openloomi.py   # 核心 Python runner（派发 agent）
│   ├── run_swebench.sh              # 启动器
│   └── run_swebench_harness.sh      # 调用官方 Docker harness
├── predictions/
│   └── openloomi-verified.jsonl     # agent 产出（每行一个 instance）
├── trajectories/openloomi-verified/
│   └── <instance_id>/attempt_*.json # 每实例一次尝试的 stdout/stderr/exit_code
├── logs/                            # 启动器与 runner 的运行报告
└── README_swebench_for_openloomi.md # 本文件
```

大型缓存（clone 出的 12 个上游 repo、per-instance workspace、Docker 镜像）建议放
在 `D:\swebench-work\`，**不要**放在 `swebench-official/` 里，否则仓库体积会迅速膨胀。

---

## 1. 一次性准备

### 1.1 系统要求

| 项目 | 要求 |
|---|---|
| Python | ≥ 3.10 |
| Docker Desktop | 已安装并运行，建议 ≥ 120 GB 磁盘、16 GB 内存 |
| Node.js | ≥ 22（`openloomi-ctl` 运行依赖） |
| OpenLoomi Desktop | ≥ 0.8.8，已登录，token 已落到 `~/.openloomi/token` |
| 工作磁盘 | `D:\swebench-work\`（可换路径，但需独立大磁盘） |

### 1.2 拉取并安装官方 harness

```powershell
git clone https://github.com/SWE-bench/SWE-bench.git `
  D:\openloomi3\openloomi\benchmark\SWE-Bench-CL

cd D:\openloomi3\openloomi\benchmark\SWE-Bench-CL
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -e .
```

数据集（`SWE-bench_Verified` 的 500 个 test 实例）已经在
`D:\openloomi3\openloomi\benchmark\SWE-Bench-CL\datasets\SWE-bench_Verified\` 下，
无需再下载。

### 1.3 Smoke test（验证 harness 本身能跑）

```powershell
python -m swebench.harness.run_evaluation `
  --predictions_path gold `
  --max_workers 1 `
  --instance_ids sympy__sympy-20590 `
  --run_id validate-gold
```

预期：`evaluation_results/validate-gold.json` 出现 `sympy__sympy-20590` 为 resolved。

### 1.4 启动 OpenLoomi dev server

另开一个终端：

```powershell
cd D:\openloomi3\openloomi
pnpm tauri:dev
```

等待 `Ready on http://localhost:3515`。

### 1.5 准备 OpenLoomi 调用环境变量

```powershell
$env:OPENLOOMI_API_URL    = "http://127.0.0.1:3515"
$env:OPENLOOMI_CLI_DIRECT = "0"
$env:OPENLOOMI_AUTH_TOKEN = (Get-Content "$HOME\.openloomi\token" -Raw).Trim()
$env:OPENLOOMI_CTL        = "C:\Users\<you>\AppData\Local\Programs\openloomi\cli\openloomi-ctl.exe"
```

> `OPENLOOMI_CLI_DIRECT=0` 强制 `openloomi-ctl` 通过 HTTP API 调用活体 dev server，
> 而不是走 CLI 自带的 in-process native runner。

---

## 2. 阶段一：让 OpenLoomi 生成 predictions

### 2.1 单实例 smoke test

```powershell
cd D:\openloomi3\openloomi\benchmark\swebench-official
.\eval\run_swebench.sh --instance-id django__django-11099 --timeout 1800
```

预期产物：

- `predictions\openloomi-verified.jsonl` 多一行：
  ```json
  {"instance_id":"django__django-11099","model_name_or_path":"openloomi-verified","model_patch":"diff --git ..."}
  ```
- `trajectories\openloomi-verified\django__django-11099\attempt_*.json` 写好
- `D:\swebench-work\workspaces\django__django-11099\src\` 里有真实修改

### 2.2 抽检（小批量）

```powershell
cd D:\openloomi3\openloomi\benchmark\swebench-official
.\eval\run_swebench.sh --limit 20 --timeout 1800 `
  --provider claude --model claude-sonnet-4-6
```

### 2.3 全量 500 实例

```powershell
cd D:\openloomi3\openloomi\benchmark\swebench-official
.\eval\run_swebench.sh `
  --provider claude `
  --model claude-sonnet-4-6 `
  --max-concurrent 1 `
  --timeout 3600
```

**重要参数说明：**

- `--max-concurrent 1`：默认串行。SWE-bench Verified 每个实例要 clone repo +
  install 依赖 + 跑测试，并发打满会拖垮 dev server。谨慎调高。
- `--timeout 3600`：单实例 1 小时上限，Verified 多数实例 5-30 分钟，但偶尔有
  长尾任务。
- runner 是**断点续跑**的：已写入 `predictions/openloomi-verified.jsonl` 的
  `instance_id` 会自动跳过。要重跑就加 `--force`。
- 单实例预测落盘在 `predictions/openloomi-verified.jsonl`，每行一个 JSON 对象：
  ```json
  {"instance_id":"...","model_name_or_path":"openloomi-verified","model_patch":"diff --git ..."}
  ```
  这是官方 `swebench.harness.run_evaluation --predictions_path` 要求的格式。

### 2.4 其它常见过滤

```powershell
# 只跑 django
.\eval\run_swebench.sh --repo django/django

# 只跑若干个 instance
.\eval\run_swebench.sh --instance-id django__django-11099 --instance-id sympy__sympy-20590

# 限速 50 个做烟测
.\eval\run_swebench.sh --limit 50

# 强制重跑（覆盖已有 prediction）
.\eval\run_swebench.sh --force --instance-id django__django-11099
```

### 2.5 输出位置

| 路径 | 内容 |
|---|---|
| `predictions/openloomi-verified.jsonl` | agent 的全部 patch，harness 直接读这个文件 |
| `trajectories/openloomi-verified/<instance_id>/attempt_*.json` | 每次尝试的命令、stdout、stderr、exit_code、duration |
| `logs/openloomi_verified_terminal_<timestamp>.log` | 启动器整段终端 transcript |
| `logs/openloomi_verified_<model>_<timestamp>.json` | runner 汇总：每实例 status、counts |

---

## 3. 阶段二：官方 Docker harness 评分

阶段一结束后，把 predictions 交给 Princeton 官方 harness：

```powershell
cd D:\openloomi3\openloomi\benchmark\swebench-official
.\eval\run_swebench_harness.sh `
  --swe-bench-home D:\openloomi3\openloomi\benchmark\SWE-Bench-CL `
  --predictions .\predictions\openloomi-verified.jsonl `
  --run-id openloomi-verified `
  --max-workers 1
```

或手动执行：

```powershell
cd D:\openloomi3\openloomi\benchmark\SWE-Bench-CL
.\.venv\Scripts\Activate.ps1

python -m swebench.harness.run_evaluation `
  --dataset_name princeton-nlp/SWE-bench_Verified `
  --predictions_path D:\openloomi3\openloomi\benchmark\swebench-official\predictions\openloomi-verified.jsonl `
  --max_workers 1 `
  --run_id openloomi-verified
```

harness 会：

1. 拉/构建每个 instance 的 Docker 镜像（含 base commit + 依赖）
2. apply `model_patch` + `test_patch`
3. 跑 `FAIL_TO_PASS`（必须由失败转通过）+ `PASS_TO_PASS`（必须继续通过）
4. 写出 `logs/run_evaluation/openloomi-verified/...` 与
   `evaluation_results/openloomi-verified.json`

**最终指标 = `evaluation_results/openloomi-verified.json` 中的 `resolved_rate`。**

---

## 4. 关键设计说明

### 4.1 不直接用文本回答

`openloomi-ctl --one-shot` 的 stdout 是 JSON 格式的对话/工具调用结果，**不**作为
SWE-bench 评测输入。runner 在 agent 退出后，在 repo 根目录执行：

```bash
git diff --binary --no-color
```

把仓库里真实修改作为 `model_patch`。这样规避：

- agent 输出 markdown fenced diff
- diff 被 stdout 截断
- agent 声称已修改但实际没改
- SSE/JSON 格式变化

### 4.2 `cwd=<repo root>`

每个 instance 的 prompt 末尾明确告诉 agent：

> 1. 在 `repo_path` 探索仓库。
> 2. 直接修改源文件。
> 3. 不要 commit / push / reset。
> 4. 不要改 benchmark scaffolding 文件（如 `.swebench-baseline`）。
> 5. unified diff 必须包含 `@@` hunk 头里的行号，否则官方 patch 会 apply 失败。

### 4.3 `.swebench-baseline` 标记文件

每个 workspace 写一个仅含 `instance_id`/`base_commit` 的小文件。如果未来想
对比"agent 修改"与"初始 scaffold"，用它当 anchor；它不会被 harness 视作 source
修改（因为它在 git 之外），不影响 `git diff` 的语义。

### 4.4 不改 OpenLoomi

- **不**修改 `apps/web/app/api/native/agent/route.ts`
- **不**修改 OpenLoomi 任何 runtime
- **不**修改现有 JobBench runner / judge
- **不**修改 OpenLoomi 现有 benchmark package

新增内容只有 3 个文件 + 4 个目录：

- `eval/run_benchmark_openloomi.py`
- `eval/run_swebench.sh`
- `eval/run_swebench_harness.sh`

---

## 5. 故障排查

| 现象 | 原因 | 处理 |
|---|---|---|
| `service_unavailable :3515` | dev server 没起 / 长时间运行后被 kill | 重启 `pnpm tauri:dev`；runner 端已自动跳过已成功的 instance |
| `openloomi-ctl not found` | `OPENLOOMI_CTL` 未设或路径错 | 重新指向 `C:\Users\<you>\AppData\Local\Programs\openloomi\cli\openloomi-ctl.exe` |
| `failed to load saved auth token` | CLI 0.8.8 误把 JWT 当 Base64 解码 | 显式 `export OPENLOOMI_AUTH_TOKEN=...` |
| 全部 instance 跑完但 `model_patch` 为空 | agent 在错误目录 / 没真正改文件 | 看 `trajectories/.../attempt_*.json` 的 stdout / stderr |
| Docker 拉镜像超时 | 网络或 GHCR 未登录 | `docker login ghcr.io`；或加 `HF_HOME` 复用缓存 |
| patch apply 失败 | diff 缺 `@@` 行号或 base_commit 漂移 | 在 prompt 强调"必须包含行号"；runner 已自动 checkout 到 `base_commit` |
| 磁盘满 | repo cache + Docker cache 堆积 | `docker system prune -a`；定期清理 `D:\swebench-work\workspaces\` |
| harness 单实例超时 | 测试本身慢 | 调高 `--timeout`；或拆小 `--max-workers` |

---

## 6. 与 JobBench official runner 的差异

| 维度 | JobBench | SWE-bench Verified |
|---|---|---|
| 任务输入 | 任务目录 + 文字指令 | `instance_id` / `repo` / `base_commit` / `problem_statement` |
| agent 工作区 | 临时目录 + 任务素材 | 真实 Git 仓库 checkout 到 base_commit |
| agent 产物 | DOCX/XLSX/PDF 等文件 | unified diff patch |
| 评测 | 官方 LLM-as-judge 打 rubric 分 | 官方 Docker harness 跑 FAIL_TO_PASS + PASS_TO_PASS |
| 评价量级 | 65 个 main 任务 | 500 个实例 |
| 隔离要求 | 临时目录 | 仓库 checkout + Docker 容器 |
| 单任务耗时 | 数十分钟到数小时 | 5-30 分钟为主 |
| 全量耗时 | 数十小时 | 数十到一百多小时 |

---

## 7. 跑批时序

```
[1] pnpm tauri:dev                                 # 终端 A：dev server
[2] Set env vars                                   # 终端 B
[3] pip install -e .                               # 一次性
[4] validate-gold smoke test                       # 一次性
[5] run_swebench.sh --instance-id ...              # 链路验证
[6] run_swebench.sh --limit 20 ...                 # 抽检
[7] run_swebench.sh                                # 全量 500
[8] run_swebench_harness.sh                        # 官方 harness
[9] 读 evaluation_results/openloomi-verified.json  # 写报告
```

阶段 [7] 和 [8] 可以分开多天做，predictions.jsonl 永远在断点续跑。

---

## 8. 数据来源 / 引用

- **数据集**：[SWE-bench/SWE-bench_Verified](https://huggingface.co/datasets/SWE-bench/SWE-bench_Verified)（500 instances, test split）
- **官方 harness**：[SWE-bench/SWE-bench](https://github.com/SWE-bench/SWE-bench)
- **方法学**：
  - Jimenez et al., *SWE-bench: Can Language Models Resolve Real-World GitHub Issues?* (ICLR 2024 Oral)
  - OpenAI, *Introducing SWE-bench Verified* (2024-08-13)
- **基线参考**：swebench.com Verified leaderboard
