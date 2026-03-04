#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from __future__ import annotations

import json
import sys
from pathlib import Path


DEFAULT_OUTPUT = {
    "event_id": "",
    "ts": "",
    "device_id": "",
    "ota_id": "",
    "current_version": "",
    "target_version": "",
    "ota_phase": "",
    "error": {"code": "", "message": "", "retryable": False},
    "context": {
        "region": {"country": "", "city": "", "timezone": ""},
        "time": {"local": "", "day_of_week": "", "time_bucket": ""},
        "power": {"source": "", "battery_pct": 0},
        "network": {"rssi_dbm": 0, "latency_ms": 0},
    },
    "evidence": {
        "ota_log": [],
        "journal_log": [],
        "filesystem": [],
        "screenshot_text": "",
    },
    "vlm": {"root_cause": "", "confidence": 0.0, "supporting_evidence": []},
    "analysis": {"tags": [], "cluster_id": "", "impact": {"affected_devices": 0}},
}


def read_input(path: str) -> str:
    if path == "-":
        return sys.stdin.read()
    candidate = Path(path)
    if candidate.exists():
        return candidate.read_text(encoding="utf-8")
    return path


def merge_dict(dst: dict, src: dict) -> dict:
    for key, value in src.items():
        if isinstance(value, dict) and isinstance(dst.get(key), dict):
            merge_dict(dst[key], value)
        else:
            dst[key] = value
    return dst


def normalize_record(raw: dict) -> dict:
    output = json.loads(json.dumps(DEFAULT_OUTPUT))
    merge_dict(output, raw)

    output["event_id"] = output["event_id"] or output.get("ota_id", "")

    # Ensure required sub-keys exist
    output.setdefault("error", DEFAULT_OUTPUT["error"])
    output.setdefault("context", DEFAULT_OUTPUT["context"])
    output.setdefault("evidence", DEFAULT_OUTPUT["evidence"])
    output.setdefault("vlm", DEFAULT_OUTPUT["vlm"])
    output.setdefault("analysis", DEFAULT_OUTPUT["analysis"])

    return output


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: python normalize_result_json.py <json_or_path_or_->")
        return 1

    raw_text = read_input(sys.argv[1]).strip()
    if not raw_text:
        print("Empty input.")
        return 1

    try:
        data = json.loads(raw_text)
    except json.JSONDecodeError as exc:
        print(f"Invalid JSON: {exc}")
        return 1

    if isinstance(data, list):
        normalized = [normalize_record(item) for item in data]
        print(json.dumps(normalized, ensure_ascii=False))
        return 0

    if not isinstance(data, dict):
        print("JSON must be an object or list of objects.")
        return 1

    normalized = normalize_record(data)
    print(json.dumps(normalized, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
