import json
import os
import time
import threading
import subprocess
from datetime import datetime
from typing import Dict, Any, List, Optional

import requests

PHASE_DOWNLOAD = "DOWNLOAD"
PHASE_APPLY = "APPLY"
PHASE_REBOOT = "REBOOT"
PHASE_COMMIT = "COMMIT"

EVENT_START = "START"
EVENT_OK = "OK"
EVENT_FAIL = "FAIL"

class OtaState:
    def __init__(self):
        self.current_version = "unknown"
        self.target_version = None
        self.phase = None
        self.event = None
        self.last_error = None
        self.active_ota_id = None

state = OtaState()

def load_config(path: str) -> Dict[str, Any]:
    if not os.path.exists(path):
        return {}
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)

def _now_ts() -> str:
    return datetime.now().astimezone().isoformat(timespec="seconds")

def _day_of_week() -> str:
    return datetime.now().strftime("%a")

def _time_bucket() -> str:
    hour = datetime.now().hour
    if 6 <= hour < 12:
        return "MORNING"
    if 12 <= hour < 18:
        return "AFTERNOON"
    if 18 <= hour < 22:
        return "EVENING"
    return "NIGHT"

def _safe_journal(unit: str, lines: int = 50) -> List[str]:
    try:
        out = subprocess.check_output(
            ["journalctl", "-u", unit, "-n", str(lines), "--no-pager"],
            text=True,
        )
        return [line.strip() for line in out.splitlines() if line.strip()]
    except Exception:
        return []

def _filesystem_evidence(path: str) -> List[Dict[str, Any]]:
    try:
        stat = os.statvfs(path)
        free = stat.f_bavail * stat.f_frsize
        total = stat.f_blocks * stat.f_frsize
        return [{"path": path, "free_bytes": free, "total_bytes": total}]
    except Exception:
        return []

def build_event(cfg: Dict[str, Any], ota_id: str, current_version: str, target_version: str,
                phase: str, event: str, error: Dict[str, Any], ota_log: List[str]) -> Dict[str, Any]:
    region = cfg.get("region", {})
    power = cfg.get("power", {})
    network = cfg.get("network", {})
    context = {
        "region": {
            "country": region.get("country", "DE"),
            "city": region.get("city", "Düsseldorf"),
            "timezone": region.get("timezone", "Europe/Berlin"),
        },
        "time": {
            "local": datetime.now().strftime("%Y-%m-%dT%H:%M:%S"),
            "day_of_week": _day_of_week(),
            "time_bucket": _time_bucket(),
        },
        "power": {
            "source": power.get("source", "BATTERY"),
            "battery": {"pct": power.get("battery_pct", 85)},
        },
        "network": {
            "rssi_dbm": network.get("rssi_dbm", -55),
            "latency_ms": network.get("latency_ms", 373),
        },
    }

    evidence = {
        "ota_log": ota_log,
        "journal_log": _safe_journal("ota-backend.service", lines=50),
        "filesystem": _filesystem_evidence(cfg.get("ota_log_dir", "/data/log/ota")),
    }

    return {
        "ts": _now_ts(),
        "device": {"device_id": cfg.get("device_id", "vw-ivi-0026")},
        "ota": {
            "ota_id": ota_id,
            "current_version": current_version,
            "target_version": target_version,
            "phase": phase,
            "event": event,
        },
        "context": context,
        "error": error,
        "evidence": evidence,
    }

def _write_event(cfg: Dict[str, Any], ota_id: str, event: Dict[str, Any]) -> None:
    log_dir = os.path.join(cfg.get("ota_log_dir", "/data/log/ota"), ota_id)
    os.makedirs(log_dir, exist_ok=True)
    path = os.path.join(log_dir, "events.jsonl")
    with open(path, "a", encoding="utf-8") as f:
        f.write(json.dumps(event) + "\n")

def _queue_event(cfg: Dict[str, Any], event: Dict[str, Any]) -> None:
    queue_path = os.path.join(cfg.get("ota_log_dir", "/data/log/ota"), "queue.jsonl")
    os.makedirs(os.path.dirname(queue_path), exist_ok=True)
    with open(queue_path, "a", encoding="utf-8") as f:
        f.write(json.dumps(event) + "\n")

def _post_event(cfg: Dict[str, Any], event: Dict[str, Any]) -> None:
    url = cfg.get("collector_url") or os.environ.get("COLLECTOR_URL", "")
    if not url:
        _queue_event(cfg, event)
        return
    try:
        resp = requests.post(url, json=event, timeout=10)
        if resp.status_code >= 300:
            _queue_event(cfg, event)
    except Exception:
        _queue_event(cfg, event)

def _flush_queue(cfg: Dict[str, Any]) -> None:
    queue_path = os.path.join(cfg.get("ota_log_dir", "/data/log/ota"), "queue.jsonl")
    if not os.path.exists(queue_path):
        return
    try:
        with open(queue_path, "r", encoding="utf-8") as f:
            lines = f.readlines()
        if not lines:
            return
        os.remove(queue_path)
        for line in lines:
            event = json.loads(line)
            _post_event(cfg, event)
    except Exception:
        return

def start_queue_flusher(cfg: Dict[str, Any], stop_event: threading.Event) -> threading.Thread:
    interval = int(cfg.get("collector_flush_interval_sec", 30))

    def _loop() -> None:
        while not stop_event.is_set():
            _flush_queue(cfg)
            stop_event.wait(interval)

    t = threading.Thread(target=_loop, daemon=True)
    t.start()
    return t

def download_with_retries(url: str, dest: str, retries: int, timeout: int,
                          on_log):
    last_status = None
    for attempt in range(1, retries + 1):
        try:
            with requests.get(url, stream=True, timeout=timeout) as resp:
                last_status = resp.status_code
                if resp.status_code >= 500:
                    on_log(f"DOWNLOAD FAIL code=HTTP_5XX http={resp.status_code} attempt={attempt}")
                    if attempt == retries:
                        return "HTTP_5XX", last_status
                    time.sleep(2 * attempt)
                    continue
                resp.raise_for_status()
                os.makedirs(os.path.dirname(dest), exist_ok=True)
                with open(dest, "wb") as f:
                    for chunk in resp.iter_content(chunk_size=1024 * 1024):
                        if chunk:
                            f.write(chunk)
            on_log("DOWNLOAD OK")
            return None, last_status
        except requests.RequestException as ex:
            on_log(f"DOWNLOAD FAIL error={ex.__class__.__name__} attempt={attempt}")
            if attempt == retries:
                last_status = getattr(ex.response, "status_code", None)
                return ("HTTP_5XX" if (last_status or 0) >= 500 else "HTTP_ERROR"), last_status
            time.sleep(2 * attempt)
    return "HTTP_ERROR", last_status

def rauc_status_json() -> Dict[str, Any]:
    try:
        out = subprocess.check_output(["rauc", "status", "--output-format=json"], text=True)
        return json.loads(out)
    except Exception:
        return {}

def rauc_install(bundle_path: str) -> int:
    try:
        return subprocess.call(["rauc", "install", bundle_path])
    except Exception:
        return 1

def rauc_mark_good() -> int:
    try:
        return subprocess.call(["rauc", "status", "mark-good"])
    except Exception:
        return 1
