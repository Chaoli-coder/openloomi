# GDPval-AA v2（OpenLoomi 复现）

本目录为 OpenLoomi 复现 **GDPval-AA v2**（Artificial Analysis 对 OpenAI GDPval 的 Elo 评分评测框架）所需的所有本地资源，**已整合为一个入口**。

## 目录结构

```
GDPval-AA v2/
├── README.md                                本文档
├── dataset/                                 数据集 + 下载脚本
│   ├── download_gdpval.py                   下载 openai/gdpval 官方 gold 子集（220 任务）
│   ├── fetch_reference_files.py             批量下载每个任务的 reference files
│   ├── gdpval_gold.jsonl                    已下载的 220 个任务
│   └── reference_files/                     每任务一个子目录，存预下载的 reference
│       └── reference_files_index.json
├── harness/
│   └── Stirrup/                             AA 官方 agent harness（git clone）
├── grader/
│   └── GDPVal_EVal/                         botschen 复刻的 Bradley-Terry Elo + pairwise grader
├── leaderboard/                             AA 公开排行榜快照（185 个模型）
├── docs/                                    论文 PDF
└── openloomi-runner/                        ← 用 OpenLoomi 当 harness 跑 v2 测评
    ├── README.md                            runner 详细说明
    ├── readme_gdpvalAAV2_for_openloomi.md    端到端使用说明
    ├── run_gdpval_aa_v2.sh                  一键工作流
    ├── package.json                         @openloomi/benchmark-gdpval-aa-v2
    ├── src/                                 TypeScript 源码
    ├── scripts/                             evaluate.py / prompt_builder.py / smoke test
    └── results/                             跑出来后的产物（per-task run JSON、artifacts、submissions）
```

## 三种跑法（选一个）

### 方案 A：用 OpenLoomi runner（推荐 · 唯一在 v2 规格上对齐的）

`openloomi-runner/` 严格按 v2 规格实现：官方 system + task prompt、reference files 通过 `fileAttachments` 注入、6 工具裁剪到 4 个、250 turns 上限、`<<<FINISH>>>` / `<<<ABANDON>>>` 文本协议替代 OpenLoomi 没有的 `finish` / `abandon_task_finish` 工具。

```powershell
cd D:\openloomi3\openloomi\benchmark\GDPval-AA v2\openloomi-runner
bash run_gdpval_aa_v2.sh --quick 3
```

详细使用见 [openloomi-runner/README.md](file:///D:/openloomi3/openloomi/benchmark/GDPval-AA%20v2/openloomi-runner/README.md) 和 [readme_gdpvalAAV2_for_openloomi.md](file:///D:/openloomi3/openloomi/benchmark/GDPval-AA%20v2/openloomi-runner/readme_gdpvalAAV2_for_openloomi.md)。

### 方案 B：用 OpenLoomi 已有 `benchmark/gdpval/` 跑（仅 sanity check）

只记录响应文本，**不算官方评分**。

```powershell
cd D:\openloomi
pnpm --filter @openloomi/benchmark-gdpval benchmark `
  --dataset "D:\openloomi3\openloomi\benchmark\GDPval-AA v2\dataset\gdpval_gold.jsonl" `
  --output results/gdpval_aa_v2_result.json --no-resume
```

### 方案 C：跑官方 Stirrup harness（最贴近 AA 原始方法）

```powershell
cd "D:\openloomi3\openloomi\benchmark\GDPval-AA v2\harness\Stirrup"
pip install -e ".[all]"
```

## Elo 评分（任一方案跑完后）

```powershell
cd "D:\openloomi3\openloomi\benchmark\GDPval-AA v2\grader\GDPVal_EVal"
pip install -e ".[dev]"
$env:GEMINI_API_KEY = "..."

python -m gdpval.grading.pairwise_grader `
  --task-set "D:\openloomi3\openloomi\benchmark\GDPval-AA v2\dataset\gdpval_gold.jsonl" `
  --submission-a "D:\openloomi3\openloomi\benchmark\GDPval-AA v2\openloomi-runner\results\submissions\openloomi_claude-sonnet-4-5.jsonl" `
  --submission-b "D:\openloomi3\openloomi\benchmark\GDPval-AA v2\openloomi-runner\results\submissions\openloomi_stirrup_claude-sonnet-4-5.jsonl" `
  --out matches.jsonl

# v2 anchor = human expert deliverables = 1000（v1 才是 gpt-5.1 = 1000）
python -m gdpval.elo.bradley_terry --matches matches.jsonl --anchor 1000
```

## 排行榜快速对照（截至 2026-08-04）

| Rank | Model | Elo |
|---|---|---|
| 1 | Claude Opus 5 (Adaptive Reasoning, Max Effort) | 1852 |
| 2 | Claude Opus 5 (Adaptive Reasoning, Xhigh Effort) | 1819 |
| 3 | Claude Fable 5 | 1743 |
| 4 | Claude Opus 5 (Adaptive Reasoning, High Effort) | 1735 |
| 5 | GPT-5.6 Sol (max) | 1730 |
| 6 | Kimi K3 (max) | 1685 |
| 7 | GPT-5.6 Sol (xhigh) | 1683 |
| 8 | Claude Opus 5 (Adaptive Reasoning, Medium Effort) | 1628 |
| 9 | GPT-5.6 Sol (high) | 1623 |
| 10 | Claude Sonnet 5 (Adaptive Reasoning, Max Effort) | 1600 |

`MiniMax-M3` 当前排第 33 位（1389 Elo，CI ±15）。

完整 185 行见 `leaderboard/gdpval_aa_v2_leaderboard.csv` / `.json`。

## 数据来源

- 论文：<https://arxiv.org/abs/2510.04374> (Patwardhan et al., 2025)
- 数据集：<https://huggingface.co/datasets/openai/gdpval>
- Agent harness：<https://github.com/ArtificialAnalysis/Stirrup>
- 评分框架参考：<https://github.com/botschen/GDPVal_EVal>
- 排行榜：<https://artificialanalysis.ai/evaluations/gdpval-aa#gdpval-aa-leaderboard-table>
- 方法学：<https://artificialanalysis.ai/methodology/intelligence-benchmarking#gdpval-aa>

## 注意事项

- 220 个任务里有不少需要 PDF / Word / Excel / PPT 等真实交付物。仅用纯文本响应做"答对率"统计意义有限。
- 官方主指标是 **head-to-head 专家对比 / Elo**，不是简单的 pass@k。
- 模型提交物请保留原文件路径与文件名，方便后续 pairwise grading 用 `view_image` 工具查看图片/图表。
- v2 配对评分用 3-judge panel 锚定到人类专家交付物 1000（v1 是单 judge + GPT-5.1 = 1000）；`GDPVal_EVal` 只复刻了 v1，需要改 Elo 代码才能对齐 v2 锚点。
