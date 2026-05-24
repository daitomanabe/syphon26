#!/usr/bin/env python3
import argparse
import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path


CLASSIC_SYPHON_BASELINE = {
    "1080p60": {"clientFPS": 59.9718, "mode": "fixed"},
    "4k60": {"clientFPS": 59.5719, "mode": "fixed"},
    "4k120": {"clientFPS": 119.9520, "mode": "fixed"},
    "1080pmax": {"clientFPS": 572.8943, "mode": "max"},
    "4kmax": {"clientFPS": 471.9263, "mode": "max"},
}

MATRICES = {
    "1080p60": {"width": 1920, "height": 1080, "fps": 60, "duration": 2},
    "4k60": {"width": 3840, "height": 2160, "fps": 60, "duration": 2},
    "4k120": {"width": 3840, "height": 2160, "fps": 120, "duration": 2},
    "1080pmax": {"width": 1920, "height": 1080, "fps": 0, "duration": 1},
    "4kmax": {"width": 3840, "height": 2160, "fps": 0, "duration": 1},
}


def parse_args():
    parser = argparse.ArgumentParser(description="Run the Syphon26 benchmark matrix.")
    parser.add_argument("--matrix", default="1080p60,4k60,4k120,1080pmax,4kmax")
    parser.add_argument("--clients", default="1")
    parser.add_argument("--sync", default="sequence-polling")
    parser.add_argument("--warmup", type=float, default=0.5)
    parser.add_argument("--slow-consumer-ms", type=float, default=0.0)
    parser.add_argument("--client-poll-us", type=int, default=0)
    parser.add_argument("--output", default="benchmark-results/matrix")
    parser.add_argument("--configuration", default="release", choices=["debug", "release"])
    return parser.parse_args()


def run_command(command, cwd):
    env = os.environ.copy()
    env.setdefault("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer")
    process = subprocess.run(command, cwd=cwd, env=env, text=True, capture_output=True)
    if process.returncode != 0:
        sys.stderr.write(process.stdout)
        sys.stderr.write(process.stderr)
        raise SystemExit(process.returncode)
    return process.stdout


def extract_json(stdout):
    start = stdout.find("{")
    end = stdout.rfind("}")
    if start < 0 or end < start:
        raise RuntimeError("benchmark output did not contain JSON")
    return json.loads(stdout[start : end + 1])


def run_one(repo_root, output_root, matrix_name, matrix, clients, sync, warmup, slow_consumer_ms, client_poll_us, configuration):
    suffix = f"{matrix_name}-c{clients}-{sync}"
    if slow_consumer_ms > 0:
        suffix += f"-slow{slow_consumer_ms:g}ms"
    if client_poll_us > 0:
        suffix += f"-poll{client_poll_us}us"
    run_output = output_root / suffix
    command = [
        "swift",
        "run",
    ]
    if configuration == "release":
        command.append("-c")
        command.append("release")
    command.extend(
        [
            "Syphon26Benchmark",
            "--width",
            str(matrix["width"]),
            "--height",
            str(matrix["height"]),
            "--fps",
            str(matrix["fps"]),
            "--warmup",
            str(warmup),
            "--duration",
            str(matrix["duration"]),
            "--clients",
            str(clients),
            "--sync",
            sync,
            "--slow-consumer-ms",
            str(slow_consumer_ms),
            "--client-poll-us",
            str(client_poll_us),
            "--output",
            str(run_output),
        ]
    )
    stdout = run_command(command, repo_root)
    summary = extract_json(stdout)
    summary["matrix"] = matrix_name
    summary["outputDirectory"] = str(run_output.relative_to(repo_root))
    return summary


def compare(summary):
    baseline = CLASSIC_SYPHON_BASELINE.get(summary["matrix"])
    if not baseline:
        return None
    classic_fps = baseline["clientFPS"]
    syphon26_fps = summary["minClientFPS"]
    if baseline["mode"] == "fixed":
        return {
            "classicSyphonClientFPS": classic_fps,
            "syphon26ClientFPS": syphon26_fps,
            "targetStability": syphon26_fps / max(summary["fpsTarget"], 0.000001),
            "mode": "fixed",
        }
    return {
        "classicSyphonClientFPS": classic_fps,
        "syphon26ClientFPS": syphon26_fps,
        "speedup": syphon26_fps / classic_fps,
        "mode": "max",
    }


def write_markdown(manifest, output_root):
    lines = [
        "# Syphon26 Benchmark Matrix",
        "",
        f"Created: `{manifest['createdAt']}`",
        "",
        "| Matrix | Clients | Sync | Syphon26 FPS | Classic Syphon FPS | Result |",
        "| --- | ---: | --- | ---: | ---: | ---: |",
    ]
    for run in manifest["runs"]:
        comparison = run.get("comparison") or {}
        if comparison.get("mode") == "max":
            result = f"{comparison['speedup']:.2f}x"
        elif comparison.get("mode") == "fixed":
            result = f"{comparison['targetStability']:.3f} target"
        else:
            result = "n/a"
        lines.append(
            f"| {run['matrix']} | {run['clients']} | {run['syncMode']} | "
            f"{run['minClientFPS']:.2f} | {comparison.get('classicSyphonClientFPS', 0):.2f} | {result} |"
        )
    (output_root / "summary.md").write_text("\n".join(lines) + "\n")


def main():
    args = parse_args()
    repo_root = Path(__file__).resolve().parents[1]
    output_root = repo_root / args.output
    output_root.mkdir(parents=True, exist_ok=True)
    selected = [item.strip() for item in args.matrix.split(",") if item.strip()]
    client_counts = [int(item.strip()) for item in args.clients.split(",") if item.strip()]

    runs = []
    for matrix_name in selected:
        matrix = MATRICES[matrix_name]
        for clients in client_counts:
            summary = run_one(
                repo_root,
                output_root,
                matrix_name,
                matrix,
                clients,
                args.sync,
                args.warmup,
                args.slow_consumer_ms,
                args.client_poll_us,
                args.configuration,
            )
            summary["comparison"] = compare(summary)
            runs.append(summary)

    manifest = {
        "createdAt": datetime.now().isoformat(timespec="seconds"),
        "sync": args.sync,
        "configuration": args.configuration,
        "slowConsumerMilliseconds": args.slow_consumer_ms,
        "clientPollMicroseconds": args.client_poll_us,
        "runs": runs,
    }
    (output_root / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True))
    write_markdown(manifest, output_root)
    print(json.dumps(manifest, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
