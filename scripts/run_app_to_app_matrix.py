#!/usr/bin/env python3
import argparse
import csv
import json
import os
import re
import subprocess
from datetime import datetime
from pathlib import Path


CLASSIC_SYPHON_BASELINE = {
    "1080p60": {"clientFPS": 59.9941955615569, "mode": "fixed"},
    "4k60": {"clientFPS": 59.97370402971977, "mode": "fixed"},
    "1080pmax": {"clientFPS": 346.44012942859786, "mode": "max"},
    "4kmax": {"clientFPS": 343.6226849676139, "mode": "max"},
}

MATRICES = {
    "smoke": [
        {"name": "1080p60", "width": 1920, "height": 1080, "fps": 60, "duration": 3, "pixelFormat": "bgra8"},
        {"name": "1080pmax", "width": 1920, "height": 1080, "fps": 0, "duration": 2, "pixelFormat": "bgra8"},
    ],
    "production": [
        {"name": "1080p60", "width": 1920, "height": 1080, "fps": 60, "duration": 10, "pixelFormat": "bgra8"},
        {"name": "4k60", "width": 3840, "height": 2160, "fps": 60, "duration": 10, "pixelFormat": "bgra8"},
        {"name": "1080pmax", "width": 1920, "height": 1080, "fps": 0, "duration": 5, "pixelFormat": "bgra8"},
        {"name": "4kmax", "width": 3840, "height": 2160, "fps": 0, "duration": 5, "pixelFormat": "bgra8"},
        {"name": "4k60-rgba16f", "width": 3840, "height": 2160, "fps": 60, "duration": 10, "pixelFormat": "rgba16f"},
    ],
}


def parse_args():
    parser = argparse.ArgumentParser(description="Run Syphon26 app-to-app sample benchmark matrix.")
    parser.add_argument("--preset", choices=sorted(MATRICES), default="smoke")
    parser.add_argument("--output", default="benchmark-reports/app-to-app-20260524")
    return parser.parse_args()


def run(command, cwd):
    env = os.environ.copy()
    env.setdefault("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer")
    process = subprocess.run(command, cwd=cwd, env=env, text=True, capture_output=True)
    output = process.stdout + process.stderr
    if process.returncode != 0:
        raise RuntimeError(output)
    return output


def parse_key_values(line):
    pairs = dict(re.findall(r"([A-Za-z][A-Za-z0-9]*)=([^\s]+)", line))
    return pairs


def parse_run_output(output):
    producer = {}
    consumer = {}
    for line in output.splitlines():
        if line.startswith("Syphon26SampleProducer "):
            producer = parse_key_values(line)
        elif line.startswith("Syphon26SampleConsumer streamID="):
            consumer = parse_key_values(line)
    if not producer or not consumer:
        raise RuntimeError(f"missing producer or consumer summary in output:\n{output}")
    return producer, consumer


def environment(repo_root):
    def maybe(command):
        try:
            return run(command, repo_root).strip()
        except Exception:
            return ""

    return {
        "createdAt": datetime.now().isoformat(timespec="seconds"),
        "gitCommit": maybe(["git", "rev-parse", "HEAD"]),
        "macOS": maybe(["sw_vers", "-productVersion"]),
        "machine": maybe(["uname", "-m"]),
        "swiftVersion": maybe(["swift", "--version"]).splitlines()[0] if maybe(["swift", "--version"]) else "",
        "xcode": maybe(["xcodebuild", "-version"]).splitlines(),
    }


def compare(matrix_name, consumer_fps):
    baseline = CLASSIC_SYPHON_BASELINE.get(matrix_name)
    if baseline is None:
        return None
    if baseline["mode"] == "fixed":
        return {
            "classicSyphonClientFPS": baseline["clientFPS"],
            "mode": "fixed",
            "targetStability": consumer_fps / max(baseline["clientFPS"], 0.000001),
        }
    return {
        "classicSyphonClientFPS": baseline["clientFPS"],
        "mode": "max",
        "speedup": consumer_fps / max(baseline["clientFPS"], 0.000001),
    }


def write_outputs(output_root, env, runs):
    output_root.mkdir(parents=True, exist_ok=True)
    (output_root / "environment.json").write_text(json.dumps(env, indent=2, sort_keys=True) + "\n")
    (output_root / "app-to-app-results.json").write_text(json.dumps({"runs": runs}, indent=2, sort_keys=True) + "\n")

    with (output_root / "summary.csv").open("w", newline="") as file:
        writer = csv.DictWriter(
            file,
            fieldnames=[
                "matrix",
                "pixelFormat",
                "width",
                "height",
                "fpsTarget",
                "durationSeconds",
                "producerFrames",
                "consumerObservedFrames",
                "consumerFPS",
                "classicSyphonClientFPS",
                "result",
            ],
        )
        writer.writeheader()
        for run in runs:
            comparison = run.get("comparison") or {}
            result = ""
            if comparison.get("mode") == "max":
                result = f"{comparison['speedup']:.2f}x"
            elif comparison.get("mode") == "fixed":
                result = f"{comparison['targetStability']:.3f} target"
            writer.writerow(
                {
                    "matrix": run["matrix"],
                    "pixelFormat": run["pixelFormat"],
                    "width": run["width"],
                    "height": run["height"],
                    "fpsTarget": run["fpsTarget"],
                    "durationSeconds": run["durationSeconds"],
                    "producerFrames": run["producerFrames"],
                    "consumerObservedFrames": run["consumerObservedFrames"],
                    "consumerFPS": f"{run['consumerFPS']:.4f}",
                    "classicSyphonClientFPS": comparison.get("classicSyphonClientFPS", ""),
                    "result": result,
                }
            )

    lines = [
        "# Syphon26 App-To-App Benchmark",
        "",
        f"Created: `{env['createdAt']}`",
        f"Git commit: `{env['gitCommit']}`",
        "",
        "These runs use the launchd-managed Syphon26 control-plane service plus separate producer and consumer processes.",
        "Classic Syphon comparison values are from the sibling Syphon-Framework benchmark run in the same OS session.",
        "",
        "| Matrix | Format | Syphon26 Consumer FPS | Classic Syphon FPS | Result |",
        "| --- | --- | ---: | ---: | ---: |",
    ]
    for run in runs:
        comparison = run.get("comparison") or {}
        if comparison.get("mode") == "max":
            result = f"{comparison['speedup']:.2f}x"
        elif comparison.get("mode") == "fixed":
            result = f"{comparison['targetStability']:.3f} target"
        else:
            result = "n/a"
        lines.append(
            f"| {run['matrix']} | {run['pixelFormat']} | {run['consumerFPS']:.2f} | "
            f"{comparison.get('classicSyphonClientFPS', 0):.2f} | {result} |"
        )
    lines.extend(
        [
            "",
            "Scope note: shared-event app-to-app reads latest sequence from `MTLSharedEvent.signaledValue`; sequence-poll fallback still uses XPC shared-state reads.",
            "The in-process benchmark remains the upper-bound transport reference because the sample apps include launchd and process scheduling overhead.",
        ]
    )
    (output_root / "summary.md").write_text("\n".join(lines) + "\n")


def main():
    args = parse_args()
    repo_root = Path(__file__).resolve().parents[1]
    output_root = repo_root / args.output
    runs = []
    for matrix in MATRICES[args.preset]:
        command = [
            "scripts/run_sample_pair.sh",
            "--duration",
            str(matrix["duration"]),
            "--width",
            str(matrix["width"]),
            "--height",
            str(matrix["height"]),
            "--fps",
            str(matrix["fps"]),
            "--pixel-format",
            matrix["pixelFormat"],
        ]
        output = run(command, repo_root)
        producer, consumer = parse_run_output(output)
        consumer_frames = int(consumer["observed"])
        consumer_fps = consumer_frames / float(matrix["duration"])
        run_record = {
            "matrix": matrix["name"],
            "width": matrix["width"],
            "height": matrix["height"],
            "fpsTarget": matrix["fps"],
            "durationSeconds": matrix["duration"],
            "pixelFormat": matrix["pixelFormat"],
            "streamID": consumer["streamID"],
            "producerFrames": int(producer["frames"]),
            "producerPublishedFrames": int(producer["published"]),
            "consumerObservedFrames": consumer_frames,
            "consumerLastSequence": int(consumer["lastSequence"]),
            "consumerRepeatedReads": int(consumer["repeatedReads"]),
            "consumerFPS": consumer_fps,
        }
        run_record["comparison"] = compare(matrix["name"], consumer_fps)
        runs.append(run_record)
    write_outputs(output_root, environment(repo_root), runs)
    print(json.dumps({"runs": runs}, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
