#!/usr/bin/env python3
import argparse
import json
import os
import pathlib
import platform
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone


ROOT = pathlib.Path(__file__).resolve().parents[1]
DEFAULT_CLASSIC_SCRIPT = (
    ROOT.parent / "Syphon-Framework" / "Examples" / "SyphonMetalBenchmark" / "scripts" / "run_benchmark.py"
)
DEFAULT_V2_APP_TO_APP_SCRIPT = ROOT / "scripts" / "run_v2_app_to_app_benchmark.py"
DEFAULT_PRODUCTION_XPC_SCRIPT = ROOT / "scripts" / "run_production_xpc_benchmark.py"

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

CLASSIC_SCRIPT_MATRICES = {
    "1080p60",
    "1080pmax",
    "4k60",
    "4kmax",
}


def parse_args():
    parser = argparse.ArgumentParser(
        description="Run same-session Syphon26 v2, v1, and classic Syphon measurements and gate claim readiness."
    )
    parser.add_argument("--matrix", default="1080p60", help=f"Comma-separated matrices: {', '.join(sorted(MATRICES))}")
    parser.add_argument("--duration", type=float, default=1.0)
    parser.add_argument("--warmup", type=float, default=0.25)
    parser.add_argument("--configuration", default="release", choices=["debug", "release"])
    parser.add_argument("--render", default="clear", choices=["clear", "none"])
    parser.add_argument("--v1-ref", default="v1")
    parser.add_argument("--v2-app-to-app-script", default=str(DEFAULT_V2_APP_TO_APP_SCRIPT))
    parser.add_argument("--production-xpc-script", default=str(DEFAULT_PRODUCTION_XPC_SCRIPT))
    parser.add_argument("--classic-script", default=str(DEFAULT_CLASSIC_SCRIPT))
    parser.add_argument("--skip-classic", action="store_true")
    parser.add_argument("--output", default=str(ROOT / "benchmark-reports" / "performance-claim-gate"))
    parser.add_argument("--require-public-claim", action="store_true")
    parser.add_argument("--require-production-xpc-claim", action="store_true")
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


def swift_run_prefix(configuration):
    command = ["swift", "run"]
    if configuration == "release":
        command.extend(["-c", "release"])
    return command


def run_capture(command, cwd, env=None):
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


def extract_json(stdout):
    start = stdout.find("{")
    end = stdout.rfind("}")
    if start < 0 or end < start:
        raise ValueError("stdout did not contain a JSON object")
    return json.loads(stdout[start : end + 1])


def short_text(value, limit=4000):
    if len(value) <= limit:
        return value
    return value[-limit:]


def write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def normalize_v2(matrix_name, raw, raw_path):
    return {
        "status": "ok",
        "implementation": "v2",
        "matrix": matrix_name,
        "transportScope": raw["transportScope"],
        "processScope": "in-process",
        "displayState": "headless-cli-no-preview",
        "measurementMode": raw.get("measurementMode", "unknown"),
        "resolution": raw["resolution"],
        "pixelFormat": canonical_pixel_format(raw["pixelFormat"]),
        "fpsTarget": raw["fpsTarget"],
        "renderMode": raw.get("renderMode", "unknown"),
        "frameCount": raw["frameCount"],
        "publishFPS": raw["publishFPS"],
        "receiveFPS": raw["receiveFPS"],
        "missedFrames": raw["missedFrames"],
        "repeatedReads": raw["repeatedReads"],
        "latencyNanosecondsAverage": raw["latencyNanosecondsAverage"],
        "cpuUserSeconds": raw["cpuUserSeconds"],
        "cpuSystemSeconds": raw["cpuSystemSeconds"],
        "memoryMaxRSSBytes": raw["memoryMaxRSSBytes"],
        "gpuWaitNanoseconds": raw["gpuWaitNanoseconds"],
        "artifact": str(raw_path),
    }


def normalize_v1(matrix_name, raw, raw_path):
    return {
        "status": "ok",
        "implementation": "v1",
        "matrix": matrix_name,
        "transportScope": "in-process-server-client",
        "processScope": "in-process",
        "displayState": "headless-cli-no-preview",
        "measurementMode": "duration",
        "resolution": {"width": raw["width"], "height": raw["height"]},
        "pixelFormat": canonical_pixel_format(raw["pixelFormat"]),
        "fpsTarget": raw["fpsTarget"],
        "renderMode": "clear",
        "frameCount": raw["serverFrames"],
        "publishFPS": raw["serverFPS"],
        "receiveFPS": raw["minClientFPS"],
        "missedFrames": raw["maxMissedFrames"],
        "repeatedReads": raw["maxRepeatedReads"],
        "latencyNanosecondsAverage": None,
        "cpuUserSeconds": None,
        "cpuSystemSeconds": None,
        "memoryMaxRSSBytes": None,
        "gpuWaitNanoseconds": raw["maxClientGPUWaitNanoseconds"],
        "artifact": str(raw_path),
    }


def normalize_classic(matrix_name, run_dir):
    server_path = run_dir / "server.json"
    client_path = run_dir / "client-0.json"
    server = json.loads(server_path.read_text(encoding="utf-8"))
    client = json.loads(client_path.read_text(encoding="utf-8"))
    return {
        "status": "ok",
        "implementation": "classic-syphon",
        "matrix": matrix_name,
        "transportScope": "app-to-app-syphon-metal",
        "processScope": "app-to-app",
        "displayState": "headless-cli-no-preview",
        "measurementMode": "duration",
        "resolution": {"width": server["width"], "height": server["height"]},
        "pixelFormat": canonical_pixel_format(server["pixelFormat"]),
        "fpsTarget": server["targetFPS"],
        "renderMode": "clear",
        "frameCount": client["measuredObservedFrames"],
        "publishFPS": server["measuredSubmittedFPS"],
        "receiveFPS": client["measuredObservedFPS"],
        "missedFrames": None,
        "repeatedReads": None,
        "latencyNanosecondsAverage": None,
        "cpuUserSeconds": None,
        "cpuSystemSeconds": None,
        "memoryMaxRSSBytes": None,
        "gpuWaitNanoseconds": None,
        "artifact": str(run_dir / "manifest.json"),
    }


def normalize_v2_app_to_app(matrix_name, run_dir):
    server_path = run_dir / "server.json"
    client_path = run_dir / "client-0.json"
    server = json.loads(server_path.read_text(encoding="utf-8"))
    client = json.loads(client_path.read_text(encoding="utf-8"))
    return {
        "status": "ok",
        "implementation": "v2-app-to-app",
        "matrix": matrix_name,
        "transportScope": server["transportScope"],
        "processScope": server["processScope"],
        "displayState": "headless-cli-no-preview",
        "measurementMode": "duration",
        "resolution": {"width": server["width"], "height": server["height"]},
        "pixelFormat": canonical_pixel_format(server["pixelFormat"]),
        "fpsTarget": server["targetFPS"],
        "renderMode": "clear",
        "frameCount": client["measuredObservedFrames"],
        "publishFPS": server["measuredSubmittedFPS"],
        "receiveFPS": client["measuredObservedFPS"],
        "missedFrames": client["missedFrames"],
        "repeatedReads": client["repeatedReads"],
        "latencyNanosecondsAverage": None,
        "cpuUserSeconds": client["cpuUserSeconds"],
        "cpuSystemSeconds": client["cpuSystemSeconds"],
        "memoryMaxRSSBytes": client["memoryMaxRSSBytes"],
        "gpuWaitNanoseconds": None,
        "artifact": str(run_dir / "manifest.json"),
    }


def normalize_production_xpc(matrix_name, run_dir):
    server_path = run_dir / "server.json"
    client_path = run_dir / "client-0.json"
    server = json.loads(server_path.read_text(encoding="utf-8"))
    client = json.loads(client_path.read_text(encoding="utf-8"))
    return {
        "status": "ok",
        "implementation": "v2-production-xpc",
        "matrix": matrix_name,
        "transportScope": server["transportScope"],
        "processScope": server["processScope"],
        "controlPlane": server.get("controlPlane"),
        "handleTransport": server.get("handleTransport"),
        "displayState": "headless-cli-no-preview",
        "measurementMode": "duration",
        "resolution": {"width": server["width"], "height": server["height"]},
        "pixelFormat": canonical_pixel_format(server["pixelFormat"]),
        "fpsTarget": server["targetFPS"],
        "renderMode": "clear",
        "frameCount": client["measuredObservedFrames"],
        "publishFPS": server["measuredSubmittedFPS"],
        "receiveFPS": client["measuredObservedFPS"],
        "missedFrames": client["missedFrames"],
        "repeatedReads": client["repeatedReads"],
        "latencyNanosecondsAverage": None,
        "cpuUserSeconds": client["cpuUserSeconds"],
        "cpuSystemSeconds": client["cpuSystemSeconds"],
        "memoryMaxRSSBytes": client["memoryMaxRSSBytes"],
        "gpuWaitNanoseconds": None,
        "artifact": str(run_dir / "manifest.json"),
    }


def failed_case(implementation, matrix_name, result, reason):
    return {
        "status": "failed",
        "implementation": implementation,
        "matrix": matrix_name,
        "reason": reason,
        "command": result.get("command", []),
        "cwd": result.get("cwd", ""),
        "returncode": result.get("returncode"),
        "stdoutTail": short_text(result.get("stdout", "")),
        "stderrTail": short_text(result.get("stderr", "")),
    }


def run_v2_cases(matrix_names, args, output_root):
    cases = {}
    for matrix_name in matrix_names:
        matrix = MATRICES[matrix_name]
        command = swift_run_prefix(args.configuration) + [
            "Syphon26Benchmark",
            "--width",
            str(matrix["width"]),
            "--height",
            str(matrix["height"]),
            "--fps-target",
            str(matrix["fps"]),
            "--duration",
            str(args.duration),
            "--warmup",
            str(args.warmup),
            "--render",
            args.render,
            "--json",
        ]
        result = run_capture(command, ROOT)
        if result["returncode"] != 0:
            cases[matrix_name] = failed_case("v2", matrix_name, result, "v2 benchmark command failed")
            continue
        try:
            raw = json.loads(result["stdout"].splitlines()[-1])
        except Exception as exc:
            cases[matrix_name] = failed_case("v2", matrix_name, result, f"could not parse v2 JSON: {exc}")
            continue
        raw_path = output_root / "v2" / f"{matrix_name}.json"
        write_json(raw_path, {"raw": raw, "commandResult": result})
        cases[matrix_name] = normalize_v2(matrix_name, raw, raw_path)
    return cases


def run_v1_cases(matrix_names, args, output_root):
    cases = {}
    worktree_path = pathlib.Path(tempfile.mkdtemp(prefix="syphon26-v1-claim."))
    worktree_added = False
    add_result = run_capture(["git", "worktree", "add", "--detach", str(worktree_path), args.v1_ref], ROOT)
    if add_result["returncode"] != 0:
        shutil.rmtree(worktree_path, ignore_errors=True)
        for matrix_name in matrix_names:
            cases[matrix_name] = failed_case("v1", matrix_name, add_result, "could not create v1 worktree")
        return cases
    worktree_added = True

    try:
        for matrix_name in matrix_names:
            matrix = MATRICES[matrix_name]
            run_output = output_root / "v1" / matrix_name
            command = swift_run_prefix(args.configuration) + [
                "Syphon26Benchmark",
                "--width",
                str(matrix["width"]),
                "--height",
                str(matrix["height"]),
                "--fps",
                str(matrix["fps"]),
                "--warmup",
                str(args.warmup),
                "--duration",
                str(args.duration),
                "--clients",
                "1",
                "--pixel-format",
                matrix["pixelFormat"],
                "--render",
                args.render,
                "--output",
                str(run_output),
            ]
            result = run_capture(command, worktree_path)
            if result["returncode"] != 0:
                cases[matrix_name] = failed_case("v1", matrix_name, result, "v1 benchmark command failed")
                continue
            try:
                raw = extract_json(result["stdout"])
            except Exception as exc:
                cases[matrix_name] = failed_case("v1", matrix_name, result, f"could not parse v1 JSON: {exc}")
                continue
            raw_path = run_output / "syphon26-benchmark.json"
            cases[matrix_name] = normalize_v1(matrix_name, raw, raw_path)
    finally:
        if worktree_added:
            run_capture(["git", "worktree", "remove", "--force", str(worktree_path)], ROOT)
            run_capture(["git", "worktree", "prune"], ROOT)
        else:
            shutil.rmtree(worktree_path, ignore_errors=True)

    return cases


def run_v2_app_to_app_cases(matrix_names, args, output_root):
    script = pathlib.Path(args.v2_app_to_app_script)
    if not script.exists():
        return {
            name: {
                "status": "failed",
                "implementation": "v2-app-to-app",
                "matrix": name,
                "reason": f"v2 app-to-app benchmark script not found at {script}",
            }
            for name in matrix_names
        }

    app_output = output_root / "v2-app-to-app"
    command = [
        sys.executable,
        str(script),
        "--matrix",
        ",".join(matrix_names),
        "--duration",
        str(args.duration),
        "--warmup",
        str(args.warmup),
        "--configuration",
        args.configuration,
        "--render",
        args.render,
        "--poll-us",
        "0",
        "--output-dir",
        str(app_output),
    ]
    result = run_capture(command, ROOT)
    cases = {}
    if result["returncode"] != 0:
        for matrix_name in matrix_names:
            cases[matrix_name] = failed_case(
                "v2-app-to-app",
                matrix_name,
                result,
                "v2 app-to-app benchmark command failed",
            )
        return cases

    try:
        top_manifest = json.loads(result["stdout"][result["stdout"].find("{") :])
    except Exception as exc:
        for matrix_name in matrix_names:
            cases[matrix_name] = failed_case(
                "v2-app-to-app",
                matrix_name,
                result,
                f"could not parse v2 app-to-app top manifest: {exc}",
            )
        return cases

    write_json(app_output / "command-result.json", {"commandResult": result, "topManifest": top_manifest})
    for run in top_manifest.get("runs", []):
        run_dir = pathlib.Path(run["manifest"]).parent
        manifest = json.loads(pathlib.Path(run["manifest"]).read_text(encoding="utf-8"))
        for summary in manifest.get("summaries", []):
            if summary.get("role") == "server":
                matrix_name = matrix_name_for(summary["width"], summary["height"], summary["targetFPS"])
                if matrix_name in matrix_names:
                    cases[matrix_name] = normalize_v2_app_to_app(matrix_name, run_dir)

    for matrix_name in matrix_names:
        cases.setdefault(
            matrix_name,
            {
                "status": "failed",
                "implementation": "v2-app-to-app",
                "matrix": matrix_name,
                "reason": "v2 app-to-app run completed but expected matrix summary was not found",
            },
        )
    return cases


def run_production_xpc_cases(matrix_names, args, output_root):
    script = pathlib.Path(args.production_xpc_script)
    if not script.exists():
        return {
            name: {
                "status": "failed",
                "implementation": "v2-production-xpc",
                "matrix": name,
                "reason": f"production XPC benchmark script not found at {script}",
            }
            for name in matrix_names
        }

    xpc_output = output_root / "production-xpc"
    command = [
        sys.executable,
        str(script),
        "--matrix",
        ",".join(matrix_names),
        "--duration",
        str(args.duration),
        "--warmup",
        str(args.warmup),
        "--configuration",
        args.configuration,
        "--render",
        args.render,
        "--poll-us",
        "0",
        "--output-dir",
        str(xpc_output),
    ]
    result = run_capture(command, ROOT)
    cases = {}
    if result["returncode"] != 0:
        for matrix_name in matrix_names:
            cases[matrix_name] = failed_case(
                "v2-production-xpc",
                matrix_name,
                result,
                "production XPC benchmark command failed",
            )
        return cases

    try:
        top_manifest = json.loads(result["stdout"][result["stdout"].find("{") :])
    except Exception as exc:
        for matrix_name in matrix_names:
            cases[matrix_name] = failed_case(
                "v2-production-xpc",
                matrix_name,
                result,
                f"could not parse production XPC top manifest: {exc}",
            )
        return cases

    write_json(xpc_output / "command-result.json", {"commandResult": result, "topManifest": top_manifest})
    for run in top_manifest.get("runs", []):
        run_dir = pathlib.Path(run["manifest"]).parent
        manifest = json.loads(pathlib.Path(run["manifest"]).read_text(encoding="utf-8"))
        for summary in manifest.get("summaries", []):
            if summary.get("role") == "server":
                matrix_name = matrix_name_for(summary["width"], summary["height"], summary["targetFPS"])
                if matrix_name in matrix_names:
                    cases[matrix_name] = normalize_production_xpc(matrix_name, run_dir)

    for matrix_name in matrix_names:
        cases.setdefault(
            matrix_name,
            {
                "status": "failed",
                "implementation": "v2-production-xpc",
                "matrix": matrix_name,
                "reason": "production XPC run completed but expected matrix summary was not found",
            },
        )
    return cases


def run_classic_cases(matrix_names, args, output_root):
    if args.skip_classic:
        return {
            name: {
                "status": "skipped",
                "implementation": "classic-syphon",
                "matrix": name,
                "reason": "classic benchmark skipped by --skip-classic",
            }
            for name in matrix_names
        }

    supported_matrix_names = [name for name in matrix_names if name in CLASSIC_SCRIPT_MATRICES]
    unsupported_matrix_names = [name for name in matrix_names if name not in CLASSIC_SCRIPT_MATRICES]
    cases = {
        name: {
            "status": "failed",
            "implementation": "classic-syphon",
            "matrix": name,
            "reason": f"classic benchmark script does not define matrix {name}",
        }
        for name in unsupported_matrix_names
    }
    if not supported_matrix_names:
        return cases

    script = pathlib.Path(args.classic_script)
    if not script.exists():
        cases.update({
            name: {
                "status": "failed",
                "implementation": "classic-syphon",
                "matrix": name,
                "reason": f"classic benchmark script not found at {script}",
            }
            for name in supported_matrix_names
        })
        return cases

    classic_output = output_root / "classic-syphon"
    command = [
        sys.executable,
        str(script),
        "--transport",
        "syphon",
        "--matrix",
        ",".join(supported_matrix_names),
        "--duration",
        str(args.duration),
        "--warmup",
        str(args.warmup),
        "--clients",
        "1",
        "--poll-us",
        "0",
        "--csv-every",
        "100",
        "--output-dir",
        str(classic_output),
    ]
    result = run_capture(command, script.parent.parent)
    if result["returncode"] != 0:
        for matrix_name in supported_matrix_names:
            cases[matrix_name] = failed_case(
                "classic-syphon",
                matrix_name,
                result,
                "classic Syphon benchmark command failed",
            )
        return cases

    try:
        top_manifest = json.loads(result["stdout"][result["stdout"].find("{") :])
    except Exception as exc:
        for matrix_name in supported_matrix_names:
            cases[matrix_name] = failed_case(
                "classic-syphon",
                matrix_name,
                result,
                f"could not parse classic top manifest: {exc}",
            )
        return cases

    write_json(classic_output / "command-result.json", {"commandResult": result, "topManifest": top_manifest})
    for run in top_manifest.get("runs", []):
        run_dir = pathlib.Path(run["manifest"]).parent
        manifest = json.loads(pathlib.Path(run["manifest"]).read_text(encoding="utf-8"))
        for summary in manifest.get("summaries", []):
            if summary.get("role") == "server":
                matrix_name = matrix_name_for(summary["width"], summary["height"], summary["targetFPS"])
                if matrix_name in supported_matrix_names:
                    cases[matrix_name] = normalize_classic(matrix_name, run_dir)

    for matrix_name in supported_matrix_names:
        cases.setdefault(
            matrix_name,
            {
                "status": "failed",
                "implementation": "classic-syphon",
                "matrix": matrix_name,
                "reason": "classic run completed but expected matrix summary was not found",
            },
        )
    return cases


def matrix_name_for(width, height, fps):
    for name, matrix in MATRICES.items():
        if matrix["width"] == width and matrix["height"] == height and matrix["fps"] == fps:
            return name
    return f"{width}x{height}@{fps}"


def canonical_pixel_format(value):
    normalized = str(value).lower().replace("_", "").replace("-", "")
    if normalized in {"bgra8", "bgra8unorm"}:
        return "bgra8"
    if normalized in {"rgba16f", "rgba16float"}:
        return "rgba16f"
    return str(value)


def comparable_shape(left, right):
    return (
        left.get("status") == "ok"
        and right.get("status") == "ok"
        and left.get("resolution") == right.get("resolution")
        and left.get("pixelFormat") == right.get("pixelFormat")
        and left.get("fpsTarget") == right.get("fpsTarget")
        and left.get("renderMode") == right.get("renderMode")
        and left.get("displayState") == right.get("displayState")
    )


def ratio(numerator, denominator):
    if denominator in (None, 0):
        return None
    return numerator / denominator


def aggregate_status(matrix_names, claimable):
    if len(claimable) == len(matrix_names):
        return "ready"
    if claimable:
        return "partial"
    return "blocked"


def build_comparisons(matrix_names, v2_cases, v2_app_to_app_cases, production_xpc_cases, v1_cases, classic_cases):
    comparisons = {}
    blockers = []
    internal_claimable = []
    public_claimable = []
    production_claimable = []

    for matrix_name in matrix_names:
        v2 = v2_cases[matrix_name]
        v1 = v1_cases[matrix_name]
        classic = classic_cases[matrix_name]
        v2_app_to_app = v2_app_to_app_cases[matrix_name]
        production_xpc = production_xpc_cases[matrix_name]
        comparison = {
            "matrix": matrix_name,
            "v2": v2,
            "v2AppToApp": v2_app_to_app,
            "productionXPC": production_xpc,
            "v1": v1,
            "classicSyphon": classic,
            "v2VsV1ReceiveFPSRatio": None,
            "v2AppToAppVsClassicReceiveFPSRatio": None,
            "productionXPCVsClassicReceiveFPSRatio": None,
            "v2VsClassicReceiveFPSRatio": None,
            "internalV2V1ClaimStatus": "blocked",
            "publicClassicClaimStatus": "blocked",
            "productionXPCClaimStatus": "blocked",
            "blockers": [],
        }

        if comparable_shape(v2, v1):
            comparison["v2VsV1ReceiveFPSRatio"] = ratio(v2["receiveFPS"], v1["receiveFPS"])
            comparison["internalV2V1ClaimStatus"] = "ready"
            internal_claimable.append(matrix_name)
        else:
            comparison["blockers"].append("v2 and v1 measurements are missing, failed, or not shape-compatible")

        if comparable_shape(v2_app_to_app, classic):
            comparison["v2AppToAppVsClassicReceiveFPSRatio"] = ratio(v2_app_to_app["receiveFPS"], classic["receiveFPS"])
            comparison["v2VsClassicReceiveFPSRatio"] = comparison["v2AppToAppVsClassicReceiveFPSRatio"]
            if v2_app_to_app.get("processScope") == classic.get("processScope") == "app-to-app":
                comparison["publicClassicClaimStatus"] = "ready"
                public_claimable.append(matrix_name)
            else:
                comparison["blockers"].append(
                    f"v2 process scope {v2_app_to_app.get('processScope')} differs from classic process scope {classic.get('processScope')}"
                )
        else:
            comparison["blockers"].append("v2 app-to-app and classic measurements are missing, failed, or not shape-compatible")

        if comparable_shape(production_xpc, classic):
            comparison["productionXPCVsClassicReceiveFPSRatio"] = ratio(production_xpc["receiveFPS"], classic["receiveFPS"])
            if (
                production_xpc.get("processScope") == classic.get("processScope") == "app-to-app"
                and production_xpc.get("controlPlane") == "launchd-mach-xpc"
                and production_xpc.get("handleTransport") == "iosurface-xpc-object"
            ):
                comparison["productionXPCClaimStatus"] = "ready"
                production_claimable.append(matrix_name)
            else:
                comparison["blockers"].append(
                    "production XPC row did not report app-to-app launchd-mach-xpc with iosurface-xpc-object handle transport"
                )
        else:
            comparison["blockers"].append("production XPC and classic measurements are missing, failed, or not shape-compatible")

        blockers.extend(f"{matrix_name}: {item}" for item in comparison["blockers"])
        comparisons[matrix_name] = comparison

    if not internal_claimable:
        blockers.append("No same-session v2-v1 internal comparison is claim-ready.")
    if not public_claimable:
        blockers.append("No public v2-vs-classic performance claim is ready.")
    if not production_claimable:
        blockers.append("No production XPC v2-vs-classic performance claim is ready.")

    return comparisons, blockers, internal_claimable, public_claimable, production_claimable


def build_markdown(payload):
    lines = [
        "# Syphon26 Performance Claim Gate",
        "",
        f"- generatedAt: `{payload['generatedAt']}`",
        f"- sameSessionID: `{payload['sameSessionID']}`",
        f"- publicClassicClaimStatus: `{payload['publicClassicClaimStatus']}`",
        f"- productionXPCClaimStatus: `{payload['productionXPCClaimStatus']}`",
        f"- internalV2V1ClaimStatus: `{payload['internalV2V1ClaimStatus']}`",
        "",
        "| matrix | v2 file scope | v2 file FPS | production XPC FPS | v1 FPS | classic FPS | file/classic | xpc/classic | production claim |",
        "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |",
    ]
    for comparison in payload["comparisons"].values():
        v2_app_to_app = comparison["v2AppToApp"]
        production_xpc = comparison["productionXPC"]
        v1 = comparison["v1"]
        classic = comparison["classicSyphon"]
        lines.append(
            "| {matrix} | {scope} | {v2filefps} | {xpcfps} | {v1fps} | {classicfps} | {fileclassic} | {xpcclassic} | {claim} |".format(
                matrix=comparison["matrix"],
                scope=v2_app_to_app.get("transportScope", v2_app_to_app.get("status", "n/a")),
                v2filefps=format_number(v2_app_to_app.get("receiveFPS")),
                xpcfps=format_number(production_xpc.get("receiveFPS")),
                v1fps=format_number(v1.get("receiveFPS")),
                classicfps=format_number(classic.get("receiveFPS")),
                fileclassic=format_number(comparison.get("v2AppToAppVsClassicReceiveFPSRatio")),
                xpcclassic=format_number(comparison.get("productionXPCVsClassicReceiveFPSRatio")),
                claim=comparison["productionXPCClaimStatus"],
            )
        )

    lines.extend(["", "## Claimable Statements", ""])
    if payload["claimableStatements"]:
        lines.extend(f"- {item}" for item in payload["claimableStatements"])
    else:
        lines.append("- None.")

    lines.extend(["", "## Blockers", ""])
    if payload["blockers"]:
        lines.extend(f"- {item}" for item in payload["blockers"])
    else:
        lines.append("- None.")

    lines.extend(["", "## Interpretation Limits", ""])
    lines.extend(f"- {item}" for item in payload["interpretationLimits"])
    return "\n".join(lines) + "\n"


def format_number(value):
    if value is None:
        return "n/a"
    return f"{value:.3f}"


def build_claimable_statements(comparisons, internal_claimable, public_claimable, production_claimable):
    statements = []
    for matrix_name in internal_claimable:
        comparison = comparisons[matrix_name]
        ratio_value = comparison["v2VsV1ReceiveFPSRatio"]
        statements.append(
            "Internal benchmark only: in the same-session {matrix} in-process run, v2 transport-core receive FPS was {ratio:.3f}x v1 server/client receive FPS. Do not present this as an app-to-app or classic Syphon claim.".format(
                matrix=matrix_name,
                ratio=ratio_value,
            )
        )
    for matrix_name in public_claimable:
        comparison = comparisons[matrix_name]
        ratio_value = comparison["v2AppToAppVsClassicReceiveFPSRatio"]
        v2_app = comparison["v2AppToApp"]
        if v2_app.get("fpsTarget") == 0:
            statements.append(
                "Public classic throughput comparison: in the same-session {matrix} app-to-app benchmark, the v2 file-backed Syphon26 path received frames at {ratio:.3f}x classic Syphon receive FPS under matched resolution, pixel format, render mode, process scope, and display state.".format(
                    matrix=matrix_name,
                    ratio=ratio_value,
                )
            )
        else:
            statements.append(
                "Public classic fixed-FPS stability comparison: in the same-session {matrix} app-to-app benchmark, the v2 file-backed Syphon26 path received frames at {ratio:.3f}x classic Syphon receive FPS against the {fps} FPS target under matched resolution, pixel format, render mode, process scope, and display state.".format(
                    matrix=matrix_name,
                    ratio=ratio_value,
                    fps=v2_app.get("fpsTarget"),
                )
            )
    for matrix_name in production_claimable:
        comparison = comparisons[matrix_name]
        ratio_value = comparison["productionXPCVsClassicReceiveFPSRatio"]
        production_xpc = comparison["productionXPC"]
        if production_xpc.get("fpsTarget") == 0:
            statements.append(
                "Production XPC throughput comparison: in the same-session {matrix} app-to-app benchmark, the v2 launchd production XPC path using IOSurface XPC object handoff received frames at {ratio:.3f}x classic Syphon receive FPS under matched resolution, pixel format, render mode, process scope, and display state.".format(
                    matrix=matrix_name,
                    ratio=ratio_value,
                )
            )
        else:
            statements.append(
                "Production XPC fixed-FPS stability comparison: in the same-session {matrix} app-to-app benchmark, the v2 launchd production XPC path using IOSurface XPC object handoff received frames at {ratio:.3f}x classic Syphon receive FPS against the {fps} FPS target under matched resolution, pixel format, render mode, process scope, and display state.".format(
                    matrix=matrix_name,
                    ratio=ratio_value,
                    fps=production_xpc.get("fpsTarget"),
                )
            )
    return statements


def main():
    args = parse_args()
    matrix_names = selected_matrices(args.matrix)
    output_root = pathlib.Path(args.output).resolve()
    output_root.mkdir(parents=True, exist_ok=True)

    same_session_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    v2_cases = run_v2_cases(matrix_names, args, output_root)
    v2_app_to_app_cases = run_v2_app_to_app_cases(matrix_names, args, output_root)
    production_xpc_cases = run_production_xpc_cases(matrix_names, args, output_root)
    v1_cases = run_v1_cases(matrix_names, args, output_root)
    classic_cases = run_classic_cases(matrix_names, args, output_root)
    comparisons, blockers, internal_claimable, public_claimable, production_claimable = build_comparisons(
        matrix_names,
        v2_cases,
        v2_app_to_app_cases,
        production_xpc_cases,
        v1_cases,
        classic_cases,
    )
    claimable_statements = build_claimable_statements(comparisons, internal_claimable, public_claimable, production_claimable)

    payload = {
        "schemaVersion": 1,
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "sameSessionID": same_session_id,
        "runnerEnvironment": {
            "host": platform.node(),
            "platform": platform.platform(),
            "python": platform.python_version(),
            "root": str(ROOT),
            "v2AppToAppScript": str(args.v2_app_to_app_script),
            "productionXPCScript": str(args.production_xpc_script),
            "classicScript": str(args.classic_script),
            "configuration": args.configuration,
            "durationSeconds": args.duration,
            "warmupSeconds": args.warmup,
            "renderMode": args.render,
        },
        "internalV2V1ClaimStatus": aggregate_status(matrix_names, internal_claimable),
        "publicClassicClaimStatus": aggregate_status(matrix_names, public_claimable),
        "productionXPCClaimStatus": aggregate_status(matrix_names, production_claimable),
        "comparisons": comparisons,
        "claimableStatements": claimable_statements,
        "blockers": blockers,
        "interpretationLimits": [
            "All rows are same-script, same-session measurements from this runner invocation.",
            "Internal v2-v1 rows compare v2 transport-core against v1 server/client and are not public classic Syphon claims.",
            "Public classic performance claims use the v2 app-to-app benchmark row and require matching process scope, resolution, pixel format, FPS target, render mode, and display state.",
            "The file-backed v2 public-ready row remains scoped to the development app-to-app benchmark path.",
            "Production XPC claims require the v2 production XPC row to report app-to-app launchd-mach-xpc control plane and iosurface-xpc-object handle transport.",
            "Classic Syphon 8K/16K rows remain blocked until the sibling classic benchmark runner defines matching 8K/16K matrix names or an equivalent same-session classic run is provided.",
            "Fixed-FPS rows are stability evidence. Throughput rows with fpsTarget 0 are speed evidence.",
            "Reports under benchmark-reports are generated artifacts and are intentionally not committed.",
        ],
    }

    json_path = output_root / "latest.json"
    markdown_path = output_root / "latest.md"
    write_json(json_path, payload)
    markdown_path.write_text(build_markdown(payload), encoding="utf-8")

    result = {
        "status": "ok",
        "jsonReport": str(json_path),
        "markdownReport": str(markdown_path),
        "internalV2V1ClaimStatus": payload["internalV2V1ClaimStatus"],
        "publicClassicClaimStatus": payload["publicClassicClaimStatus"],
        "productionXPCClaimStatus": payload["productionXPCClaimStatus"],
        "blockerCount": len(blockers),
    }
    print(json.dumps(result, sort_keys=True))
    if args.require_public_claim and payload["publicClassicClaimStatus"] not in {"ready", "partial"}:
        return 2
    if args.require_production_xpc_claim and payload["productionXPCClaimStatus"] != "ready":
        return 3
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
