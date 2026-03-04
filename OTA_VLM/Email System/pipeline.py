import argparse
import json
import os
import sys
from pathlib import Path

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = Path(SCRIPT_DIR).resolve().parents[0]
sys.path.insert(0, SCRIPT_DIR)
sys.path.insert(0, str(ROOT_DIR))

from append_raw_and_result import process_raw_record
from rules import ALLOWED_ROOT_CAUSES, suggest_user_actions
from vlm_client import VLMClient


def parse_input(input_path):
    if input_path == "-":
        return [json.loads(line) for line in sys.stdin if line.strip()]
    with open(input_path, "r", encoding="utf-8") as f:
        if input_path.endswith(".jsonl"):
            return [json.loads(line) for line in f if line.strip()]
        return [json.loads(f.read())]


def decide_root_cause(vlm_result):
    root = str(vlm_result.get("root_cause", "UNKNOWN")).upper()
    confidence = float(vlm_result.get("confidence", 0.0) or 0.0)
    if root not in ALLOWED_ROOT_CAUSES:
        root = "UNKNOWN"
    if confidence < 0.6:
        return "UNKNOWN"
    return root


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


def process_record(raw_log, vlm_client):
    processed = process_raw_record(raw_log)
    vlm_result = processed["result"].get("vlm", {})
    final_root = decide_root_cause(vlm_result)

    action_info = suggest_user_actions(final_root, raw_log)
    email_context = build_email_context(
        raw_log,
        final_root,
        action_info["actions"],
        action_info["user_actionable"],
    )
    email_content = vlm_client.generate_email(email_context)

    return {
        "vlm": vlm_result,
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


def main():
    parser = argparse.ArgumentParser(description="Email system pipeline")
    parser.add_argument("--input", required=True, help="input log json or jsonl path, or '-'")
    parser.add_argument("--output", help="output jsonl path")
    args = parser.parse_args()

    vlm_client = VLMClient()
    records = parse_input(args.input)

    outputs = [process_record(record, vlm_client) for record in records]

    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            for item in outputs:
                f.write(json.dumps(item, ensure_ascii=False) + "\n")
    else:
        for item in outputs:
            print(json.dumps(item, ensure_ascii=False))


if __name__ == "__main__":
    main()
