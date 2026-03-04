#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import json
import random
import uuid
from datetime import datetime, timedelta, timezone

# -----------------------------
# 사용자 환경에 맞게 수정
# -----------------------------
BASE_DIR = "failed case"   # 여기 아래에 케이스 폴더가 있다고 가정
PER_CASE = 100             # 폴더당 생성 개수
OUT_NAME = "dummy.jsonl"   # 각 폴더에 생성될 파일명

# -----------------------------
# 고정 데이터(폭스바겐 차종 + 독일 도시)
# -----------------------------
VW_MODELS = [
    {"brand": "Volkswagen", "series": "Golf",    "segment": "C",   "fuel": "ICE"},
    {"brand": "Volkswagen", "series": "Passat",  "segment": "D",   "fuel": "ICE"},
    {"brand": "Volkswagen", "series": "Tiguan",  "segment": "SUV", "fuel": "ICE"},
    {"brand": "Volkswagen", "series": "Touareg", "segment": "SUV", "fuel": "ICE"},
    {"brand": "Volkswagen", "series": "ID.3",    "segment": "C",   "fuel": "EV"},
    {"brand": "Volkswagen", "series": "ID.4",    "segment": "SUV", "fuel": "EV"},
    {"brand": "Volkswagen", "series": "ID.7",    "segment": "D",   "fuel": "EV"},
]

GERMAN_CITIES = [
    ("DE", "Berlin",      "Europe/Berlin"),
    ("DE", "Munich",      "Europe/Berlin"),
    ("DE", "Hamburg",     "Europe/Berlin"),
    ("DE", "Wolfsburg",   "Europe/Berlin"),
    ("DE", "Stuttgart",   "Europe/Berlin"),
    ("DE", "Frankfurt",   "Europe/Berlin"),
    ("DE", "Cologne",     "Europe/Berlin"),
    ("DE", "Düsseldorf",  "Europe/Berlin"),
    ("DE", "Leipzig",     "Europe/Berlin"),
    ("DE", "Hannover",    "Europe/Berlin"),
]

# 실패 코드별 예시 템플릿(증거/메시지/phase)
CASE_TEMPLATES = {
    "NET_TIMEOUT": {
        "phase": "DOWNLOAD",
        "message": "HTTP read timeout after 15s",
        "retryable": True,
        "ota_log": ["DOWNLOAD START", "DOWNLOAD FAIL code=NET_TIMEOUT"],
        "journal_log": ["curl: (28) Operation timed out"],
        "filesystem": []
    },
    "DNS_FAIL": {
        "phase": "DOWNLOAD",
        "message": "Could not resolve host",
        "retryable": True,
        "ota_log": ["DOWNLOAD START", "DOWNLOAD FAIL code=DNS_FAIL"],
        "journal_log": ["curl: (6) Could not resolve host"],
        "filesystem": []
    },
    "HTTP_5XX": {
        "phase": "DOWNLOAD",
        "message": "Server error: 503 Service Unavailable",
        "retryable": True,
        "ota_log": ["DOWNLOAD START", "DOWNLOAD FAIL code=HTTP_5XX http=503"],
        "journal_log": ["HTTP/1.1 503 Service Unavailable"],
        "filesystem": []
    },
    "HASH_MISMATCH": {
        "phase": "VERIFY",
        "message": "SHA256 mismatch for artifact",
        "retryable": False,
        "ota_log": ["VERIFY START", "VERIFY FAIL code=HASH_MISMATCH"],
        "journal_log": ["sha256sum: WARNING: 1 computed checksum did NOT match"],
        "filesystem": []
    },
    "DISK_FULL": {
        "phase": "INSTALL",
        "message": "No space left on device during install",
        "retryable": False,
        "ota_log": ["INSTALL START", "INSTALL FAIL code=DISK_FULL"],
        "journal_log": ["tar: write error: No space left on device"],
        "filesystem": ["df -h -> /opt 100%"]
    },
    "SYSTEMD_UNIT_FAILED": {
        "phase": "APPLY",
        "message": "ivi-ui.service exited with status=1",
        "retryable": False,
        "ota_log": ["APPLY SERVICE_RESTART service=ivi-ui.service", "APPLY FAIL code=SYSTEMD_UNIT_FAILED"],
        "journal_log": [
            "ivi-ui[412]: error: missing /opt/app/resources/ui.qml",
            "systemd[1]: ivi-ui.service: Main process exited, status=1/FAILURE"
        ],
        "filesystem": ["ls /opt/app/resources -> ui.qml NOT FOUND"]
    },
    "SERVICE_CRASH": {
        "phase": "POSTCHECK",
        "message": "Service crashed (segfault)",
        "retryable": False,
        "ota_log": ["POSTCHECK START", "POSTCHECK FAIL code=SERVICE_CRASH"],
        "journal_log": ["app[512]: Segmentation fault (core dumped)"],
        "filesystem": []
    },
    "POLICY_REJECT": {
        "phase": "CHECK",
        "message": "Update not allowed by policy (battery/time/driving)",
        "retryable": True,
        "ota_log": ["CHECK START", "CHECK FAIL code=POLICY_REJECT"],
        "journal_log": [],
        "filesystem": []
    },
    "UNKNOWN": {
        "phase": "REPORT",
        "message": "Unknown failure (insufficient evidence)",
        "retryable": False,
        "ota_log": ["REPORT FAIL code=UNKNOWN"],
        "journal_log": [],
        "filesystem": []
    },
    # 성공 폴더명이 SUCCESS/OK 등 어떤 것이든 들어올 수 있으므로 런타임에서 처리
}

# 시간대/타임존
TZ_OFFSET = timedelta(hours=1)
BERLIN_TZ = timezone(TZ_OFFSET)

def time_bucket(dt: datetime) -> str:
    return "NIGHT" if dt.hour >= 22 or dt.hour < 6 else "DAY"

def is_success_folder(folder_name: str) -> bool:
    n = folder_name.strip().upper()
    return n in {"OK", "SUCCESS", "SUCCEEDED", "PASS", "PASSED"}

def mk_record(case_name: str, i: int) -> dict:
    # 기본 랜덤 컨텍스트
    country, city, tz = random.choice(GERMAN_CITIES)
    vehicle = random.choice(VW_MODELS)

    # timestamp: 최근 30일 내 분산
    start = datetime(2026, 1, 1, 0, 0, 0, tzinfo=BERLIN_TZ)
    ts = start + timedelta(minutes=random.randint(0, 60*24*30)) + timedelta(seconds=random.randint(0, 59))

    battery_pct = random.randint(5, 100)
    on_battery = random.random() < 0.65
    power_source = "BATTERY" if on_battery else "AC"
    driving = random.random() < 0.25

    # 네트워크 RSSI는 NET_TIMEOUT/DNS_FAIL일 때 더 나쁘게 만들기
    rssi = random.randint(-78, -45)
    if case_name in {"NET_TIMEOUT", "DNS_FAIL"}:
        rssi = random.randint(-88, -70)

    storage_free_mb = random.randint(200, 20000)
    if case_name == "DISK_FULL":
        storage_free_mb = random.randint(50, 500)

    device_id = f"vw-ivi-{random.randint(1, 80):04d}"
    ota_id = f"ota-{ts.strftime('%Y%m%d')}-{uuid.uuid4().hex[:6]}"

    base = {
        "ts": ts.isoformat(),
        "device": {
            "device_id": device_id,
            "model": "raspberrypi4",
            "hw_rev": "1.2",
            "serial": f"RPI4-{random.randint(1000,9999)}",
            "current_slot": random.choice(["A", "B"])
        },
        "log_vehicle": {
            "brand": vehicle["brand"],
            "series": vehicle["series"],
            "segment": vehicle["segment"],
            "fuel": vehicle["fuel"]
        },
        "ota": {
            "ota_id": ota_id,
            "type": "PARTIAL",
            "current_version": random.choice(["1.2.2", "1.2.3"]),
            "target_version": "1.2.4",
            "phase": "REPORT",
            "event": "OK",
            "attempt": random.randint(1, 3)
        },
        "context": {
            "region": {"country": country, "city": city, "timezone": tz},
            "time": {
                "local": ts.strftime("%Y-%m-%dT%H:%M:%S"),
                "day_of_week": ts.strftime("%a"),
                "time_bucket": time_bucket(ts)
            },
            "power": {
                "source": power_source,
                "battery": {
                    "pct": battery_pct,
                    "state": "DISCHARGING" if power_source == "BATTERY" else "CHARGING",
                    "voltage_mv": random.randint(4700, 5200)
                }
            },
            "environment": {
                "temp_c": random.randint(35, 75),
                "cpu_load_pct": random.randint(5, 95),
                "mem_free_mb": random.randint(200, 2000),
                "storage_free_mb": storage_free_mb
            },
            "network": {
                "iface": "wlan0",
                "ip": f"192.168.1.{random.randint(2, 250)}",
                "rssi_dbm": rssi,
                "latency_ms": random.randint(10, 400),
                "gateway_reachable": True
            },
            "vehicle_state": {
                "driving": driving,
                "speed_kph": random.randint(5, 120) if driving else 0
            }
        },
        "error": {"code": "NONE", "message": "", "retryable": False},
        "evidence": {
            "ota_log": ["CHECK OK", "DOWNLOAD OK", "VERIFY OK", "INSTALL OK", "APPLY OK", "POSTCHECK OK"],
            "journal_log": [],
            "filesystem": [],
            "boot_state": {"bootcount": 0, "upgrade_available": False}
        },
        "user_interaction": {"user_action": "NONE", "power_event": "NONE"},
        "artifacts": {"screenshot_path": "", "log_bundle_path": ""},
        "report": {
            "sent": True,
            "sent_at": (ts + timedelta(seconds=1)).isoformat(),
            "server_response": "200 OK"
        }
    }

    # 성공 케이스
    if is_success_folder(case_name):
        base["ota"]["phase"] = "REPORT"
        base["ota"]["event"] = "OK"
        base["evidence"]["ota_log"].append("REPORT SEND status=OK")
        return base

    # 실패 케이스
    tpl = CASE_TEMPLATES.get(case_name)
    if tpl is None:
        # 폴더명이 템플릿에 없으면 "알 수 없음"으로라도 생성
        tpl = {
            "phase": "REPORT",
            "message": f"Unknown failure case folder: {case_name}",
            "retryable": False,
            "ota_log": [f"FAIL code={case_name}"],
            "journal_log": [],
            "filesystem": []
        }

    base["ota"]["phase"] = tpl["phase"]
    base["ota"]["event"] = "FAIL"
    base["error"] = {"code": case_name, "message": tpl["message"], "retryable": tpl["retryable"]}
    base["evidence"]["ota_log"] = tpl["ota_log"]
    base["evidence"]["journal_log"] = tpl["journal_log"]
    base["evidence"]["filesystem"] = tpl["filesystem"]

    # 실패 시 아티팩트 경로(더미)
    base["artifacts"]["screenshot_path"] = f"s3://ota/{device_id}/{ota_id}/failure.png"
    base["artifacts"]["log_bundle_path"] = f"s3://ota/{device_id}/{ota_id}/logs.tar.gz"
    base["report"]["server_response"] = random.choice(["200 OK", "202 ACCEPTED"])
    return base

def main():
    if not os.path.isdir(BASE_DIR):
        raise SystemExit(f"BASE_DIR not found: {BASE_DIR}")

    case_dirs = [
        d for d in os.listdir(BASE_DIR)
        if os.path.isdir(os.path.join(BASE_DIR, d)) and not d.startswith(".")
    ]
    if not case_dirs:
        raise SystemExit(f"No case folders found under: {BASE_DIR}")

    random.seed(7)

    for case in sorted(case_dirs):
        out_path = os.path.join(BASE_DIR, case, OUT_NAME)
        with open(out_path, "w", encoding="utf-8") as f:
            for i in range(PER_CASE):
                rec = mk_record(case, i)
                f.write(json.dumps(rec, ensure_ascii=False) + "\n")
        print(f"[OK] {case}: wrote {PER_CASE} lines -> {out_path}")

if __name__ == "__main__":
    main()
