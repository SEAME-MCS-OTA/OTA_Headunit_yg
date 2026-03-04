# OTA Ops Dashboard (Local)

Local React + Node + MySQL dashboard to visualize OTA failure analytics in realtime.

## 1) MySQL setup

```sql
-- run in mysql shell
SOURCE ota-dashboard/backend/schema.sql;
```

If you already created the database/user manually, ensure MySQL is running and accessible:

```bash
sudo systemctl start mysql
```
## 2) Backend setup

```bash
cd ota-dashboard/backend
cp .env.example .env
# edit .env with your MySQL credentials
npm install
npm run start
```

Backend runs on `http://localhost:4000`.

If you changed backend code, restart it:
```bash
pkill -f "node server.js"
cd /home/yg/OTA_VLM/ota-dashboard/backend
npm run start
```

## 3) Frontend setup

```bash
cd ota-dashboard/frontend
npm install
npm run dev
```

Frontend runs on `http://localhost:5173` and calls the backend at `http://localhost:4000`.

## 4) Ingest logs (example)

The backend expects each POST body to be a single JSON record in the result schema.

```bash
head -n 1 "failed case/NET_TIMEOUT/result.jsonl" > /tmp/one.json
curl -X POST http://localhost:4000/ingest \
  -H 'Content-Type: application/json' \
  -d @/tmp/one.json
```

If you have multiple JSONL lines, send them line-by-line. A simple helper in Python:

```bash
python3 - <<'PY'
import json
import requests
from pathlib import Path

path = Path("failed case/NET_TIMEOUT/result.jsonl")
for line in path.read_text().splitlines():
    if not line.strip():
        continue
    requests.post("http://localhost:4000/ingest", json=json.loads(line))
print("done")
PY
```

To ingest all result files at once:

```bash
python3 - <<'PY'
import json
from pathlib import Path
import urllib.request

BASE_DIR = Path("failed case")
API_URL = "http://localhost:4000/ingest"

count = 0
for path in sorted(BASE_DIR.glob("*/result.jsonl")):
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        data = json.dumps(json.loads(line)).encode("utf-8")
        req = urllib.request.Request(API_URL, data=data, headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req) as resp:
            resp.read()
        count += 1

print(f"ingested {count} records")
PY
```

If you want a full refresh (ingest all cases):

```bash
python3 - <<'PY'
import json
from pathlib import Path
import urllib.request

BASE_DIR = Path("failed case")
API_URL = "http://localhost:4000/ingest"

for path in sorted(BASE_DIR.glob("*/result.jsonl")):
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        data = json.dumps(json.loads(line)).encode("utf-8")
        req = urllib.request.Request(API_URL, data=data, headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req) as resp:
            resp.read()
print("done")
PY
```

If /ingest returns a 500 error about column count mismatch, restart the backend to pick up the latest INSERT statement:

```bash
pkill -f "node server.js"
cd /home/yg/OTA_VLM/ota-dashboard/backend
npm run start
```

If UNKNOWN results are not visible, re-ingest the UNKNOWN result file:

```bash
python3 - <<'PY'
import json
from pathlib import Path
import urllib.request

path = Path("failed case/UNKNOWN/result.jsonl")
API_URL = "http://localhost:4000/ingest"

count = 0
for line in path.read_text(encoding="utf-8").splitlines():
    if not line.strip():
        continue
    data = json.dumps(json.loads(line)).encode("utf-8")
    req = urllib.request.Request(API_URL, data=data, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req) as resp:
        resp.read()
    count += 1

print(f"ingested {count} UNKNOWN records")
PY
```

If you want a clean reset (remove duplicates and re-ingest):

```bash
# clear table
mysql -h 127.0.0.1 -P 3306 -u admin -padmin -D ota_dashboard -e "TRUNCATE TABLE ota_logs;"

# re-ingest all results
python3 - <<'PY'
import json
from pathlib import Path
import urllib.request

BASE_DIR = Path("failed case")
API_URL = "http://localhost:4000/ingest"

count = 0
for path in sorted(BASE_DIR.glob("*/result.jsonl")):
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        data = json.dumps(json.loads(line)).encode("utf-8")
        req = urllib.request.Request(API_URL, data=data, headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req) as resp:
            resp.read()
        count += 1

print(f"ingested {count} records")
PY
```

If vehicle series stats show only UNKNOWN, backfill from `raw_json`:

```sql
UPDATE ota_logs
SET
  vehicle_brand = JSON_UNQUOTE(JSON_EXTRACT(raw_json, '$.log_vehicle.brand')),
  vehicle_series = JSON_UNQUOTE(JSON_EXTRACT(raw_json, '$.log_vehicle.series')),
  vehicle_segment = JSON_UNQUOTE(JSON_EXTRACT(raw_json, '$.log_vehicle.segment')),
  vehicle_fuel = JSON_UNQUOTE(JSON_EXTRACT(raw_json, '$.log_vehicle.fuel'))
WHERE vehicle_series IS NULL OR vehicle_series = '';
```

## Endpoints

- `POST /ingest` insert a result JSON object
- `GET /stats/summary`
- `GET /stats/root-cause`
- `GET /stats/cities`
- `GET /stats/time-bucket`
- `GET /stats/network-buckets`
- `GET /stats/models`
- `GET /stats/raw`
