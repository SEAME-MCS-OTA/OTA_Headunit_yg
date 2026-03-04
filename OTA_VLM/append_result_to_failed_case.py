#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from __future__ import annotations

import json
import sys
from pathlib import Path

BASE_DIR = (Path(__file__).resolve().parent / "failed case").resolve()

KNOWN_CASES = {
    "NET_TIMEOUT",
    "DNS_FAIL",
    "HTTP_5XX",
    "HASH_MISMATCH",
    "DISK_FULL",
    "SYSTEMD_UNIT_FAILED",
    "SERVICE_CRASH",
    "POLICY_REJECT",
    "UNKNOWN",
}

SUCCESS_NAMES = {"OK", "SUCCESS", "SUCCEEDED", "PASS", "PASSED"}


def read_input(arg: str) -> list[str]:
    if arg == "-":
        return [line for line in sys.stdin.read().splitlines() if line.strip()]
    path = Path(arg)
    if path.exists():
        return [line for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
    return [arg]


def resolve_folder(rec: dict, raw: dict | None = None) -> str:
    code = str(rec.get("error", {}).get("code", "")).strip().upper()
    if not code or code == "NONE":
        code = str(rec.get("vlm", {}).get("root_cause", "")).strip().upper()
    if (not code or code == "NONE") and raw is not None:
        code = str(raw.get("error", {}).get("code", "")).strip().upper()
    if (not code or code == "NONE") and raw is not None:
        code = str(raw.get("ota", {}).get("event", "")).strip().upper()

    if code in SUCCESS_NAMES or rec.get("ota_phase") == "REPORT" and not code:
        return "SUCCESS"
    if code in KNOWN_CASES:
        return code
    if code in SUCCESS_NAMES:
        return "SUCCESS"
    return "UNKNOWN"


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: python append_result_to_failed_case.py <result_json|path|-> [raw_json|path|-]")
        return 1

    if not BASE_DIR.is_dir():
        print(f"BASE_DIR not found: {BASE_DIR}")
        return 1

    result_lines = read_input(sys.argv[1])
    if not result_lines:
        print("No result lines found.")
        return 1

    raw_lines = []
    if len(sys.argv) >= 3:
        raw_lines = read_input(sys.argv[2])
        if raw_lines and len(raw_lines) != len(result_lines):
            print("Result and raw JSONL line counts do not match.")
            return 1

    counts: dict[str, int] = {}

    for idx, line in enumerate(result_lines):
        try:
            rec = json.loads(line)
        except json.JSONDecodeError as exc:
            print(f"Invalid JSON line: {exc}")
            return 1
        raw_rec = None
        if raw_lines:
            try:
                raw_rec = json.loads(raw_lines[idx])
            except json.JSONDecodeError as exc:
                print(f"Invalid raw JSON line: {exc}")
                return 1

        folder = resolve_folder(rec, raw_rec)
        out_dir = BASE_DIR / folder
        out_dir.mkdir(exist_ok=True)
        out_path = out_dir / "result.jsonl"

        with out_path.open("a", encoding="utf-8") as f:
            f.write(json.dumps(rec, ensure_ascii=True) + "\n")

        if raw_rec is not None:
            dummy_path = out_dir / "dummy.jsonl"
            with dummy_path.open("a", encoding="utf-8") as f:
                f.write(json.dumps(raw_rec, ensure_ascii=False) + "\n")

        counts[folder] = counts.get(folder, 0) + 1

    for folder, cnt in sorted(counts.items()):
        print(f"[OK] {folder}: appended {cnt}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
