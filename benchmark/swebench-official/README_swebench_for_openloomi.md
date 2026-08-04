# SWE-bench Verified on OpenLoomi — End-to-End Guide

This directory hosts the end-to-end evaluation pipeline that runs the OpenLoomi desktop agent against **SWE-bench Verified**. It follows the minimal-change principle of the official JobBench runner: it reuses OpenLoomi's existing `openloomi-ctl --one-shot` invocation, **does not** modify any existing benchmark or OpenLoomi internals, **does not** write its own tests, **does not** write its own judge, and **completely** defers scoring to the official Princeton Docker harness.

---

## 0. Directory Layout

```
swebench-official/
├── eval/
│   ├── run_benchmark_openloomi.py   # Core Python runner (dispatches the agent)
│   ├── run_swebench.sh              # Launcher
│   └── run_swebench_harness.sh      # Invokes the official Docker harness
├── predictions/
│   └── openloomi-verified.jsonl     # Agent output (one record per instance)
├── trajectories/openloomi-verified/
│   └── <instance_id>/attempt_*.json # stdout / stderr / exit_code per attempt
├── logs/                            # Launcher and runner reports
└── README_swebench_for_openloomi.md # This document
```

Large caches (the 12 cloned upstream repos, per-instance workspaces, and Docker images) should live under `D:\swebench-work\` — **not** inside `swebench-official/`, otherwise the repository will balloon in size.

---

## 1. One-time Preparation

### 1.1 System Requirements

| Item | Requirement |
| --- | --- |
| Python | ≥ 3.10 |
| Docker Desktop | Installed and running; at least 120 GB of free disk and 16 GB of RAM recommended |
| Node.js | ≥ 22 (required by `openloomi-ctl`) |
| OpenLoomi Desktop | ≥ 0.8.8, signed in, with the token written to `~/.openloomi/token` |
| Working disk | `D:\swebench-work\` (the path can be changed, but it must be a separate large disk) |

### 1.2 Clone and Install the Official Harness

```powershell
git clone https://github.com/SWE-bench/SWE-bench.git `
  D:\openloomi3\openloomi\benchmark\SWE-Bench-CL

cd D:\openloomi3\openloomi\benchmark\SWE-Bench-CL
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -e .
```

The dataset (`SWE-bench_Verified`, 500 test instances) is already present at `D:\openloomi3\openloomi\benchmark\SWE-Bench-CL\datasets\SWE-bench_Verified\`; no further download is required.

### 1.3 Smoke Test (Verify the Harness Itself Runs)

```powershell
python -m swebench.harness.run_evaluation `
  --predictions_path gold `
  --max_workers 1 `
  --instance_ids sympy__sympy-20590 `
  --run_id validate-gold
```

Expected outcome: `evaluation_results/validate-gold.json` reports `sympy__sympy-20590` as resolved.

### 1.4 Start the OpenLoomi Dev Server

In a separate terminal:

```powershell
cd D:\openloomi3\openloomi
pnpm tauri:dev
```

Wait until `Ready on http://localhost:3515` appears.

### 1.5 Prepare the OpenLoomi Invocation Environment Variables

```powershell
$env:OPENLOOMI_API_URL    = "http://127.0.0.1:3515"
$env:OPENLOOMI_CLI_DIRECT = "0"
$env:OPENLOOMI_AUTH_TOKEN = (Get-Content "$HOME\.openloomi\token" -Raw).Trim()
$env:OPENLOOMI_CTL        = "C:\Users\<you>\AppData\Local\Programs\openloomi\cli\openloomi-ctl.exe"
```

> `OPENLOOMI_CLI_DIRECT=0` forces `openloomi-ctl` to call the live dev server through the HTTP API rather than running the in-process native runner bundled inside the CLI.

---

## 2. Phase One — Let OpenLoomi Generate Predictions

### 2.1 Single-Instance Smoke Test

```powershell
cd D:\openloomi3\openloomi\benchmark\swebench-official
.\eval\run_swebench.sh --instance-id django__django-11099 --timeout 1800
```

Expected artifacts:

- `predictions\openloomi-verified.jsonl` gains a new line:
  ```json
  {"instance_id":"django__django-11099","model_name_or_path":"openloomi-verified","model_patch":"diff --git ..."}
  ```
- `trajectories\openloomi-verified\django__django-11099\attempt_*.json` is written.
- `D:\swebench-work\workspaces\django__django-11099\src\` contains real modifications.

### 2.2 Spot Check (Small Batch)

```powershell
cd D:\openloomi3\openloomi\benchmark\swebench-official
.\eval\run_swebench.sh --limit 20 --timeout 1800 `
  --provider claude --model claude-sonnet-4-6
```

### 2.3 Full 500-Instance Run

```powershell
cd D:\openloomi3\openloomi\benchmark\swebench-official
.\eval\run_swebench.sh `
  --provider claude `
  --model claude-sonnet-4-6 `
  --max-concurrent 1 `
  --timeout 3600
```

**Important parameter notes:**

- `--max-concurrent 1`: runs serially by default. Each SWE-bench Verified instance involves cloning a repo, installing dependencies, and running tests, so high concurrency will overwhelm the dev server. Raise it with caution.
- `--timeout 3600`: a one-hour per-instance cap. Most Verified instances finish in 5–30 minutes, but long-tail tasks exist.
- The runner is **resumable**: any `instance_id` already written to `predictions/openloomi-verified.jsonl` is skipped automatically. Pass `--force` to re-run.
- Per-instance predictions are persisted one JSON object per line in `predictions/openloomi-verified.jsonl`:
  ```json
  {"instance_id":"...","model_name_or_path":"openloomi-verified","model_patch":"diff --git ..."}
  ```
  This is the format expected by `swebench.harness.run_evaluation --predictions_path`.

### 2.4 Other Common Filters

```powershell
# Run only Django
.\eval\run_swebench.sh --repo django/django

# Run a specific list of instances
.\eval\run_swebench.sh --instance-id django__django-11099 --instance-id sympy__sympy-20590

# Cap at 50 for a smoke test
.\eval\run_swebench.sh --limit 50

# Force a re-run (overwrite an existing prediction)
.\eval\run_swebench.sh --force --instance-id django__django-11099
```

### 2.5 Output Locations

| Path | Contents |
| --- | --- |
| `predictions/openloomi-verified.jsonl` | The agent's complete set of patches; the harness reads this file directly |
| `trajectories/openloomi-verified/<instance_id>/attempt_*.json` | Command, stdout, stderr, exit code, and duration for each attempt |
| `logs/openloomi_verified_terminal_<timestamp>.log` | Full terminal transcript of the launcher |
| `logs/openloomi_verified_<model>_<timestamp>.json` | Runner summary: per-instance status and counts |

---

## 3. Phase Two — Score with the Official Docker Harness

Once Phase One has finished, hand the predictions over to the official Princeton harness:

```powershell
cd D:\openloomi3\openloomi\benchmark\swebench-official
.\eval\run_swebench_harness.sh `
  --swe-bench-home D:\openloomi3\openloomi\benchmark\SWE-Bench-CL `
  --predictions .\predictions\openloomi-verified.jsonl `
  --run-id openloomi-verified `
  --max-workers 1
```

Or run it manually:

```powershell
cd D:\openloomi3\openloomi\benchmark\SWE-Bench-CL
.\.venv\Scripts\Activate.ps1

python -m swebench.harness.run_evaluation `
  --dataset_name princeton-nlp/SWE-bench_Verified `
  --predictions_path D:\openloomi3\openloomi\benchmark\swebench-official\predictions\openloomi-verified.jsonl `
  --max_workers 1 `
  --run_id openloomi-verified
```

The harness will:

1. Pull or build the Docker image for each instance (base commit + dependencies).
2. Apply `model_patch` together with `test_patch`.
3. Execute `FAIL_TO_PASS` (must switch from failing to passing) and `PASS_TO_PASS` (must remain passing).
4. Write `logs/run_evaluation/openloomi-verified/...` and `evaluation_results/openloomi-verified.json`.

**The final metric is the `resolved_rate` value in `evaluation_results/openloomi-verified.json`.**

---

## 4. Key Design Notes

### 4.1 Do Not Use the Text Answer Directly

The stdout of `openloomi-ctl --one-shot` is conversation and tool-call JSON, **not** the input SWE-bench evaluates. After the agent exits, the runner executes `git diff --binary --no-color` in the repository root and uses the actual on-disk change as `model_patch`. This avoids:

- The agent emitting a markdown-fenced diff.
- The diff being truncated by stdout.
- The agent claiming to have edited files but not actually editing them.
- Variations in SSE/JSON formatting.

### 4.2 `cwd = <repo root>`

The prompt for each instance explicitly tells the agent at the end:

> 1. Explore the repository at `repo_path`.
> 2. Modify the source files directly.
> 3. Do not commit, push, or reset.
> 4. Do not touch benchmark scaffolding files (e.g. `.swebench-baseline`).
> 5. The unified diff must include the `@@` hunk header line numbers; otherwise the official patch will fail to apply.

### 4.3 The `.swebench-baseline` Marker File

Each workspace writes a small file containing only `instance_id` / `base_commit`. If you later want to compare "what the agent edited" against "the initial scaffold", use this as the anchor; it is treated by the harness as outside the source tree and does not affect the semantics of `git diff`.

### 4.4 No OpenLoomi Modifications

- **No** modifications to `apps/web/app/api/native/agent/route.ts`.
- **No** modifications to any OpenLoomi runtime.
- **No** modifications to the existing JobBench runner / judge.
- **No** modifications to any existing OpenLoomi benchmark package.

The only new artefacts are three files plus four directories:

- `eval/run_benchmark_openloomi.py`
- `eval/run_swebench.sh`
- `eval/run_swebench_harness.sh`

---

## 5. Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `service_unavailable :3515` | The dev server is not running, or it was killed after a long run | Restart `pnpm tauri:dev`; the runner automatically skips instances that already succeeded |
| `openloomi-ctl not found` | `OPENLOOMI_CTL` is unset or points to the wrong path | Reset it to `C:\Users\<you>\AppData\Local\Programs\openloomi\cli\openloomi-ctl.exe` |
| `failed to load saved auth token` | CLI 0.8.8 misinterprets the JWT as Base64 | Explicitly `export OPENLOOMI_AUTH_TOKEN=...` |
| All instances ran but `model_patch` is empty | The agent modified the wrong directory or did not actually edit files | Inspect `trajectories/.../attempt_*.json` for stdout / stderr |
| Docker image pull timed out | Network issue or you have not logged in to GHCR | `docker login ghcr.io`; alternatively set `HF_HOME` to reuse the cache |
| Patch failed to apply | The diff is missing `@@` line numbers or `base_commit` drifted | Reinforce the "must include line numbers" rule in the prompt; the runner already checks out `base_commit` automatically |
| Disk full | Repo cache and Docker cache piling up | `docker system prune -a`; periodically clean `D:\swebench-work\workspaces\` |
| Harness timed out on a single instance | The tests themselves are slow | Raise `--timeout`; or reduce `--max-workers` |

---

## 6. Differences from the Official JobBench Runner

| Dimension | JobBench | SWE-bench Verified |
| --- | --- | --- |
| Task input | A task directory plus a written instruction | `instance_id` / `repo` / `base_commit` / `problem_statement` |
| Agent workspace | A temporary directory with task materials | A real Git repository checked out at `base_commit` |
| Agent output | DOCX / XLSX / PDF files, etc. | A unified diff patch |
| Evaluation | Official LLM-as-judge scoring against rubrics | Official Docker harness running FAIL_TO_PASS plus PASS_TO_PASS |
| Scale | 65 main tasks | 500 instances |
| Isolation requirements | Temporary directory | Repository checkout plus Docker container |
| Per-task duration | Tens of minutes to a few hours | Mostly 5–30 minutes |
| End-to-end duration | Tens of hours | Tens to about a hundred hours |

---

## 7. Batch Run Sequence

```
[1] pnpm tauri:dev                                 # Terminal A: dev server
[2] Set env vars                                   # Terminal B
[3] pip install -e .                               # One-time
[4] validate-gold smoke test                       # One-time
[5] run_swebench.sh --instance-id ...              # Path validation
[6] run_swebench.sh --limit 20 ...                 # Spot check
[7] run_swebench.sh                                # Full 500 instances
[8] run_swebench_harness.sh                        # Official harness
[9] Read evaluation_results/openloomi-verified.json  # Write the report
```

Phases [7] and [8] can be split across multiple days; `predictions.jsonl` is always resumable.

---

## 8. Sources / Citations

- **Dataset**: [SWE-bench/SWE-bench_Verified](https://huggingface.co/datasets/SWE-bench/SWE-bench_Verified) (500 instances, test split)
- **Official harness**: [SWE-bench/SWE-bench](https://github.com/SWE-bench/SWE-bench)
- **Methodology**:
  - Jimenez et al., *SWE-bench: Can Language Models Resolve Real-World GitHub Issues?* (ICLR 2024 Oral)
  - OpenAI, *Introducing SWE-bench Verified* (2024-08-13)
- **Baseline reference**: swebench.com Verified leaderboard
