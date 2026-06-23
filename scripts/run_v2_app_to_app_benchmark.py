#!/usr/bin/env python3
import argparse
import json
import os
import pathlib
import platform
import subprocess
import sys
import time
from datetime import datetime


ROOT = pathlib.Path(__file__).resolve().parents[1]
REPORT_DIR = ROOT / "benchmark-reports" / "v2-app-to-app"

MATRICES = {
    "1080p60": {"width": 1920, "height": 1080, "fps": 60, "pixelFormat": "bgra8"},
    "1080pmax": {"width": 1920, "height": 1080, "fps": 0, "pixelFormat": "bgra8"},
    "4k60": {"width": 3840, "height": 2160, "fps": 60, "pixelFormat": "bgra8"},
    "4kmax": {"width": 3840, "height": 2160, "fps": 0, "pixelFormat": "bgra8"},
    "8k60": {"width": 7680, "height": 4320, "fps": 60, "pixelFormat": "bgra8"},
    "8kmax": {"width": 7680, "height": 4320, "fps": 0, "pixelFormat": "bgra8"},
    "16k60": {"width": 15360, "height": 8640, "fps": 60, "pixelFormat": "bgra8"},
    "16kmax": {"width": 15360, "height": 8640, "fps": 0, "pixelFormat": "bgra8"},
}


def parse_args():
    parser = argparse.ArgumentParser(description="Run Syphon26 v2 app-to-app benchmark producer/client processes.")
    parser.add_argument("--matrix", default="1080p60", help=f"Comma-separated matrices: {', '.join(sorted(MATRICES))}")
    parser.add_argument("--duration", type=float, default=1.0)
    parser.add_argument("--warmup", type=float, default=0.25)
    parser.add_argument("--configuration", default="release", choices=["debug", "release"])
    parser.add_argument("--render", default="clear", choices=["clear", "none"])
    parser.add_argument("--poll-us", type=int, default=0)
    parser.add_argument("--slow-consumer-ms", type=float, default=0.0)
    parser.add_argument("--wait-timeout", type=float, default=10.0)
    parser.add_argument("--output-dir", default=str(REPORT_DIR))
    parser.add_argument("--no-build", action="store_true")
    return parser.parse_args()


def selected_matrices(value):
    names = [item.strip() for item in value.split(",") if item.strip()]
    unknown = [name for name in names if name not in MATRICES]
    if unknown:
        raise SystemExit(f"Unknown matrix name(s): {', '.join(unknown)}")
    return names


def developer_env():
    env = os.environ.copy()
    env.setdefault("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer")
    return env


def run_capture(command, cwd=ROOT, env=None):
    completed = subprocess.run(
        command,
        cwd=cwd,
        env=env or developer_env(),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    return {
        "command": [str(item) for item in command],
        "cwd": str(cwd),
        "returncode": completed.returncode,
        "stdout": completed.stdout,
        "stderr": completed.stderr,
    }


def build_binary(configuration):
    command = ["swift", "build", "--product", "Syphon26AppToAppBenchmark"]
    if configuration == "release":
        command.extend(["-c", "release"])
    result = run_capture(command)
    if result["returncode"] != 0:
        sys.stderr.write(result["stdout"])
        sys.stderr.write(result["stderr"])
        raise SystemExit(result["returncode"])


def binary_path(configuration):
    directory = "release" if configuration == "release" else "debug"
    path = ROOT / ".build" / directory / "Syphon26AppToAppBenchmark"
    if not path.exists():
        raise SystemExit(f"Benchmark binary not found at {path}")
    return path


def wait_for_file(path, timeout):
    deadline = time.time() + timeout
    while time.time() < deadline:
        if path.exists():
            return True
        time.sleep(0.01)
    return False


def terminate(process):
    if process.poll() is not None:
        return
    process.terminate()
    try:
        process.wait(timeout=3)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=3)


def write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def collect_environment(configuration):
    return {
        "createdAt": datetime.now().isoformat(timespec="seconds"),
        "host": platform.node(),
        "platform": platform.platform(),
        "machine": platform.machine(),
        "python": platform.python_version(),
        "root": str(ROOT),
        "configuration": configuration,
        "swVers": run_capture(["sw_vers"]),
        "xcodebuildVersion": run_capture(["xcodebuild", "-version"], env=developer_env()),
    }


def run_one(binary, matrix_name, matrix, args, output_root):
    run_id = f"{datetime.now().strftime('%Y%m%d-%H%M%S')}-syphon26-{matrix_name}-c1"
    run_dir = output_root / run_id
    run_dir.mkdir(parents=True, exist_ok=True)
    log_dir = run_dir / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)

    state_path = run_dir / "syphon26.state.json"
    server_ready = run_dir / "server.ready"
    client_ready = run_dir / "client.ready"
    server_summary = run_dir / "server.json"
    client_summary = run_dir / "client-0.json"
    server_name = f"Syphon26 App-To-App Benchmark {run_id}"

    common = [
        "--name",
        server_name,
        "--width",
        str(matrix["width"]),
        "--height",
        str(matrix["height"]),
        "--fps-target",
        str(matrix["fps"]),
        "--pixel-format",
        matrix["pixelFormat"],
        "--warmup",
        str(args.warmup),
        "--duration",
        str(args.duration),
        "--render",
        args.render,
        "--state",
        str(state_path),
        "--client-ready",
        str(client_ready),
        "--wait-timeout",
        str(args.wait_timeout),
    ]

    server_cmd = [
        str(binary),
        "--role",
        "server",
        *common,
        "--server-ready",
        str(server_ready),
        "--summary",
        str(server_summary),
    ]
    client_cmd = [
        str(binary),
        "--role",
        "client",
        *common,
        "--poll-us",
        str(args.poll_us),
        "--slow-consumer-ms",
        str(args.slow_consumer_ms),
        "--summary",
        str(client_summary),
    ]

    server_log = open(log_dir / "server.log", "w", encoding="utf-8")
    client_log = open(log_dir / "client-0.log", "w", encoding="utf-8")
    server = subprocess.Popen(server_cmd, cwd=ROOT, env=developer_env(), stdout=server_log, stderr=subprocess.STDOUT)
    statuses = []
    try:
        server_became_ready = wait_for_file(server_ready, args.wait_timeout)
        if not server_became_ready:
            terminate(server)
            statuses.append({"role": "server", "returncode": server.returncode, "ready": False})
            return write_run_manifest(run_dir, run_id, server_name, matrix_name, args, server_cmd, client_cmd, statuses)

        client = subprocess.Popen(client_cmd, cwd=ROOT, env=developer_env(), stdout=client_log, stderr=subprocess.STDOUT)
        timeout = args.wait_timeout + args.warmup + args.duration + 15
        try:
            client_returncode = client.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            terminate(client)
            client_returncode = client.returncode
        statuses.append({"role": "client", "index": 0, "returncode": client_returncode})

        try:
            server_returncode = server.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            terminate(server)
            server_returncode = server.returncode
        statuses.append({"role": "server", "returncode": server_returncode, "ready": True})
    finally:
        terminate(server)
        server_log.close()
        client_log.close()

    return write_run_manifest(run_dir, run_id, server_name, matrix_name, args, server_cmd, client_cmd, statuses)


def write_run_manifest(run_dir, run_id, server_name, matrix_name, args, server_cmd, client_cmd, statuses):
    summary_paths = [run_dir / "server.json", run_dir / "client-0.json"]
    summaries = []
    for path in summary_paths:
        if path.exists():
            summaries.append(json.loads(path.read_text(encoding="utf-8")))

    manifest = {
        "runId": run_id,
        "transport": "syphon26-file-control-plane",
        "transportScope": "app-to-app-syphon26-file-control-plane",
        "processScope": "app-to-app",
        "serverName": server_name,
        "matrix": matrix_name,
        "warmupSeconds": args.warmup,
        "durationSeconds": args.duration,
        "renderMode": args.render,
        "serverCommand": server_cmd,
        "clientCommands": [client_cmd],
        "statuses": statuses,
        "artifacts": {
            "serverSummary": str(run_dir / "server.json"),
            "clientSummaries": [str(run_dir / "client-0.json")],
            "logs": str(run_dir / "logs"),
            "state": str(run_dir / "syphon26.state.json"),
        },
        "summaries": summaries,
    }
    write_json(run_dir / "manifest.json", manifest)
    return manifest


def main():
    args = parse_args()
    matrix_names = selected_matrices(args.matrix)
    output_root = pathlib.Path(args.output_dir).resolve()
    output_root.mkdir(parents=True, exist_ok=True)

    if not args.no_build:
        build_binary(args.configuration)
    binary = binary_path(args.configuration)
    write_json(output_root / "environment.json", collect_environment(args.configuration))

    manifests = [run_one(binary, name, MATRICES[name], args, output_root) for name in matrix_names]
    top_manifest = {
        "createdAt": datetime.now().isoformat(timespec="seconds"),
        "outputDir": str(output_root),
        "runs": [
            {
                "runId": manifest["runId"],
                "transport": manifest["transport"],
                "transportScope": manifest["transportScope"],
                "processScope": manifest["processScope"],
                "manifest": str(output_root / manifest["runId"] / "manifest.json"),
                "statuses": manifest["statuses"],
            }
            for manifest in manifests
        ],
    }
    write_json(output_root / "manifest.json", top_manifest)
    print(json.dumps(top_manifest, indent=2, sort_keys=True))

    failed = [
        status
        for manifest in manifests
        for status in manifest["statuses"]
        if status.get("returncode") != 0
    ]
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
