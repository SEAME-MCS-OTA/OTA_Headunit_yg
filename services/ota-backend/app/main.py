import os
import threading
from typing import Dict, Any
from fastapi import FastAPI, HTTPException

from .models import OtaStartRequest, OtaStatus
from .ota_logic import (
    build_event,
    download_with_retries,
    rauc_status_json,
    rauc_install,
    rauc_mark_good,
    state,
    PHASE_DOWNLOAD,
    PHASE_APPLY,
    PHASE_REBOOT,
    PHASE_COMMIT,
    EVENT_START,
    EVENT_OK,
    EVENT_FAIL,
    load_config,
    _write_event,
    _post_event,
    start_queue_flusher,
)

app = FastAPI(title="ota-backend")

CFG_PATH = os.environ.get("OTA_BACKEND_CONFIG", "/etc/ota-backend/config.json")
CFG: Dict[str, Any] = load_config(CFG_PATH)

_stop_event = threading.Event()
start_queue_flusher(CFG, _stop_event)

@app.get("/health")
def health():
    return {"ok": True}

@app.get("/ota/status", response_model=OtaStatus)
def ota_status():
    status = rauc_status_json()
    slots = []
    compatible = status.get("compatible")
    for slot_name, slot in status.get("slots", {}).items():
        slots.append({
            "name": slot_name,
            "state": slot.get("state", "unknown"),
            "bootname": slot.get("bootname"),
            "device": slot.get("device"),
        })
    return OtaStatus(
        compatible=compatible,
        current_slot=status.get("booted", {}).get("slot"),
        slots=slots,
        current_version=state.current_version,
        target_version=state.target_version,
        phase=state.phase,
        event=state.event,
        last_error=state.last_error,
    )

@app.post("/ota/start")
def ota_start(req: OtaStartRequest):
    if state.phase in (PHASE_DOWNLOAD, PHASE_APPLY, PHASE_REBOOT, PHASE_COMMIT):
        raise HTTPException(status_code=409, detail="OTA already running")

    def _run():
        ota_log = []
        def _log(msg: str):
            ota_log.append(msg)

        state.active_ota_id = req.ota_id
        state.target_version = req.target_version

        state.phase = PHASE_DOWNLOAD
        state.event = EVENT_START
        _log("DOWNLOAD START")
        event = build_event(CFG, req.ota_id, state.current_version, req.target_version,
                            PHASE_DOWNLOAD, EVENT_START, {}, ota_log)
        _write_event(CFG, req.ota_id, event)
        _post_event(CFG, event)

        bundle_dir = CFG.get("bundle_dir", "/data/ota")
        bundle_path = os.path.join(bundle_dir, f"{req.ota_id}.raucb")
        err_code, last_status = download_with_retries(req.url, bundle_path,
                                                      int(CFG.get("download_retries", 3)),
                                                      int(CFG.get("download_timeout_sec", 30)),
                                                      _log)
        if err_code:
            state.event = EVENT_FAIL
            state.last_error = err_code
            if err_code == "HTTP_5XX":
                msg = f"Server error: {last_status} Service Unavailable" if last_status else "Server error: 5xx"
            else:
                msg = "Download error"
            error = {"code": err_code, "message": msg, "retryable": err_code == "HTTP_5XX"}
            event = build_event(CFG, req.ota_id, state.current_version, req.target_version,
                                PHASE_DOWNLOAD, EVENT_FAIL, error, ota_log)
            _write_event(CFG, req.ota_id, event)
            _post_event(CFG, event)
            state.phase = None
            return

        state.phase = PHASE_APPLY
        state.event = EVENT_START
        _log("APPLY START")
        event = build_event(CFG, req.ota_id, state.current_version, req.target_version,
                            PHASE_APPLY, EVENT_START, {}, ota_log)
        _write_event(CFG, req.ota_id, event)
        _post_event(CFG, event)

        rc = rauc_install(bundle_path)
        if rc != 0:
            state.event = EVENT_FAIL
            state.last_error = "RAUC_INSTALL"
            error = {"code": "RAUC_INSTALL", "message": "RAUC install failed", "retryable": False}
            event = build_event(CFG, req.ota_id, state.current_version, req.target_version,
                                PHASE_APPLY, EVENT_FAIL, error, ota_log)
            _write_event(CFG, req.ota_id, event)
            _post_event(CFG, event)
            state.phase = None
            return

        state.phase = PHASE_REBOOT
        state.event = EVENT_OK
        _log("APPLY OK")
        event = build_event(CFG, req.ota_id, state.current_version, req.target_version,
                            PHASE_REBOOT, EVENT_OK, {}, ota_log)
        _write_event(CFG, req.ota_id, event)
        _post_event(CFG, event)

        if bool(CFG.get("reboot_after_apply", False)):
            os.system("systemctl reboot")
            return

        state.phase = PHASE_COMMIT
        state.event = EVENT_START
        _log("COMMIT START")
        event = build_event(CFG, req.ota_id, state.current_version, req.target_version,
                            PHASE_COMMIT, EVENT_START, {}, ota_log)
        _write_event(CFG, req.ota_id, event)
        _post_event(CFG, event)

        if bool(CFG.get("mark_good_on_commit", True)):
            rauc_mark_good()

        state.event = EVENT_OK
        _log("COMMIT OK")
        event = build_event(CFG, req.ota_id, state.current_version, req.target_version,
                            PHASE_COMMIT, EVENT_OK, {}, ota_log)
        _write_event(CFG, req.ota_id, event)
        _post_event(CFG, event)
        state.phase = None

    t = threading.Thread(target=_run, daemon=True)
    t.start()
    return {"ok": True}

@app.post("/ota/reboot")
def ota_reboot():
    os.system("systemctl reboot")
    return {"ok": True}


def main():
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
