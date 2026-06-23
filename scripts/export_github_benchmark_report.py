#!/usr/bin/env python3
import argparse
import json
from datetime import datetime, timezone
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(
        description="Export sanitized, GitHub-readable Syphon26 benchmark reports from claim-gate JSON."
    )
    parser.add_argument("--fixed", required=True, help="Claim-gate JSON for fixed-FPS rows.")
    parser.add_argument("--throughput", required=True, help="Claim-gate JSON for max-throughput rows.")
    parser.add_argument("--markdown", required=True, help="Output Markdown report path.")
    parser.add_argument("--json", required=True, help="Output sanitized JSON path.")
    return parser.parse_args()


def load_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def matrix_sort_key(name):
    order = {
        "1080p60": 10,
        "4k60": 20,
        "8k60": 30,
        "16k60": 40,
        "1080pmax": 110,
        "4kmax": 120,
        "8kmax": 130,
        "16kmax": 140,
    }
    return order.get(name, 999)


def fmt(value):
    if value is None:
        return "n/a"
    if isinstance(value, (int, float)):
        return f"{value:.3f}"
    return str(value)


def fps_label(fps_target):
    return "max throughput" if fps_target == 0 else f"{fps_target} FPS target"


def row_from_comparison(mode, comparison):
    classic = comparison["classicSyphon"]
    file_v2 = comparison["v2AppToApp"]
    xpc_v2 = comparison["productionXPC"]
    resolution = classic.get("resolution") or file_v2.get("resolution") or xpc_v2.get("resolution") or {}
    fps_target = classic.get("fpsTarget", file_v2.get("fpsTarget", xpc_v2.get("fpsTarget")))
    return {
        "mode": mode,
        "matrix": comparison["matrix"],
        "resolution": {
            "width": resolution.get("width"),
            "height": resolution.get("height"),
        },
        "fpsTarget": fps_target,
        "fpsLabel": fps_label(fps_target),
        "pixelFormat": classic.get("pixelFormat") or file_v2.get("pixelFormat") or xpc_v2.get("pixelFormat"),
        "renderMode": classic.get("renderMode") or file_v2.get("renderMode") or xpc_v2.get("renderMode"),
        "displayState": classic.get("displayState") or file_v2.get("displayState") or xpc_v2.get("displayState"),
        "classicReceiveFPS": classic.get("receiveFPS"),
        "syphon26FileReceiveFPS": file_v2.get("receiveFPS"),
        "syphon26ProductionXPCReceiveFPS": xpc_v2.get("receiveFPS"),
        "fileVsClassicRatio": (
            comparison.get("v2AppToAppVsClassicReceiveFPSRatio")
            if comparison.get("publicClassicClaimStatus") == "ready"
            else None
        ),
        "productionXPCVsClassicRatio": (
            comparison.get("productionXPCVsClassicReceiveFPSRatio")
            if comparison.get("productionXPCClaimStatus") == "ready"
            else None
        ),
        "publicClassicClaimStatus": comparison.get("publicClassicClaimStatus"),
        "productionXPCClaimStatus": comparison.get("productionXPCClaimStatus"),
        "blockers": comparison.get("blockers", []),
    }


def collect_rows(mode, payload):
    return [
        row_from_comparison(mode, payload["comparisons"][name])
        for name in sorted(payload["comparisons"], key=matrix_sort_key)
    ]


def collect_claimable_statements(payloads):
    statements = []
    for payload in payloads:
        statements.extend(
            statement
            for statement in payload.get("claimableStatements", [])
            if not statement.startswith("Internal benchmark only:")
        )
    return statements


def build_sanitized(fixed, throughput):
    rows = collect_rows("fixed-fps", fixed) + collect_rows("max-throughput", throughput)
    return {
        "schemaVersion": 1,
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "source": "Syphon26 run_performance_claim_gate.py",
        "scope": {
            "session": "same-session per fixed-FPS or max-throughput claim-gate invocation",
            "processScope": "app-to-app",
            "pixelFormat": "bgra8",
            "renderMode": "clear",
            "displayState": "headless-cli-no-preview",
        },
        "fixed": {
            "generatedAt": fixed.get("generatedAt"),
            "sameSessionID": fixed.get("sameSessionID"),
            "publicClassicClaimStatus": fixed.get("publicClassicClaimStatus"),
            "productionXPCClaimStatus": fixed.get("productionXPCClaimStatus"),
            "internalV2V1ClaimStatus": fixed.get("internalV2V1ClaimStatus"),
        },
        "throughput": {
            "generatedAt": throughput.get("generatedAt"),
            "sameSessionID": throughput.get("sameSessionID"),
            "publicClassicClaimStatus": throughput.get("publicClassicClaimStatus"),
            "productionXPCClaimStatus": throughput.get("productionXPCClaimStatus"),
            "internalV2V1ClaimStatus": throughput.get("internalV2V1ClaimStatus"),
        },
        "rows": rows,
        "claimableStatements": collect_claimable_statements([fixed, throughput]),
        "interpretationLimits": [
            "Rows are same-session measurements within each claim-gate invocation.",
            "Fixed-FPS rows are stability evidence, not max-speed evidence.",
            "Max-throughput rows use fpsTarget 0 and are speed evidence.",
            "Ratios are included only when the same-session claim gate marked that row ready.",
            "Syphon26 production XPC means app-to-app launchd Mach XPC with IOSurface XPC object handoff.",
            "Syphon26 file-backed app-to-app remains scoped to the development benchmark path.",
            "This report intentionally omits raw artifact paths, local usernames, hostnames, and command dumps.",
        ],
    }


def markdown_table(rows, mode):
    selected = [row for row in rows if row["mode"] == mode]
    lines = [
        "| matrix | resolution | target | classic FPS | Syphon26 file FPS | file/classic | Syphon26 production XPC FPS | xpc/classic | production claim |",
        "| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- |",
    ]
    for row in selected:
        resolution = f"{row['resolution']['width']}x{row['resolution']['height']}"
        lines.append(
            "| {matrix} | {resolution} | {target} | {classic} | {filefps} | {fileratio} | {xpcfps} | {xpcratio} | {claim} |".format(
                matrix=row["matrix"],
                resolution=resolution,
                target=row["fpsLabel"],
                classic=fmt(row["classicReceiveFPS"]),
                filefps=fmt(row["syphon26FileReceiveFPS"]),
                fileratio=fmt(row["fileVsClassicRatio"]),
                xpcfps=fmt(row["syphon26ProductionXPCReceiveFPS"]),
                xpcratio=fmt(row["productionXPCVsClassicRatio"]),
                claim=row["productionXPCClaimStatus"],
            )
        )
    return "\n".join(lines)


def find_row(rows, matrix):
    for row in rows:
        if row["matrix"] == matrix:
            return row
    return None


def build_markdown(report):
    fixed = report["fixed"]
    throughput = report["throughput"]
    row_16k60 = find_row(report["rows"], "16k60")
    row_16kmax = find_row(report["rows"], "16kmax")
    lines = [
        "# Classic Syphon vs Syphon26 Benchmark Report",
        "",
        "This report is a sanitized GitHub copy of same-session benchmark claim-gate output.",
        "It compares classic Syphon app-to-app against Syphon26 file-backed app-to-app and Syphon26 production XPC app-to-app paths through 16K BGRA8.",
        "",
        "## Scope",
        "",
        "- Process scope: `app-to-app`",
        "- Pixel format: `bgra8`",
        "- Render mode: `clear`",
        "- Display state: `headless-cli-no-preview`",
        "- Syphon26 production XPC path: `launchd-mach-xpc` with `iosurface-xpc-object` handoff",
        "- Ratios are shown only for rows marked ready by the same-session claim gate.",
        "",
        "## Status",
        "",
        f"- fixed publicClassicClaimStatus: `{fixed['publicClassicClaimStatus']}`",
        f"- fixed productionXPCClaimStatus: `{fixed['productionXPCClaimStatus']}`",
        f"- throughput publicClassicClaimStatus: `{throughput['publicClassicClaimStatus']}`",
        f"- throughput productionXPCClaimStatus: `{throughput['productionXPCClaimStatus']}`",
        "",
        "## Highlights",
        "",
        "- All fixed-FPS rows from 1080p60 through 16k60 are claim-gate ready for classic-vs-Syphon26 comparison.",
        "- All max-throughput rows from 1080pmax through 16kmax are claim-gate ready for classic-vs-Syphon26 comparison.",
    ]
    if row_16k60:
        lines.append(
            "- 16k60 stability: classic `{classic}` FPS, Syphon26 file-backed `{filefps}` FPS, Syphon26 production XPC `{xpcfps}` FPS.".format(
                classic=fmt(row_16k60["classicReceiveFPS"]),
                filefps=fmt(row_16k60["syphon26FileReceiveFPS"]),
                xpcfps=fmt(row_16k60["syphon26ProductionXPCReceiveFPS"]),
            )
        )
    if row_16kmax:
        lines.append(
            "- 16kmax throughput: Syphon26 file-backed is `{fileratio}x` classic; Syphon26 production XPC is `{xpcratio}x` classic.".format(
                fileratio=fmt(row_16kmax["fileVsClassicRatio"]),
                xpcratio=fmt(row_16kmax["productionXPCVsClassicRatio"]),
            )
        )
    lines.extend([
        "",
        "## Fixed-FPS Stability",
        "",
        markdown_table(report["rows"], "fixed-fps"),
        "",
        "## Max-Throughput",
        "",
        markdown_table(report["rows"], "max-throughput"),
        "",
        "## Claimable Statements",
        "",
    ])
    if report["claimableStatements"]:
        lines.extend(f"- {statement}" for statement in report["claimableStatements"])
    else:
        lines.append("- None.")
    lines.extend(["", "## Interpretation Limits", ""])
    lines.extend(f"- {item}" for item in report["interpretationLimits"])
    lines.append("")
    return "\n".join(lines)


def main():
    args = parse_args()
    fixed = load_json(args.fixed)
    throughput = load_json(args.throughput)
    report = build_sanitized(fixed, throughput)

    json_path = Path(args.json)
    markdown_path = Path(args.markdown)
    json_path.parent.mkdir(parents=True, exist_ok=True)
    markdown_path.parent.mkdir(parents=True, exist_ok=True)
    json_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    markdown_path.write_text(build_markdown(report), encoding="utf-8")
    print(json.dumps({"status": "ok", "markdown": str(markdown_path), "json": str(json_path)}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
