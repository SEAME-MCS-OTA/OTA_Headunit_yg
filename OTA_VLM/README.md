# OTA_VLM

## System architecture

1) Raw OTA logs are ingested (JSON).
2) Rule-based classifier assigns an initial root cause.
3) VLM refines the result when UNKNOWN or low confidence.
4) Raw logs are appended to `failed case/<case>/dummy.jsonl`.
5) Final results are appended to `failed case/<case>/result.jsonl`.
6) The backend ingests `result.jsonl` into MySQL via `/ingest`.
7) React dashboard reads aggregates from backend APIs.

This repo contains a hybrid log-classification pipeline (rules + VLM) and a local dashboard to visualize results.

## What's here

- `vLLM_practice_token_fixed.py`: Hybrid classifier (rule-based first, VLM fallback)
- `append_raw_and_result.py`: Append raw logs to `dummy.jsonl`, VLM results to `result.jsonl`
- `append_result_to_failed_case.py`: Append a ready-made result JSON to the right case folder
- `normalize_result_json.py`: Fill missing fields to match the result schema
- `analyze_results.py`: Generate CSV/PNG analytics from `result.jsonl`
- `ota-dashboard/`: Local React + Node + MySQL dashboard

## Flow (log -> server)

1) Input log (raw JSON)
2) Rule-based classification (fast keywords + error code)
3) VLM fallback if UNKNOWN or low confidence
4) Write:
   - `failed case/<case>/dummy.jsonl` (raw log, rule-based folder)
   - `failed case/<case>/result.jsonl` (final VLM result folder)
5) Ingest `result.jsonl` to the dashboard backend (`/ingest`)

## Input log format (raw)

Minimum fields recommended:

```json
{
  "ts": "2026-01-13T22:27:29+01:00",
  "device": {"device_id": "vw-ivi-0026"},
  "ota": {
    "ota_id": "ota-20260113-07f480",
    "current_version": "1.2.3",
    "target_version": "1.2.4",
    "phase": "DOWNLOAD",
    "event": "FAIL"
  },
  "context": {
    "region": {"country": "DE", "city": "Düsseldorf", "timezone": "Europe/Berlin"},
    "time": {"local": "2026-01-13T22:27:29", "day_of_week": "Tue", "time_bucket": "NIGHT"},
    "power": {"source": "BATTERY", "battery": {"pct": 85}},
    "network": {"rssi_dbm": -55, "latency_ms": 373}
  },
  "error": {"code": "HTTP_5XX", "message": "Server error: 503 Service Unavailable", "retryable": true},
  "evidence": {
    "ota_log": ["DOWNLOAD START", "DOWNLOAD FAIL code=HTTP_5XX http=503"],
    "journal_log": ["HTTP/1.1 503 Service Unavailable"],
    "filesystem": []
  }
}
```

### Allowed case values

Use one of the following values in `error.code` and evidence logs:

- `NET_TIMEOUT`
- `DNS_FAIL`
- `HTTP_5XX`
- `HASH_MISMATCH`
- `DISK_FULL`
- `SYSTEMD_UNIT_FAILED`
- `SERVICE_CRASH`
- `POLICY_REJECT`
- `UNKNOWN`

Example:

```json
"error": {"code": "HTTP_5XX", "message": "Server error: 503 Service Unavailable", "retryable": true}
```

## Run the hybrid classifier

Single log (inline JSON):

```bash
python3 vLLM_practice_token_fixed.py '<raw_json>'
```

STDIN:

```bash
cat /path/to/raw.json | python3 vLLM_practice_token_fixed.py -
```

## Append raw + result to case folders

This will add:
- raw log -> `failed case/<case>/dummy.jsonl`
- VLM result -> `failed case/<case>/result.jsonl`

```bash
python3 append_raw_and_result.py '<raw_json>'
```

JSONL file:

```bash
python3 append_raw_and_result.py /path/to/raw.jsonl
```

## Dashboard (server ingest)

See `ota-dashboard/README.md` for full setup.

## Original image example (legacy)

The repository originally included an image captioning example. The script now focuses on log classification, but the vLLM endpoint remains configurable:

- `VLLM_API_URL`
- `API_KEY`
- `MODEL_NAME`
