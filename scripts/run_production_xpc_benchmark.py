#!/usr/bin/env python3
import argparse
import json
import os
import pathlib
import platform
import plistlib
import subprocess
import sys
import time
from datetime import datetime


ROOT = pathlib.Path(__file__).resolve().parents[1]
REPORT_DIR = ROOT / "benchmark-reports" / "production-xpc"

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
    parser = argparse.ArgumentParser(description="Run Syphon26 production XPC benchmark through a launchd Mach service.")
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


def build_binaries(configuration):
    for product in ("Syphon26ControlPlaneService", "Syphon26ProductionXPCBenchmark"):
        command = ["swift", "build", "--product", product]
        if configuration == "release":
            command.extend(["-c", "release"])
        result = run_capture(command)
        if result["returncode"] != 0:
            sys.stderr.write(result["stdout"])
            sys.stderr.write(result["stderr"])
            raise SystemExit(result["returncode"])


def binary_path(configuration, name):
    directory = "release" if configuration == "release" else "debug"
    path = ROOT / ".build" / directory / name
    if not path.exists():
        raise SystemExit(f"Required binary not found at {path}")
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
        "launchctlPrint": run_capture(["launchctl", "print", f"gui/{os.getuid()}"]),
    }


def service_name_for(matrix_name):
    stamp = datetime.now().strftime("%Y%m%d%H%M%S")
    return f"com.syphon26.benchmark.{stamp}.{os.getpid()}.{matrix_name.lower().replace('-', '')}"


def write_launchd_plist(path, service_binary, service_name, stdout_path, stderr_path):
    payload = {
        "Label": service_name,
        "ProgramArguments": [str(service_binary), "--xpc-mach-service", service_name],
        "MachServices": {service_name: True},
        "RunAtLoad": False,
        "StandardOutPath": str(stdout_path),
        "StandardErrorPath": str(stderr_path),
    }
    path.write_bytes(plistlib.dumps(payload, sort_keys=True))


def bootstrap_service(plist_path):
    return run_capture(["launchctl", "bootstrap", f"gui/{os.getuid()}", str(plist_path)])


def bootout_service(plist_path):
    return run_capture(["launchctl", "bootout", f"gui/{os.getuid()}", str(plist_path)])


def run_tool(binary, args, timeout):
    return subprocess.run(
        [str(binary), *args],
        cwd=ROOT,
        env=developer_env(),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=timeout,
        check=False,
    )


def run_one(benchmark_binary, service_binary, matrix_name, matrix, args, output_root):
    run_id = f"{datetime.now().strftime('%Y%m%d-%H%M%S')}-production-xpc-{matrix_name}-c1"
    run_dir = output_root / run_id
    run_dir.mkdir(parents=True, exist_ok=True)
    log_dir = run_dir / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)

    service_name = service_name_for(matrix_name)
    plist_path = run_dir / f"{service_name}.plist"
    write_launchd_plist(
        plist_path,
        service_binary,
        service_name,
        log_dir / "service.stdout.log",
        log_dir / "service.stderr.log",
    )

    server_ready = run_dir / "server.ready"
    client_ready = run_dir / "client.ready"
    server_summary = run_dir / "server.json"
    client_summary = run_dir / "client-0.json"
    health_summary = run_dir / "health.json"
    reset_summary = run_dir / "reset.json"
    server_name = f"Syphon26 Production XPC Benchmark {run_id}"

    bootstrap_result = bootstrap_service(plist_path)
    bootout_result = None
    statuses = [{"role": "launchd-bootstrap", "returncode": bootstrap_result["returncode"]}]
    if bootstrap_result["returncode"] != 0:
        return write_run_manifest(
            run_dir,
            run_id,
            server_name,
            service_name,
            matrix_name,
            args,
            [],
            [],
            statuses,
            bootstrap_result,
            bootout_result,
        )

    try:
        common = [
            "--name",
            server_name,
            "--service-name",
            service_name,
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
            "--client-ready",
            str(client_ready),
            "--wait-timeout",
            str(args.wait_timeout),
        ]

        health_cmd = [
            "--role",
            "health",
            "--service-name",
            service_name,
            "--summary",
            str(health_summary),
        ]
        reset_cmd = [
            "--role",
            "reset",
            "--service-name",
            service_name,
            "--summary",
            str(reset_summary),
        ]
        server_cmd = [
            "--role",
            "server",
            *common,
            "--server-ready",
            str(server_ready),
            "--summary",
            str(server_summary),
        ]
        client_cmd = [
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

        health = run_tool(benchmark_binary, health_cmd, timeout=args.wait_timeout)
        statuses.append({"role": "health", "returncode": health.returncode})
        reset = run_tool(benchmark_binary, reset_cmd, timeout=args.wait_timeout)
        statuses.append({"role": "reset", "returncode": reset.returncode})
        if health.returncode != 0 or reset.returncode != 0:
            write_json(run_dir / "preflight-command-result.json", {
                "health": completed_to_json(health, [str(benchmark_binary), *health_cmd]),
                "reset": completed_to_json(reset, [str(benchmark_binary), *reset_cmd]),
            })
            return write_run_manifest(
                run_dir,
                run_id,
                server_name,
                service_name,
                matrix_name,
                args,
                [str(benchmark_binary), *server_cmd],
                [str(benchmark_binary), *client_cmd],
                statuses,
                bootstrap_result,
                bootout_result,
            )

        server_log = open(log_dir / "server.log", "w", encoding="utf-8")
        client_log = open(log_dir / "client-0.log", "w", encoding="utf-8")
        server = subprocess.Popen([str(benchmark_binary), *server_cmd], cwd=ROOT, env=developer_env(), stdout=server_log, stderr=subprocess.STDOUT)
        try:
            server_became_ready = wait_for_file(server_ready, args.wait_timeout)
            if not server_became_ready:
                terminate(server)
                statuses.append({"role": "server", "returncode": server.returncode, "ready": False})
                return write_run_manifest(
                    run_dir,
                    run_id,
                    server_name,
                    service_name,
                    matrix_name,
                    args,
                    [str(benchmark_binary), *server_cmd],
                    [str(benchmark_binary), *client_cmd],
                    statuses,
                    bootstrap_result,
                    bootout_result,
                )

            client = subprocess.Popen([str(benchmark_binary), *client_cmd], cwd=ROOT, env=developer_env(), stdout=client_log, stderr=subprocess.STDOUT)
            timeout = args.wait_timeout + args.warmup + args.duration + 30
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
    finally:
        bootout_result = bootout_service(plist_path)
        statuses.append({"role": "launchd-bootout", "returncode": bootout_result["returncode"]})

    return write_run_manifest(
        run_dir,
        run_id,
        server_name,
        service_name,
        matrix_name,
        args,
        [str(benchmark_binary), *server_cmd],
        [str(benchmark_binary), *client_cmd],
        statuses,
        bootstrap_result,
        bootout_result,
    )


def completed_to_json(completed, command):
    return {
        "command": command,
        "returncode": completed.returncode,
        "stdout": completed.stdout,
        "stderr": completed.stderr,
    }


def write_run_manifest(
    run_dir,
    run_id,
    server_name,
    service_name,
    matrix_name,
    args,
    server_cmd,
    client_cmd,
    statuses,
    bootstrap_result,
    bootout_result,
):
    summary_paths = [run_dir / "health.json", run_dir / "server.json", run_dir / "client-0.json"]
    summaries = []
    for path in summary_paths:
        if path.exists():
            summaries.append(json.loads(path.read_text(encoding="utf-8")))

    manifest = {
        "runId": run_id,
        "transport": "syphon26-production-xpc",
        "transportScope": "app-to-app-syphon26-production-xpc",
        "processScope": "app-to-app",
        "controlPlane": "launchd-mach-xpc",
        "handleTransport": "iosurface-xpc-object",
        "serverName": server_name,
        "serviceName": service_name,
        "matrix": matrix_name,
        "warmupSeconds": args.warmup,
        "durationSeconds": args.duration,
        "renderMode": args.render,
        "serverCommand": server_cmd,
        "clientCommands": [client_cmd] if client_cmd else [],
        "statuses": statuses,
        "launchd": {
            "plist": str(run_dir / f"{service_name}.plist"),
            "bootstrap": bootstrap_result,
            "bootout": bootout_result,
        },
        "artifacts": {
            "healthSummary": str(run_dir / "health.json"),
            "serverSummary": str(run_dir / "server.json"),
            "clientSummaries": [str(run_dir / "client-0.json")],
            "logs": str(run_dir / "logs"),
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
        build_binaries(args.configuration)
    service_binary = binary_path(args.configuration, "Syphon26ControlPlaneService")
    benchmark_binary = binary_path(args.configuration, "Syphon26ProductionXPCBenchmark")
    write_json(output_root / "environment.json", collect_environment(args.configuration))

    manifests = [run_one(benchmark_binary, service_binary, name, MATRICES[name], args, output_root) for name in matrix_names]
    top_manifest = {
        "createdAt": datetime.now().isoformat(timespec="seconds"),
        "outputDir": str(output_root),
        "runs": [
            {
                "runId": manifest["runId"],
                "transport": manifest["transport"],
                "transportScope": manifest["transportScope"],
                "processScope": manifest["processScope"],
                "controlPlane": manifest["controlPlane"],
                "handleTransport": manifest["handleTransport"],
                "serviceName": manifest["serviceName"],
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
