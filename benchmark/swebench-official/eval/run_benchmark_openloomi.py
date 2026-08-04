#!/usr/bin/env python3
"""Run SWE-bench Verified with OpenLoomi's one-shot CLI.

Pipeline per instance:
  1. Clone repo at base_commit into a fresh workspace.
  2. Build a prompt from the instance's problem_statement.
  3. Launch `openloomi-ctl --one-shot --stdin --json` with cwd=repo.
  4. Run `git diff --binary` in the repo to extract model_patch.
  5. Append {instance_id, model_name_or_path, model_patch} to predictions.jsonl.
  6. Save trajectory and per-instance run report.

The runner is resumable: instances already present in the predictions file
are skipped unless --force is set.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import uuid
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
ROOT_DIR = SCRIPT_DIR.parent
PRINT_LOCK = threading.Lock()


@dataclass
class TaskResult:
    instance_id: str
    repo: str
    base_commit: str
    status: str
    exit_code: int | None
    duration_seconds: float
    patch_bytes: int
    trajectory_file: str | None = None
    error: str | None = None


# ---------------------------------------------------------------------------
# Argparse
# ---------------------------------------------------------------------------
def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run SWE-bench Verified with OpenLoomi."
    )
    parser.add_argument("--provider", default="",
                        help="OpenLoomi provider override (e.g. claude, codex).")
    parser.add_argument("--model", default="",
                        help="OpenLoomi model override (forwarded to openloomi-ctl).")
    parser.add_argument(
        "--permission-mode", choices=("deny", "bypass"), default="bypass",
        help="Forwarded to openloomi-ctl. Default: bypass.",
    )
    parser.add_argument("--max-concurrent", type=int, default=1,
                        help="Number of instances to run in parallel. Default: 1.")
    parser.add_argument("--timeout", type=int, default=3600,
                        help="Per-instance wall-clock cap in seconds. Default: 3600.")
    parser.add_argument("--limit", type=int, default=0,
                        help="Only run the first N instances after filtering.")
    parser.add_argument("--instance-id", action="append", default=[],
                        help="Only run the given instance_id. Repeatable.")
    parser.add_argument("--repo", action="append", default=[],
                        help="Only run instances of the given repo (e.g. django/django).")
    parser.add_argument("--force", action="store_true",
                        help="Re-run even if prediction already exists.")
    parser.add_argument("--keep-workspace", action="store_true",
                        help="Do not delete the per-instance workspace at the end.")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print the plan but do not run anything.")
    return parser.parse_args()


# ---------------------------------------------------------------------------
# Dataset loading
# ---------------------------------------------------------------------------
def load_verified(dataset_name: str) -> list[dict]:
    from datasets import load_dataset
    ds = load_dataset(dataset_name, split="test")
    return list(ds)


def filter_instances(
    instances: list[dict],
    only_ids: list[str],
    only_repos: list[str],
) -> list[dict]:
    out = instances
    if only_ids:
        ids = set(only_ids)
        out = [i for i in out if i["instance_id"] in ids]
    if only_repos:
        repos = set(only_repos)
        out = [i for i in out if i["repo"] in repos]
    return out


# ---------------------------------------------------------------------------
# Workspace preparation
# ---------------------------------------------------------------------------
def prep_workspace(instance: dict, work_dir: Path) -> Path:
    """Clone the repo at base_commit and return the path of the working tree."""
    iid = instance["instance_id"]
    repo = instance["repo"]
    base = instance["base_commit"]
    repo_dir = work_dir / "workspaces" / iid
    if repo_dir.exists():
        shutil.rmtree(repo_dir)
    repo_dir.mkdir(parents=True)

    cache = work_dir / "repo-cache" / repo.replace("/", "__")
    if not cache.exists():
        cache.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(
            ["git", "clone", "--quiet", f"https://github.com/{repo}.git", str(cache)],
            check=True,
        )

    src = repo_dir / "src"
    subprocess.run(
        ["git", "clone", "--quiet", "--shared", "--no-checkout", str(cache), str(src)],
        check=True,
    )
    subprocess.run(["git", "checkout", "-q", base], cwd=src, check=True)

    # Mark the baseline so post-run `git diff` does not include benchmark files
    # that we may need to add later.
    (src / ".swebench-baseline").write_text(
        f"instance_id={iid}\nbase_commit={base}\nrepo={repo}\n",
        encoding="utf-8",
    )
    return src


# ---------------------------------------------------------------------------
# Prompt construction
# ---------------------------------------------------------------------------
def make_prompt(instance: dict, repo_path: Path) -> str:
    return f"""=== SWE-bench Verified Instance ===
Instance ID : {instance['instance_id']}
Repository  : {instance['repo']}
Base commit : {instance['base_commit']}

=== Repository (already checked out at base_commit) ===
{repo_path}

=== Problem Statement ===
{instance['problem_statement']}

=== Instructions ===
1. Explore the repository at the path above.
2. Identify the root cause and modify the source code to resolve the issue.
3. You may run local tests if practical.
4. Do NOT commit, push, or reset your changes.
5. Do NOT modify benchmark scaffolding files (such as `.swebench-baseline`).
6. Edit the files directly. The runner will extract `git diff` afterwards.
7. The unified diff must include line numbers in `@@` hunk headers
   (e.g. `@@ -start,count +start,count @@`). Missing line numbers cause
   the official patch to fail to apply.
"""


# ---------------------------------------------------------------------------
# Single instance
# ---------------------------------------------------------------------------
def already_predicted(predictions_path: Path, instance_id: str) -> bool:
    if not predictions_path.exists():
        return False
    with predictions_path.open(encoding="utf-8") as f:
        for line in f:
            try:
                if json.loads(line).get("instance_id") == instance_id:
                    return True
            except json.JSONDecodeError:
                continue
    return False


def extract_diff(repo_path: Path) -> str:
    res = subprocess.run(
        ["git", "diff", "--binary", "--no-color"],
        cwd=repo_path, capture_output=True, text=True, timeout=120,
    )
    return res.stdout


def run_instance(
    instance: dict,
    args: argparse.Namespace,
    model_name: str,
    work_dir: Path,
    predictions_path: Path,
) -> TaskResult:
    iid = instance["instance_id"]
    traj_dir = ROOT_DIR / "trajectories" / model_name / iid
    traj_dir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    traj_file = traj_dir / f"attempt_{stamp}_{uuid.uuid4().hex[:8]}.json"

    started = time.monotonic()

    if not args.force and already_predicted(predictions_path, iid):
        with PRINT_LOCK:
            print(f"SKIP  {iid}: prediction already exists")
        return TaskResult(iid, instance["repo"], instance["base_commit"],
                          "skipped", 0, 0.0, 0, str(traj_file))

    repo_path: Path | None = None
    try:
        repo_path = prep_workspace(instance, work_dir)
        prompt = make_prompt(instance, repo_path)

        ctl = os.environ.get("OPENLOOMI_CTL", "")
        if not ctl or not Path(ctl).is_file():
            raise RuntimeError(
                "OPENLOOMI_CTL is not set or does not point to a real file. "
                "Export OPENLOOMI_CTL=/path/to/openloomi-ctl(.exe)."
            )

        cmd = [
            ctl,
            "--one-shot", "--stdin", "--json",
            "--platform", "benchmark-swebench",
            "--permission-mode", args.permission_mode,
        ]
        if args.provider:
            cmd += ["--provider", args.provider]
        if args.model:
            cmd += ["--model", args.model]

        with PRINT_LOCK:
            print(f"RUN   {iid}  ({instance['repo']} @ {instance['base_commit'][:8]})")

        proc = subprocess.run(
            cmd,
            cwd=repo_path,
            input=prompt,
            text=True,
            encoding="utf-8",
            errors="replace",
            capture_output=True,
            timeout=args.timeout,
            env=os.environ.copy(),
        )
        diff = extract_diff(repo_path)

        traj_file.write_text(
            json.dumps(
                {
                    "instance_id": iid,
                    "repo": instance["repo"],
                    "base_commit": instance["base_commit"],
                    "command": cmd,
                    "started_at": stamp,
                    "duration_seconds": round(time.monotonic() - started, 3),
                    "exit_code": proc.returncode,
                    "stdout": proc.stdout,
                    "stderr": proc.stderr,
                    "patch_bytes": len(diff),
                },
                ensure_ascii=False,
                indent=2,
            ),
            encoding="utf-8",
        )

        predictions_path.parent.mkdir(parents=True, exist_ok=True)
        with predictions_path.open("a", encoding="utf-8") as f:
            f.write(
                json.dumps(
                    {
                        "instance_id": iid,
                        "model_name_or_path": model_name,
                        "model_patch": diff,
                    },
                    ensure_ascii=False,
                )
                + "\n"
            )

        if proc.returncode != 0 and not diff.strip():
            return TaskResult(iid, instance["repo"], instance["base_commit"],
                              "failed", proc.returncode,
                              time.monotonic() - started,
                              len(diff), str(traj_file),
                              f"openloomi-ctl exit={proc.returncode} and no diff")

        status = "success" if proc.returncode == 0 else "cli_error"
        with PRINT_LOCK:
            print(f"DONE  {iid}: {status}  patch={len(diff)}B")
        return TaskResult(iid, instance["repo"], instance["base_commit"],
                          status, proc.returncode,
                          time.monotonic() - started,
                          len(diff), str(traj_file))

    except subprocess.TimeoutExpired as exc:
        traj_file.write_text(
            json.dumps(
                {
                    "instance_id": iid,
                    "started_at": stamp,
                    "status": "timeout",
                    "stdout": exc.stdout or "",
                    "stderr": exc.stderr or "",
                },
                ensure_ascii=False,
                indent=2,
            ),
            encoding="utf-8",
        )
        with PRINT_LOCK:
            print(f"TIME  {iid}: exceeded {args.timeout}s")
        return TaskResult(iid, instance["repo"], instance["base_commit"],
                          "timeout", None,
                          time.monotonic() - started,
                          0, str(traj_file),
                          f"Timed out after {args.timeout}s")
    except Exception as exc:  # noqa: BLE001
        with PRINT_LOCK:
            print(f"FAIL  {iid}: {exc}")
        return TaskResult(iid, instance["repo"], instance["base_commit"],
                          "failed", None,
                          time.monotonic() - started,
                          0, str(traj_file), str(exc))
    finally:
        if not args.keep_workspace and repo_path is not None:
            shutil.rmtree(repo_path.parent, ignore_errors=True)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main() -> int:
    args = parse_args()
    if args.max_concurrent < 1:
        print("--max-concurrent must be at least 1", file=sys.stderr)
        return 2
    if args.timeout < 1:
        print("--timeout must be at least 1", file=sys.stderr)
        return 2

    model_name = os.environ.get("SWEBENCH_MODEL_NAME", "openloomi-verified")
    dataset_name = os.environ.get(
        "SWEBENCH_DATASET", "SWE-bench/SWE-bench_Verified"
    )
    work_dir = Path(os.environ.get("SWEBENCH_WORK_DIR", "D:/swebench-work"))
    work_dir.mkdir(parents=True, exist_ok=True)

    predictions_path = Path(
        os.environ.get(
            "SWEBENCH_PREDICTIONS",
            str(ROOT_DIR / "predictions" / f"{model_name}.jsonl"),
        )
    )

    print(f"Dataset       : {dataset_name}")
    print(f"Model         : {model_name}")
    print(f"Work dir      : {work_dir}")
    print(f"Predictions   : {predictions_path}")
    print(f"Concurrency   : {args.max_concurrent}")
    print(f"Timeout (s)   : {args.timeout}")
    print(f"Provider/Model: {args.provider or '<default>'} / {args.model or '<default>'}")

    instances = load_verified(dataset_name)
    instances = filter_instances(instances, args.instance_id, args.repo)
    if args.limit:
        instances = instances[: args.limit]
    if not instances:
        print("Error: no matching SWE-bench Verified instances found", file=sys.stderr)
        return 2
    print(f"Selected      : {len(instances)} instance(s)")

    if args.dry_run:
        for inst in instances[:10]:
            print(f"  - {inst['instance_id']}  ({inst['repo']})")
        if len(instances) > 10:
            print(f"  ... and {len(instances) - 10} more")
        return 0

    results: list[TaskResult] = []
    with ThreadPoolExecutor(max_workers=args.max_concurrent) as ex:
        futs = [
            ex.submit(
                run_instance, inst, args, model_name, work_dir, predictions_path
            )
            for inst in instances
        ]
        for f in as_completed(futs):
            results.append(f.result())

    results.sort(key=lambda r: r.instance_id)
    counts: dict[str, int] = {}
    for r in results:
        counts[r.status] = counts.get(r.status, 0) + 1
    print(f"Counts: {counts}")

    summary_dir = ROOT_DIR / "logs"
    summary_dir.mkdir(parents=True, exist_ok=True)
    summary_path = summary_dir / f"openloomi_verified_{model_name}_{int(time.time())}.json"
    summary_path.write_text(
        json.dumps(
            {
                "model": model_name,
                "dataset": dataset_name,
                "predictions_path": str(predictions_path),
                "counts": counts,
                "results": [asdict(r) for r in results],
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    print(f"Run report: {summary_path}")
    return 1 if counts.get("failed", 0) or counts.get("timeout", 0) else 0


if __name__ == "__main__":
    raise SystemExit(main())
