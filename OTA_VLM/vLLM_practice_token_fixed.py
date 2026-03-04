#!/usr/bin/env python3
import sys
import os
import json
import requests

# =========================
# vLLM API 설정
# =========================
VLLM_API_URL = "http://210.121.152.22:9000/v1/chat/completions"
API_KEY = "81cbe888efea8c89da139c5cc8194393c1ead203e11e85a9a5a721428c5a2517" #
MODEL_NAME = "Qwen/Qwen3-VL-2B-Instruct"

SYSTEM_PROMPT = """You are a log parser. Output ONLY JSON in this schema:
{"event_id":"","ts":"","device_id":"","ota_id":"","current_version":"","target_version":"","ota_phase":"",
 "error":{"code":"","message":"","retryable":false},
 "context":{"region":{"country":"","city":"","timezone":""},
            "time":{"local":"","day_of_week":"","time_bucket":""},
            "power":{"source":"","battery_pct":0},
            "network":{"rssi_dbm":0,"latency_ms":0}},
 "evidence":{"ota_log":[],"journal_log":[],"filesystem":[],"screenshot_text":""},
 "vlm":{"root_cause":"","confidence":0.0,"supporting_evidence":[]},
 "analysis":{"tags":[],"cluster_id":"","impact":{"affected_devices":0}}}
Rules: JSON only; missing values -> empty/0/false/[].
root_cause must be one of NET_TIMEOUT, DNS_FAIL, HTTP_5XX, HASH_MISMATCH, DISK_FULL, SYSTEMD_UNIT_FAILED, SERVICE_CRASH, POLICY_REJECT, UNKNOWN.
supporting_evidence must quote exact phrases from input.
"""

ALLOWED_ROOT_CAUSES = {
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

TAG_MAP = {
    "NET_TIMEOUT": ["network"],
    "DNS_FAIL": ["network"],
    "HTTP_5XX": ["network", "server"],
    "HASH_MISMATCH": ["verify"],
    "DISK_FULL": ["storage"],
    "SYSTEMD_UNIT_FAILED": ["app"],
    "SERVICE_CRASH": ["app"],
    "POLICY_REJECT": ["policy"],
    "UNKNOWN": [],
}


def read_log_input(arg: str) -> str:
    if arg == "-":
        return sys.stdin.read()
    if os.path.exists(arg):
        with open(arg, "r", encoding="utf-8") as f:
            return f.read()
    return arg


def build_compact_prompt(raw_log: str) -> str:
    try:
        data = json.loads(raw_log)
    except json.JSONDecodeError:
        return raw_log

    compact = {
        "ts": data.get("ts", ""),
        "device": {"device_id": data.get("device", {}).get("device_id", "")},
        "ota": {
            "ota_id": data.get("ota", {}).get("ota_id", ""),
            "current_version": data.get("ota", {}).get("current_version", ""),
            "target_version": data.get("ota", {}).get("target_version", ""),
            "phase": data.get("ota", {}).get("phase", ""),
        },
        "context": {
            "region": data.get("context", {}).get("region", {}),
            "time": data.get("context", {}).get("time", {}),
            "power": {
                "source": data.get("context", {}).get("power", {}).get("source", ""),
                "battery": {
                    "pct": data.get("context", {}).get("power", {}).get("battery", {}).get("pct", 0)
                },
            },
            "network": {
                "rssi_dbm": data.get("context", {}).get("network", {}).get("rssi_dbm", 0),
                "latency_ms": data.get("context", {}).get("network", {}).get("latency_ms", 0),
            },
        },
        "error": data.get("error", {}),
        "evidence": {
            "ota_log": data.get("evidence", {}).get("ota_log", []),
            "journal_log": data.get("evidence", {}).get("journal_log", []),
            "filesystem": data.get("evidence", {}).get("filesystem", []),
            "screenshot_text": "",
        },
    }

    return json.dumps(compact, ensure_ascii=False)


def build_output_from_raw(data: dict) -> dict:
    context = data.get("context", {})
    power = context.get("power", {})
    battery = power.get("battery", {})
    network = context.get("network", {})
    region = context.get("region", {})
    time_info = context.get("time", {})

    return {
        "event_id": data.get("ota", {}).get("ota_id", ""),
        "ts": data.get("ts", ""),
        "device_id": data.get("device", {}).get("device_id", ""),
        "ota_id": data.get("ota", {}).get("ota_id", ""),
        "current_version": data.get("ota", {}).get("current_version", ""),
        "target_version": data.get("ota", {}).get("target_version", ""),
        "ota_phase": data.get("ota", {}).get("phase", ""),
        "error": {
            "code": data.get("error", {}).get("code", ""),
            "message": data.get("error", {}).get("message", ""),
            "retryable": bool(data.get("error", {}).get("retryable", False)),
        },
        "context": {
            "region": {
                "country": region.get("country", ""),
                "city": region.get("city", ""),
                "timezone": region.get("timezone", ""),
            },
            "time": {
                "local": time_info.get("local", ""),
                "day_of_week": time_info.get("day_of_week", ""),
                "time_bucket": time_info.get("time_bucket", ""),
            },
            "power": {
                "source": power.get("source", ""),
                "battery_pct": int(battery.get("pct", 0) or 0),
            },
            "network": {
                "rssi_dbm": int(network.get("rssi_dbm", 0) or 0),
                "latency_ms": int(network.get("latency_ms", 0) or 0),
            },
        },
        "evidence": {
            "ota_log": data.get("evidence", {}).get("ota_log", []) or [],
            "journal_log": data.get("evidence", {}).get("journal_log", []) or [],
            "filesystem": data.get("evidence", {}).get("filesystem", []) or [],
            "screenshot_text": "",
        },
        "vlm": {"root_cause": "", "confidence": 0.0, "supporting_evidence": []},
        "analysis": {"tags": [], "cluster_id": "", "impact": {"affected_devices": 0}},
    }


def rule_based_infer(data: dict) -> dict:
    error = data.get("error", {}) or {}
    code = str(error.get("code", "")).strip().upper()
    ota_log = data.get("evidence", {}).get("ota_log", []) or []
    journal_log = data.get("evidence", {}).get("journal_log", []) or []
    text_blob = " ".join(ota_log + journal_log).lower()

    if code in ALLOWED_ROOT_CAUSES and code != "UNKNOWN":
        root = code
        confidence = 0.9
    elif "timeout" in text_blob or "timed out" in text_blob:
        root = "NET_TIMEOUT"
        confidence = 0.75
    elif "could not resolve host" in text_blob or "dns" in text_blob:
        root = "DNS_FAIL"
        confidence = 0.75
    elif "503" in text_blob or "5xx" in text_blob or "server error" in text_blob:
        root = "HTTP_5XX"
        confidence = 0.75
    elif "sha256" in text_blob or "checksum" in text_blob:
        root = "HASH_MISMATCH"
        confidence = 0.75
    elif "no space left" in text_blob or "disk full" in text_blob:
        root = "DISK_FULL"
        confidence = 0.75
    elif "systemd" in text_blob or "exited with status=1" in text_blob:
        root = "SYSTEMD_UNIT_FAILED"
        confidence = 0.7
    elif "segmentation fault" in text_blob or "segfault" in text_blob or "core dumped" in text_blob:
        root = "SERVICE_CRASH"
        confidence = 0.7
    elif "policy" in text_blob or "driving" in text_blob or "battery" in text_blob:
        root = "POLICY_REJECT"
        confidence = 0.65
    else:
        root = "UNKNOWN"
        confidence = 0.4

    supporting = []
    for line in ota_log:
        if "FAIL" in line or "code=" in line:
            supporting.append(line)
            break
    if journal_log:
        supporting.append(journal_log[0])
    supporting = supporting[:2]

    return {
        "root_cause": root,
        "confidence": confidence,
        "supporting_evidence": supporting,
        "tags": TAG_MAP.get(root, []),
    }


def merge_vlm_result(base: dict, vlm_output: dict) -> dict:
    if not isinstance(vlm_output, dict):
        return base
    if "vlm" in vlm_output and isinstance(vlm_output["vlm"], dict):
        base["vlm"] = vlm_output["vlm"]
    if "analysis" in vlm_output and isinstance(vlm_output["analysis"], dict):
        base["analysis"] = vlm_output["analysis"]
    return base


def call_vllm(prompt: str) -> str:
    """Send prompt to vLLM Chat Completions API."""
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json",
    }

    payload = {
        "model": MODEL_NAME,
        "messages": [
            {
                "role": "system",
                "content": SYSTEM_PROMPT,
            },
            {
                "role": "user",
                "content": prompt,
            },
        ],
        "max_tokens": 256,
        "temperature": 0.2,
    }

    response = requests.post(
        VLLM_API_URL,
        headers=headers,
        data=json.dumps(payload),
        timeout=60,
    )
    response.raise_for_status()

    result = response.json()
    if "choices" not in result or not result["choices"]:
        raise ValueError(f"Unexpected response format: {json.dumps(result, ensure_ascii=False)}")
    return result["choices"][0]["message"]["content"]


def process_log(raw_log: str) -> dict:
    data = json.loads(raw_log)
    base_output = build_output_from_raw(data)

    rule = rule_based_infer(data)
    base_output["vlm"]["root_cause"] = rule["root_cause"]
    base_output["vlm"]["confidence"] = rule["confidence"]
    base_output["vlm"]["supporting_evidence"] = rule["supporting_evidence"]
    base_output["analysis"]["tags"] = rule["tags"]

    if rule["root_cause"] == "UNKNOWN" or rule["confidence"] < 0.7:
        prompt = build_compact_prompt(raw_log)
        vlm_text = call_vllm(prompt=prompt)
        try:
            vlm_json = json.loads(vlm_text)
        except json.JSONDecodeError:
            vlm_json = None
        if isinstance(vlm_json, dict):
            rc = str(vlm_json.get("vlm", {}).get("root_cause", "")).upper()
            if rc in ALLOWED_ROOT_CAUSES:
                base_output = merge_vlm_result(base_output, vlm_json)

    return base_output


def main():
    if len(sys.argv) < 2:
        print("Usage: python vLLM_practice_token_fixed.py <log_json_path_or_inline_or_->")
        sys.exit(1)

    log_input = sys.argv[1]

    try:
        raw_log = read_log_input(log_input).strip()
        if not raw_log:
            raise ValueError("Empty log input.")

        base_output = process_log(raw_log)
        print(json.dumps(base_output, ensure_ascii=False))

    except requests.HTTPError as e:
        print(f"HTTP Error: {e.response.text}")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
