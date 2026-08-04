# CL-bench 续跑脚本

`scripts/` 目录里提供了两个等价的"清理失败 checkpoint + 续跑"脚本：

| 脚本 | 平台 | 解释器 |
|---|---|---|
| [`resume_clbench.sh`](file:///d:/openloomi3/openloomi/benchmark/clbench/scripts/resume_clbench.sh) | Linux / macOS / WSL / Git Bash | bash + python（已检测） |
| [`resume_clbench.ps1`](file:///d:/openloomi3/openloomi/benchmark/clbench/scripts/resume_clbench.ps1) | Windows PowerShell | PowerShell 5+ |

两个脚本行为完全一致：

1. 扫描 `$CHECKPOINT_DIR`（默认 `D:\openloomi_val_results\clbench\checkpoints\clbench`）下所有 `.json` checkpoint
2. 对每个 checkpoint 用 JSON 解析后看 `response` 字段是否以 `Error:` 或 `ERROR:` 开头（agent API 调用失败、timeout、terminated 等不可抗力失败）
3. 把这些失败 checkpoint **移动**到一个时间戳备份目录 `<parent>/_trash_resumed_<YYYYMMDD_HHMMSS>/`（不删除，留底）
4. 调用 `pnpm benchmark -- ...` 启动续跑——已 checkpoint 的 44 个有效任务被 resume 复用，剩下 994 条会被重新评估

## 使用方法

### Windows PowerShell

```powershell
cd D:\openloomi3\openloomi\benchmark\clbench
powershell -ExecutionPolicy Bypass -File scripts\resume_clbench.ps1
```

### Git Bash / WSL

```bash
cd /d/openloomi3/openloomi/benchmark/clbench
bash scripts/resume_clbench.sh
```

## 环境变量覆盖

所有路径都可以用环境变量覆盖，默认值见下表：

| 变量 | 默认值（clbench） | 含义 |
|---|---|---|
| `CHECKPOINT_DIR` | `D:\openloomi_val_results\clbench\checkpoints\clbench` | checkpoint 目录 |
| `DATASET` | `<package>/dataset/clbench.jsonl` | JSONL 数据集路径 |
| `BENCHMARK_TYPE` | `clbench` | benchmark 类型 |
| `OUTPUT` | `D:\openloomi_val_results\clbench\results\clbench_result_resumed.json` | 汇总结果输出路径 |

> ⚠️ **clbench-life 用法**：把上面 4 个变量改成 life 的路径再跑一次即可。脚本本身不区分 clbench / clbench-life，只看路径。

clbench-life 的等价环境变量示例：

```bash
# Git Bash / WSL
export CHECKPOINT_DIR=D:/openloomi_val_results/clbench_life/checkpoints/clbench-life
export DATASET=/d/openloomi3/openloomi/benchmark/clbench_life/dataset/clbench-life.jsonl
export BENCHMARK_TYPE=clbench-life
export OUTPUT=D:/openloomi_val_results/clbench_life/results/clbench_life_result_resumed.json
bash scripts/resume_clbench.sh
```

```powershell
# PowerShell
$env:CHECKPOINT_DIR = "D:\openloomi_val_results\clbench_life\checkpoints\clbench-life"
$env:DATASET        = "D:\openloomi3\openloomi\benchmark\clbench_life\dataset\clbench-life.jsonl"
$env:BENCHMARK_TYPE = "clbench-life"
$env:OUTPUT         = "D:\openloomi_val_results\clbench_life\results\clbench_life_result_resumed.json"
powershell -ExecutionPolicy Bypass -File scripts\resume_clbench.ps1
```

## 失败 checkpoint 识别规则

脚本判断"失败"的标准**严格**匹配 [`evaluator.ts#L36-42`](file:///d:/openloomi3/openloomi/benchmark/clbench/src/evaluator.ts#L36-L42)：

```ts
function isErrorResponse(response: string): boolean {
  return (
    response.startsWith("Error:") ||
    response.includes("Failed to authenticate") ||
    response.includes("API Error")
  );
}
```

即只有以下三种前缀/子串的 checkpoint 会被移动：

- `Error:`（含 `Error: fetch failed`、`Error: timeout`、`Error: terminated` 等）
- `Failed to authenticate`（理论上不应出现，但兜底）
- `API Error`

**正常响应中提到 "Error" 但不是错误的情况不会被误判**——只匹配字段值。

## 备份目录

每次跑都会创建一个新的备份目录：

```
<checkpoint_dir>/../_trash_resumed_<YYYYMMDD_HHMMSS>/
```

里面是所有被移动的失败 checkpoint。**不要主动删除**——如果续跑后还有问题，可以从备份目录把对应 task_id 的文件放回去重跑。

## 故障排查

### 提示 "pnpm not found in PATH"

需要先安装 pnpm：

```bash
npm install -g pnpm
```

### 提示 "checkpoint dir not found"

确认 OpenLoomi 跑过至少一次，checkpoints 应该写到 `D:\openloomi_val_results\clbench\checkpoints\clbench`（或 `clbench_life/checkpoints/clbench-life`）。如果路径不一样，覆盖 `CHECKPOINT_DIR` 环境变量。

### 跑了脚本后 `pnpm benchmark` 立即退出

通常是 OpenLoomi server 没起或不在 3515。脚本不会去启动 server，需要你提前确认：

```powershell
Test-NetConnection -ComputerName 127.0.0.1 -Port 3515
```

### 续跑后又出现新的 `Error: fetch failed`

这是 OpenLoomi server 端的问题（端口死了、provider 限流、auth token 失效等），与脚本无关。检查 server 日志或重启 server 后重跑脚本。

## 完整跑批流程（推荐）

第一次跑：

```powershell
$env:CLBENCH_CHECKPOINT_DIR = "D:\openloomi_val_results\clbench\checkpoints\clbench"
cd D:\openloomi3\openloomi\benchmark\clbench
pnpm benchmark -- --dataset dataset\clbench.jsonl --benchmark clbench --output results\clbench_result.json
```

中断或失败后，从 `pnpm benchmark` 这一行开始重新跑——`--resume`（默认开启）会自动跳过已完成 checkpoint。

如果想"先清掉失败 checkpoint 再续跑"，就用本目录的 `resume_clbench.ps1` / `resume_clbench.sh`。

## Requirements

- Node.js 18+
- pnpm
- Python 3（仅 .sh 脚本需要）
- OpenLoomi server 运行在 3515 端口
- OpenRouter API key（rubric 评判需要）