#!/usr/bin/env python3
import json
import os
import pathlib
import platform
import subprocess
import sys
from datetime import datetime, timezone


ROOT = pathlib.Path(__file__).resolve().parents[1]
REPORT_DIR = ROOT / "benchmark-reports"


def run(command):
    env = os.environ.copy()
    env.setdefault("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer")
    result = subprocess.run(
        command,
        cwd=ROOT,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        sys.stderr.write(result.stderr)
        raise SystemExit(result.returncode)
    return result.stdout.strip(), result.stderr.strip()


def run_case(width, height, frames, fps_target):
    command = [
        "swift",
        "run",
        "Syphon26Benchmark",
        "--width",
        str(width),
        "--height",
        str(height),
        "--frames",
        str(frames),
        "--fps-target",
        str(fps_target),
        "--json",
    ]
    stdout, stderr = run(command)
    report = json.loads(stdout.splitlines()[-1])
    report["runnerCommand"] = command
    report["runnerStderr"] = stderr
    return report


def write_markdown(path, payload):
    lines = [
        "# Syphon26 Benchmark Report",
        "",
        f"- generatedAt: `{payload['generatedAt']}`",
        f"- host: `{payload['runnerEnvironment']['host']}`",
        f"- python: `{payload['runnerEnvironment']['python']}`",
        f"- v1ComparisonStatus: `{payload['v1ComparisonStatus']}`",
        f"- classicSyphonComparisonStatus: `{payload['classicSyphonComparisonStatus']}`",
        "",
        "| case | resolution | frames | publish FPS | receive FPS | missed | repeated | avg latency ns |",
        "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for case in payload["cases"]:
        lines.append(
            "| {name} | {width}x{height} | {frames} | {publish:.2f} | {receive:.2f} | {missed} | {repeated} | {latency} |".format(
                name=case["benchmarkName"],
                width=case["resolution"]["width"],
                height=case["resolution"]["height"],
                frames=case["frameCount"],
                publish=case["publishFPS"],
                receive=case["receiveFPS"],
                missed=case["missedFrames"],
                repeated=case["repeatedReads"],
                latency=case["latencyNanosecondsAverage"],
            )
        )
    lines.extend([
        "",
        "## Interpretation Limits",
        "",
    ])
    for limit in payload["interpretationLimits"]:
        lines.append(f"- {limit}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main():
    REPORT_DIR.mkdir(exist_ok=True)
    generated_at = datetime.now(timezone.utc).isoformat()
    cases = [
        run_case(width=640, height=360, frames=120, fps_target=60),
        run_case(width=1920, height=1080, frames=120, fps_target=60),
    ]
    payload = {
        "schemaVersion": 1,
        "generatedAt": generated_at,
        "runnerEnvironment": {
            "host": platform.node(),
            "platform": platform.platform(),
            "python": platform.python_version(),
        },
        "cases": cases,
        "v1ComparisonStatus": "not_run",
        "classicSyphonComparisonStatus": "not_run",
        "interpretationLimits": [
            "Current reports measure the v2 in-process transport harness only.",
            "No v1 branch checkout was built or measured by this runner.",
            "No classic Syphon framework benchmark was built or measured by this runner.",
            "Do not use these numbers as published compatibility or performance claims.",
        ],
    }
    json_path = REPORT_DIR / "latest.json"
    markdown_path = REPORT_DIR / "latest.md"
    json_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    write_markdown(markdown_path, payload)
    print(json.dumps({
        "status": "ok",
        "jsonReport": str(json_path),
        "markdownReport": str(markdown_path),
        "caseCount": len(cases),
        "v1ComparisonStatus": payload["v1ComparisonStatus"],
        "classicSyphonComparisonStatus": payload["classicSyphonComparisonStatus"],
    }, sort_keys=True))


if __name__ == "__main__":
    main()
