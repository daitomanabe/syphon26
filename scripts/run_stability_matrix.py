#!/usr/bin/env python3
import argparse
import csv
import json
import os
import plistlib
import re
import subprocess
import tempfile
import time
from datetime import datetime
from pathlib import Path


MATRICES = {
    "smoke": [
        {"name": "1080p60", "width": 1920, "height": 1080, "fps": 60, "duration": 5, "pixelFormat": "bgra8"},
        {"name": "1080pmax", "width": 1920, "height": 1080, "fps": 0, "duration": 3, "pixelFormat": "bgra8"},
    ],
    "production": [
        {"name": "1080p60-30m", "width": 1920, "height": 1080, "fps": 60, "duration": 1800, "pixelFormat": "bgra8"},
        {"name": "4k60-30m", "width": 3840, "height": 2160, "fps": 60, "duration": 1800, "pixelFormat": "bgra8"},
        {"name": "1080pmax-10m", "width": 1920, "height": 1080, "fps": 0, "duration": 600, "pixelFormat": "bgra8"},
    ],
}


def parse_args():
    parser = argparse.ArgumentParser(description="Run long app-to-app Syphon26 stability checks.")
    parser.add_argument("--preset", choices=sorted(MATRICES), default="smoke")
    parser.add_argument("--matrix", default="", help="Comma-separated matrix names from the selected preset.")
    parser.add_argument("--output", default="benchmark-results/stability-smoke")
    parser.add_argument("--sample-interval", type=float, default=10.0)
    parser.add_argument("--skip-build", action="store_true")
    return parser.parse_args()


def run(command, cwd, check=True):
    env = os.environ.copy()
    env.setdefault("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer")
    process = subprocess.run(command, cwd=cwd, env=env, text=True, capture_output=True)
    if check and process.returncode != 0:
        raise RuntimeError(process.stdout + process.stderr)
    return process


def environment(repo_root):
    def maybe(command):
        try:
            return run(command, repo_root).stdout.strip()
        except Exception:
            return ""

    swift_version = maybe(["swift", "--version"]).splitlines()
    return {
        "createdAt": datetime.now().isoformat(timespec="seconds"),
        "gitCommit": maybe(["git", "rev-parse", "HEAD"]),
        "macOS": maybe(["sw_vers", "-productVersion"]),
        "machine": maybe(["uname", "-m"]),
        "swiftVersion": swift_version[0] if swift_version else "",
        "xcode": maybe(["xcodebuild", "-version"]).splitlines(),
    }


def parse_key_values(text, prefix):
    for line in text.splitlines():
        if line.startswith(prefix):
            return dict(re.findall(r"([A-Za-z][A-Za-z0-9]*)=([^\s]+)", line))
    return {}


def process_rss_kb(pid):
    process = subprocess.run(["ps", "-o", "rss=", "-p", str(pid)], text=True, capture_output=True)
    if process.returncode != 0:
        return None
    value = process.stdout.strip()
    return int(value) if value else None


def process_fd_count(pid):
    process = subprocess.run(["lsof", "-n", "-p", str(pid)], text=True, capture_output=True)
    if process.returncode != 0:
        return None
    lines = [line for line in process.stdout.splitlines() if line.strip()]
    return max(len(lines) - 1, 0) if lines else 0


def process_sample(role, pid, start_time):
    rss = process_rss_kb(pid)
    return {
        "elapsedSeconds": round(time.monotonic() - start_time, 3),
        "role": role,
        "pid": pid,
        "rssKB": rss,
        "fdCount": process_fd_count(pid) if rss is not None else None,
        "alive": rss is not None,
    }


def summarize_resource(samples, role):
    role_samples = [sample for sample in samples if sample["role"] == role and sample["rssKB"] is not None]
    if not role_samples:
        return {
            "rssStartKB": None,
            "rssEndKB": None,
            "rssMaxKB": None,
            "rssDeltaKB": None,
            "fdStart": None,
            "fdEnd": None,
            "fdMax": None,
            "fdDelta": None,
        }
    first = role_samples[0]
    last = role_samples[-1]
    return {
        "rssStartKB": first["rssKB"],
        "rssEndKB": last["rssKB"],
        "rssMaxKB": max(sample["rssKB"] for sample in role_samples),
        "rssDeltaKB": last["rssKB"] - first["rssKB"],
        "fdStart": first["fdCount"],
        "fdEnd": last["fdCount"],
        "fdMax": max(sample["fdCount"] for sample in role_samples if sample["fdCount"] is not None),
        "fdDelta": last["fdCount"] - first["fdCount"] if last["fdCount"] is not None and first["fdCount"] is not None else None,
    }


def is_resource_stable(summary):
    for role in ["producer", "consumer"]:
        resources = summary[f"{role}Resources"]
        rss_start = resources["rssStartKB"]
        rss_delta = resources["rssDeltaKB"]
        fd_delta = resources["fdDelta"]
        if rss_start is not None and rss_delta is not None:
            rss_limit = max(64 * 1024, int(rss_start * 0.15))
            if rss_delta > rss_limit:
                return False
        if fd_delta is not None and fd_delta > 8:
            return False
    return True


def write_resource_csv(path, samples):
    with path.open("w", newline="") as file:
        writer = csv.DictWriter(
            file,
            fieldnames=["elapsedSeconds", "role", "pid", "rssKB", "fdCount", "alive"],
            lineterminator="\n",
        )
        writer.writeheader()
        writer.writerows(samples)


def make_plist(service_name, service_bin):
    return {
        "Label": service_name,
        "ProgramArguments": [str(service_bin), "--mach-service", service_name],
        "MachServices": {service_name: True},
        "RunAtLoad": True,
        "KeepAlive": True,
    }


def bootout(plist_path):
    subprocess.run(
        ["launchctl", "bootout", f"gui/{os.getuid()}", str(plist_path)],
        text=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def terminate(process):
    if process is None or process.poll() is not None:
        return
    process.terminate()
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=5)


def run_one(repo_root, output_root, matrix, sample_interval):
    run_dir = output_root / matrix["name"]
    run_dir.mkdir(parents=True, exist_ok=True)

    service_name = f"com.syphon26.stability.{os.getuid()}.{os.getpid()}.{matrix['name']}"
    service_bin = repo_root / ".build/release/Syphon26ControlPlaneService"
    producer_bin = repo_root / ".build/release/Syphon26SampleProducer"
    consumer_bin = repo_root / ".build/release/Syphon26SampleConsumer"
    producer_duration = float(matrix["duration"]) + 1.0

    plist_fd, plist_name = tempfile.mkstemp(prefix="syphon26-stability-", suffix=".plist")
    plist_path = Path(plist_name)
    os.close(plist_fd)
    with plist_path.open("wb") as file:
        plistlib.dump(make_plist(service_name, service_bin), file)

    producer_log_path = run_dir / "producer.log"
    consumer_log_path = run_dir / "consumer.log"
    samples = []
    producer = None
    consumer = None
    start_time = time.monotonic()

    try:
        run(["launchctl", "bootstrap", f"gui/{os.getuid()}", str(plist_path)], repo_root)
        time.sleep(0.8)

        consumer_log = consumer_log_path.open("w")
        producer_log = producer_log_path.open("w")
        try:
            consumer = subprocess.Popen(
                [
                    str(consumer_bin),
                    "--mach-service",
                    service_name,
                    "--duration",
                    str(matrix["duration"]),
                    "--attach-timeout",
                    "10",
                    "--pixel-format",
                    matrix["pixelFormat"],
                ],
                cwd=repo_root,
                text=True,
                stdout=consumer_log,
                stderr=subprocess.STDOUT,
            )
            time.sleep(0.2)
            producer = subprocess.Popen(
                [
                    str(producer_bin),
                    "--mach-service",
                    service_name,
                    "--duration",
                    str(producer_duration),
                    "--width",
                    str(matrix["width"]),
                    "--height",
                    str(matrix["height"]),
                    "--fps",
                    str(matrix["fps"]),
                    "--pixel-format",
                    matrix["pixelFormat"],
                ],
                cwd=repo_root,
                text=True,
                stdout=producer_log,
                stderr=subprocess.STDOUT,
            )

            while consumer.poll() is None:
                samples.append(process_sample("consumer", consumer.pid, start_time))
                samples.append(process_sample("producer", producer.pid, start_time))
                time.sleep(sample_interval)

            consumer_status = consumer.wait()
            producer_status = producer.wait(timeout=max(10, int(sample_interval * 2)))
        finally:
            consumer_log.close()
            producer_log.close()
    finally:
        terminate(consumer)
        terminate(producer)
        bootout(plist_path)
        plist_path.unlink(missing_ok=True)

    samples.append(process_sample("consumer", consumer.pid, start_time))
    samples.append(process_sample("producer", producer.pid, start_time))
    write_resource_csv(run_dir / "resource-samples.csv", samples)

    producer_text = producer_log_path.read_text()
    consumer_text = consumer_log_path.read_text()
    producer_summary = parse_key_values(producer_text, "Syphon26SampleProducer ")
    consumer_summary = parse_key_values(consumer_text, "Syphon26SampleConsumer streamID=")
    if not producer_summary or not consumer_summary:
        raise RuntimeError(f"missing producer or consumer summary for {matrix['name']}")

    observed_frames = int(consumer_summary["observed"])
    consumer_fps = observed_frames / float(matrix["duration"])
    target_fps = float(matrix["fps"])
    fixed_fps_ok = target_fps <= 0 or consumer_fps >= target_fps * 0.99
    summary = {
        "matrix": matrix["name"],
        "width": matrix["width"],
        "height": matrix["height"],
        "fpsTarget": matrix["fps"],
        "durationSeconds": matrix["duration"],
        "pixelFormat": matrix["pixelFormat"],
        "producerReturnCode": producer_status,
        "consumerReturnCode": consumer_status,
        "producerFrames": int(producer_summary["frames"]),
        "producerPublishedFrames": int(producer_summary["published"]),
        "consumerObservedFrames": observed_frames,
        "consumerLastSequence": int(consumer_summary["lastSequence"]),
        "consumerRepeatedReads": int(consumer_summary["repeatedReads"]),
        "consumerFPS": consumer_fps,
        "producerResources": summarize_resource(samples, "producer"),
        "consumerResources": summarize_resource(samples, "consumer"),
    }
    summary["resourceStable"] = is_resource_stable(summary)
    summary["passed"] = (
        producer_status == 0
        and consumer_status == 0
        and observed_frames > 0
        and fixed_fps_ok
        and summary["resourceStable"]
    )
    (run_dir / "run.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    return summary


def write_summary(output_root, env, runs):
    manifest = {"environment": env, "runs": runs}
    (output_root / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    lines = [
        "# Syphon26 App-To-App Stability Report",
        "",
        f"Created: `{env['createdAt']}`",
        f"Git commit: `{env['gitCommit']}`",
        "",
        "| Matrix | Duration | Format | Consumer FPS | Producer RSS Delta | Consumer RSS Delta | Producer FD Delta | Consumer FD Delta | Result |",
        "| --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | --- |",
    ]
    for run_record in runs:
        producer_resources = run_record["producerResources"]
        consumer_resources = run_record["consumerResources"]
        result = "pass" if run_record["passed"] else "fail"
        lines.append(
            f"| {run_record['matrix']} | {run_record['durationSeconds']}s | {run_record['pixelFormat']} | "
            f"{run_record['consumerFPS']:.2f} | {producer_resources['rssDeltaKB'] or 0} KB | "
            f"{consumer_resources['rssDeltaKB'] or 0} KB | {producer_resources['fdDelta'] or 0} | "
            f"{consumer_resources['fdDelta'] or 0} | {result} |"
        )
    lines.extend(
        [
            "",
            "Memory stability is evaluated from RSS start/end deltas. Handle stability is evaluated from file-descriptor count deltas sampled during the producer and consumer lifetimes.",
        ]
    )
    (output_root / "summary.md").write_text("\n".join(lines) + "\n")


def main():
    args = parse_args()
    repo_root = Path(__file__).resolve().parents[1]
    output_root = repo_root / args.output
    output_root.mkdir(parents=True, exist_ok=True)

    if not args.skip_build:
        run(["swift", "build", "-c", "release"], repo_root)

    selected = MATRICES[args.preset]
    if args.matrix:
        names = {name.strip() for name in args.matrix.split(",") if name.strip()}
        selected = [matrix for matrix in selected if matrix["name"] in names]
        missing = names.difference(matrix["name"] for matrix in selected)
        if missing:
            raise SystemExit(f"unknown matrix name(s): {', '.join(sorted(missing))}")

    env = environment(repo_root)
    runs = []
    for matrix in selected:
        print(f"running {matrix['name']} for {matrix['duration']}s", flush=True)
        runs.append(run_one(repo_root, output_root, matrix, args.sample_interval))

    write_summary(output_root, env, runs)
    print(json.dumps({"runs": runs}, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
