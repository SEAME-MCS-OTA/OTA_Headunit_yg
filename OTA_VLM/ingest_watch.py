#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from __future__ import annotations

import argparse
import json
import time
from pathlib import Path
import urllib.request


def load_state(path: Path) -> dict:
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}


def save_state(path: Path, state: dict) -> None:
    path.write_text(json.dumps(state, indent=2), encoding="utf-8")


def post_json(api_url: str, payload: dict) -> None:
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(api_url, data=data, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req) as resp:
        resp.read()


def read_new_lines(path: Path, state: dict) -> tuple[list[str], dict]:
    entry = state.get(str(path), {"pos": 0, "tail": ""})
    pos = int(entry.get("pos", 0))
    tail = entry.get("tail", "")

    try:
        size = path.stat().st_size
    except FileNotFoundError:
        return [], state

    if size < pos:
        pos = 0
        tail = ""

    with path.open("r", encoding="utf-8") as f:
        f.seek(pos)
        data = f.read()
        pos = f.tell()

    if not data and not tail:
        entry["pos"] = pos
        entry["tail"] = tail
        state[str(path)] = entry
        return [], state

    text = tail + data
    if not text:
        entry["pos"] = pos
        entry["tail"] = tail
        state[str(path)] = entry
        return [], state

    if text.endswith("\n"):
        complete = text
        tail = ""
    else:
        last_nl = text.rfind("\n")
        if last_nl == -1:
            tail = text
            complete = ""
        else:
            complete = text[: last_nl + 1]
            tail = text[last_nl + 1 :]

    lines = [line for line in complete.splitlines() if line.strip()]

    entry["pos"] = pos
    entry["tail"] = tail
    state[str(path)] = entry
    return lines, state


def main() -> int:
    parser = argparse.ArgumentParser(description="Watch result.jsonl files and auto-ingest to backend.")
    parser.add_argument(
        "--base-dir",
        default=str((Path(__file__).resolve().parent / "failed case").resolve()),
        help="Base folder containing case subfolders.",
    )
    parser.add_argument(
        "--api-url",
        default="http://localhost:4000/ingest",
        help="Backend ingest endpoint.",
    )
    parser.add_argument(
        "--interval",
        type=float,
        default=2.0,
        help="Polling interval in seconds.",
    )
    parser.add_argument(
        "--state-file",
        default=str((Path(__file__).resolve().parent / ".ingest_offsets.json").resolve()),
        help="Path to state file for offsets.",
    )

    args = parser.parse_args()

    base_dir = Path(args.base_dir)
    if not base_dir.is_dir():
        print(f"BASE_DIR not found: {base_dir}")
        return 1

    state_path = Path(args.state_file)
    state = load_state(state_path)

    print(f"Watching {base_dir} for result.jsonl changes...")
    while True:
        total = 0
        for path in sorted(base_dir.glob("*/result.jsonl")):
            lines, state = read_new_lines(path, state)
            for line in lines:
                try:
                    record = json.loads(line)
                except json.JSONDecodeError:
                    continue
                post_json(args.api_url, record)
                total += 1

        if total:
            print(f"[ingest] {total} new records")

        save_state(state_path, state)
        time.sleep(args.interval)


if __name__ == "__main__":
    raise SystemExit(main())
