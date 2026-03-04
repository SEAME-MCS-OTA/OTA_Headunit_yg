#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from vLLM_practice_token_fixed import ALLOWED_ROOT_CAUSES, process_log, rule_based_infer

EMAIL_SYSTEM_DIR = (Path(__file__).resolve().parent / "Email System").resolve()
sys.path.insert(0, str(EMAIL_SYSTEM_DIR))

from email_sender import EmailSender
from rules import suggest_user_actions
from vlm_client import VLMClient

BASE_DIR = (Path(__file__).resolve().parent / "failed case").resolve()


def read_input(arg: str) -> list[str]:
    if arg == "-":
        return [line for line in sys.stdin.read().splitlines() if line.strip()]
    path = Path(arg)
    try:
        if path.exists():
            return [line for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
    except OSError:
        # Treat overly long or invalid path as inline JSON
        return [arg]
    return [arg]


def resolve_folder(code: str) -> str:
    if not code:
        return "UNKNOWN"
    code = str(code).strip().upper()
    if code in ALLOWED_ROOT_CAUSES:
        return code
    return "UNKNOWN"


def append_jsonl(path: Path, record: dict, ensure_ascii: bool) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(record, ensure_ascii=ensure_ascii) + "\n")


def process_raw_record(raw_rec: dict) -> dict:
    rule = rule_based_infer(raw_rec)
    dummy_folder = resolve_folder(rule["root_cause"])
    append_jsonl(BASE_DIR / dummy_folder / "dummy.jsonl", raw_rec, ensure_ascii=False)

    result_rec = process_log(json.dumps(raw_rec, ensure_ascii=False))
    result_folder = resolve_folder(result_rec.get("vlm", {}).get("root_cause", ""))
    append_jsonl(BASE_DIR / result_folder / "result.jsonl", result_rec, ensure_ascii=True)

    return {
        "rule": rule,
        "dummy_folder": dummy_folder,
        "result": result_rec,
        "result_folder": result_folder,
    }


def build_email_context(raw_log, final_root, actions, user_actionable):
    device = raw_log.get("device", {}) or {}
    ota = raw_log.get("ota", {}) or {}
    error = raw_log.get("error", {}) or {}
    context = raw_log.get("context", {}) or {}
    region = context.get("region", {}) or {}

    return {
        "device_id": device.get("device_id", ""),
        "model": device.get("model", ""),
        "ota_id": ota.get("ota_id", ""),
        "current_version": ota.get("current_version", ""),
        "target_version": ota.get("target_version", ""),
        "error_code": error.get("code", ""),
        "error_message": error.get("message", ""),
        "root_cause": final_root,
        "region": region,
        "user_actionable": user_actionable,
        "actions": actions,
    }


def append_email_jsonl(path: Path, record: dict, ensure_ascii: bool) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(record, ensure_ascii=ensure_ascii) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Append raw/result logs and optionally generate email output."
    )
    parser.add_argument("input", help="raw_json | jsonl_path | '-' for stdin")
    default_email_output = str(EMAIL_SYSTEM_DIR / "email_result.jsonl")
    parser.add_argument(
        "--email-output",
        default=default_email_output,
        help="output jsonl for generated emails (default: Email System/email_result.jsonl)",
    )
    parser.add_argument(
        "--no-email",
        action="store_true",
        help="disable email generation output",
    )
    parser.add_argument(
        "--send-email",
        action="store_true",
        help="send generated email via SMTP",
    )
    args = parser.parse_args()

    if not BASE_DIR.is_dir():
        print(f"BASE_DIR not found: {BASE_DIR}")
        return 1

    raw_lines = read_input(args.input)
    if not raw_lines:
        print("No input lines found.")
        return 1

    counts: dict[str, int] = {}
    email_output_path = None if args.no_email else args.email_output
    email_client = VLMClient() if email_output_path else None
    email_sender = EmailSender.from_env() if args.send_email else None

    for line in raw_lines:
        try:
            raw_rec = json.loads(line)
        except json.JSONDecodeError as exc:
            print(f"Invalid JSON line: {exc}")
            return 1

        processed = process_raw_record(raw_rec)
        counts[processed["result_folder"]] = counts.get(processed["result_folder"], 0) + 1

        if email_client:
            vlm_result = processed["result"].get("vlm", {})
            final_root = str(vlm_result.get("root_cause", "UNKNOWN")).upper()
            if final_root not in ALLOWED_ROOT_CAUSES:
                final_root = "UNKNOWN"
            action_info = suggest_user_actions(final_root, raw_rec)
            email_context = build_email_context(
                raw_rec,
                final_root,
                action_info["actions"],
                action_info["user_actionable"],
            )
            email_content = email_client.generate_email(email_context)
            email_record = {
                "final": {
                    "root_cause": final_root,
                    "user_actionable": action_info["user_actionable"],
                    "actions": action_info["actions"],
                    "center_recommended": action_info["center_recommended"],
                },
                "email": email_content,
                "email_context": email_context,
                "append_raw_and_result": {
                    "dummy_folder": processed["dummy_folder"],
                    "result_folder": processed["result_folder"],
                },
            }
            append_email_jsonl(
                Path(email_output_path),
                email_record,
                ensure_ascii=False,
            )
            if email_sender:
                email_sender.send(
                    subject=email_content.get("subject", ""),
                    body=email_content.get("body", ""),
                )

    for folder, cnt in sorted(counts.items()):
        print(f"[OK] {folder}: appended {cnt}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
