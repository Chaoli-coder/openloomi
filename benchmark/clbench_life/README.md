# CL-bench-Life Benchmark

CL-bench-Life 是腾讯发布的 [Context Learning Benchmark](https://clbench.com/) 子集，用于评估模型在日常生活上下文上的学习能力。包含 **405 个任务 / 5348 个 rubric**，覆盖 3 个类别（Communication & Social Interactions / Daily Life Planning / Task Assistance）。

数据集来源：[tencent/CL-bench-Life (HuggingFace)](https://huggingface.co/datasets/tencent/CL-bench-Life)。

论文：[CL-bench Life: Can Language Models Learn from Real-Life Context?](https://arxiv.org/html/2604.27043v1)

## 与 `benchmark/clbench` 的关系

本目录是一个独立可运行包，内部拷贝自 `benchmark/clbench/src/*`。两者共享同一套：
- evaluator 逻辑（`CLBenchLifeEvaluator` 用 `reasoning_effort = "high"`）
- checkpoint / resume 机制
- OpenLoomi `/api/native/agent` 调用方式
- OpenRouter rubric 评判流程

区别仅在于：
- 包名 `@openloomi/benchmark-clbench-life`
- 默认 checkpoint 目录子目录名为 `clbench-life`
- 数据集是 `clbench-life.jsonl`，只跑 life 子集

如果只想跑 life、不想留两套副本，也可以直接在 `benchmark/clbench` 目录里执行：

```bash
pnpm benchmark -- --dataset dataset/clbench-life.jsonl --benchmark clbench-life
```

## Setup

```bash
cd benchmark/clbench_life
pnpm install
```

## 配置环境变量

复制 `.env.example` 为 `.env` 并填入 OpenRouter API key（用于 rubric 评判）：

```bash
cp .env.example .env
# 然后编辑 .env
```

## 运行

```bash
# 完整跑 CL-bench-Life（405 条，high reasoning effort）
pnpm benchmark -- --dataset dataset/clbench-life.jsonl --benchmark clbench-life --output results/clbench_life_result.json

# 烟囱测试：只跑前 5 条
pnpm benchmark -- --dataset dataset/clbench-life.jsonl --benchmark clbench-life --quick 5

# 指定 OpenLoomi 端口（默认自动发现 3515）
pnpm benchmark -- --dataset dataset/clbench-life.jsonl --benchmark clbench-life --port 3515

# 续跑（默认开启，会跳过已 checkpoint 的任务）
pnpm benchmark -- --dataset dataset/clbench-life.jsonl --benchmark clbench-life --resume
```

## Checkpoint 位置

默认 checkpoint 写到：

```
<package_root>/checkpoints/clbench-life/
```

可通过环境变量 `CLBENCH_CHECKPOINT_DIR` 改写到自定义路径，例如：

```powershell
# PowerShell
$env:CLBENCH_CHECKPOINT_DIR = "D:\openloomi_val_results\clbench_life\checkpoints\clbench-life"
pnpm benchmark -- --dataset dataset/clbench-life.jsonl --benchmark clbench-life
```

## CLI 选项

| 选项               | 说明                                |
| ------------------ | ----------------------------------- |
| `--dataset <path>` | JSONL 数据集路径（必填）            |
| `--benchmark`      | 必须填 `clbench-life`               |
| `--quick <n>`      | 只跑前 N 条                         |
| `--port <n>`       | OpenLoomi API 端口                  |
| `--token <path>`   | 自定义 auth token 路径              |
| `--output <path>`  | 把最终结果 JSON 写到指定路径        |
| `--resume`         | 开启 checkpoint 续跑（默认开启）    |
| `--no-resume`      | 关闭续跑，重跑全部                  |

## Requirements

- Node.js 18+
- pnpm
- OpenLoomi server 运行在 3515 端口（可改）
- OpenRouter API key（rubric 评判需要 GPT-5.1 judge）