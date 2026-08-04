# CL-bench-Life 续跑脚本

`scripts/` 目录里提供了两个等价的"清理失败 checkpoint + 续跑"脚本，专用于 **CL-bench-Life**（405 条日常生活任务，high reasoning effort）：

| 脚本 | 平台 | 解释器 |
|---|---|---|
| [`resume_clbench_life.sh`](file:///d:/openloomi3/openloomi/benchmark/clbench_life/scripts/resume_clbench_life.sh) | Linux / macOS / WSL / Git Bash | bash + python |
| [`resume_clbench_life.ps1`](file:///d:/openloomi3/openloomi/benchmark/clbench_life/scripts/resume_clbench_life.ps1) | Windows PowerShell | PowerShell 5+ |

两个脚本行为完全一致：

1. 扫描 `$CHECKPOINT_DIR`（默认 `D:\openloomi_val_results\clbench_life\checkpoints\clbench-life`）下所有 `.json` checkpoint
2. 对每个 checkpoint 用 JSON 解析后看 `response` 字段是否以 `Error:` 或 `ERROR:` 开头（agent API 调用失败、timeout、orchestrator 数据错误等**不可抗力失败**）
3. 把这些失败 checkpoint **移动**到一个时间戳备份目录 `<parent>/_trash_resumed_<YYYYMMDD_HHMMSS>/`（不删除，留底）
4. 调用 `pnpm benchmark -- ...` 启动续跑——已 checkpoint 的有效任务被 resume 复用，剩下未完成的会被重新评估

> 📝 **关于"不可抗力"**：脚本**只**清理 response 字段以 `Error:` / `ERROR:` 开头的 checkpoint。这些通常代表：
> - OpenLoomi agent API 调用失败（`Error: fetch failed`）
> - 单条任务超时（`Error: The operation was aborted due to timeout`）
> - OpenLoomi 内部被中止（`Error: terminated`）
> - Orchestrator 返回无效数据（`ERROR: ...`）
>
> 其它情况（正常 response 但答错、rubric 评判 JSON 解析失败）**不会被清理**——保留下来作为最终结果的一部分。

## 使用方法

### Windows PowerShell

```powershell
cd D:\openloomi3\openloomi\benchmark\clbench_life
powershell -ExecutionPolicy Bypass -File scripts\resume_clbench_life.ps1
```

### Git Bash / WSL

```bash
cd /d/openloomi3/openloomi/benchmark/clbench_life
bash scripts/resume_clbench_life.sh
```

## 环境变量覆盖

所有路径都可以用环境变量覆盖，默认值见下表：

| 变量 | 默认值（clbench-life） | 含义 |
|---|---|---|
| `CHECKPOINT_DIR` | `D:\openloomi_val_results\clbench_life\checkpoints\clbench-life` | checkpoint 目录 |
| `DATASET` | `<package>/dataset/clbench-life.jsonl` | JSONL 数据集路径 |
| `BENCHMARK_TYPE` | `clbench-life` | benchmark 类型 |
| `OUTPUT` | `D:\openloomi_val_results\clbench_life\results\clbench_life_result_resumed.json` | 汇总结果输出路径 |

## 失败 checkpoint 识别规则

脚本判断"失败"的标准**严格**匹配 [`evaluator.ts#L36-42`](file:///d:/openloomi3/openloomi/benchmark/clbench_life/src/evaluator.ts#L36-L42)：

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

**正常响应中提到 "Error" 但不是错误的情况不会被误判**——只匹配字段值开头。

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

确认 OpenLoomi 跑过至少一次，checkpoints 应该写到 `D:\openloomi_val_results\clbench_life\checkpoints\clbench-life`。如果路径不一样，覆盖 `CHECKPOINT_DIR` 环境变量。

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
$env:CLBENCH_CHECKPOINT_DIR = "D:\openloomi_val_results\clbench_life\checkpoints\clbench-life"
cd D:\openloomi3\openloomi\benchmark\clbench_life
pnpm benchmark -- `
  --dataset dataset\clbench-life.jsonl `
  --benchmark clbench-life `
  --output D:\openloomi_val_results\clbench_life\results\clbench_life_result.json
```

中断或失败后，从 `pnpm benchmark` 这一行开始重新跑——`--resume`（默认开启）会自动跳过已完成 checkpoint。

如果想"先清掉失败 checkpoint 再续跑"，就用本目录的 `resume_clbench_life.ps1` / `resume_clbench_life.sh`。

## Requirements

- Node.js 18+
- pnpm
- Python 3（仅 .sh 脚本需要）
- OpenLoomi server 运行在 3515 端口
- OpenRouter API key（rubric 评判需要）

## 相关文档

- [`clbench/scripts/README.md`](file:///d:/openloomi3/openloomi/benchmark/clbench/scripts/README.md) —— CL-bench（1899 条专业任务，low reasoning effort）版本的脚本
- [`D:\openloomi3\openloomi\benchmark\clbench_life\README.md`](file:///d:/openloomi3/openloomi/benchmark/clbench_life/README.md) —— clbench_life 包说明