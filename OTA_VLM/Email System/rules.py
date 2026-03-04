import re

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

USER_ACTIONABLE = {
    "NET_TIMEOUT",
    "DNS_FAIL",
    "HTTP_5XX",
}

ROOT_CAUSE_SEVERITY = {
    "NET_TIMEOUT": 1,
    "DNS_FAIL": 1,
    "HTTP_5XX": 1,
    "HASH_MISMATCH": 2,
    "DISK_FULL": 2,
    "SYSTEMD_UNIT_FAILED": 3,
    "SERVICE_CRASH": 3,
    "POLICY_REJECT": 2,
    "UNKNOWN": 3,
}


def normalize_text(lines):
    return " ".join([str(line) for line in lines if line]).lower()


def rule_based_classify(raw_log):
    error = raw_log.get("error", {}) or {}
    code = str(error.get("code", "")).strip().upper()
    ota_log = raw_log.get("evidence", {}).get("ota_log", []) or []
    journal_log = raw_log.get("evidence", {}).get("journal_log", []) or []

    text_blob = normalize_text(ota_log + journal_log)
    root_cause = "UNKNOWN"
    confidence = 0.4

    if code in ALLOWED_ROOT_CAUSES and code != "UNKNOWN":
        root_cause = code
        confidence = 0.9
    elif "timeout" in text_blob or "timed out" in text_blob:
        root_cause = "NET_TIMEOUT"
        confidence = 0.75
    elif "could not resolve host" in text_blob or "dns" in text_blob:
        root_cause = "DNS_FAIL"
        confidence = 0.75
    elif "503" in text_blob or "5xx" in text_blob or "server error" in text_blob:
        root_cause = "HTTP_5XX"
        confidence = 0.75
    elif "sha256" in text_blob or "checksum" in text_blob or "hash" in text_blob:
        root_cause = "HASH_MISMATCH"
        confidence = 0.75
    elif "no space left" in text_blob or "disk full" in text_blob:
        root_cause = "DISK_FULL"
        confidence = 0.75
    elif "systemd" in text_blob or "exited with status=1" in text_blob:
        root_cause = "SYSTEMD_UNIT_FAILED"
        confidence = 0.7
    elif "segmentation fault" in text_blob or "segfault" in text_blob or "core dumped" in text_blob:
        root_cause = "SERVICE_CRASH"
        confidence = 0.7
    elif "policy" in text_blob or re.search(r"\bdriving\b", text_blob):
        root_cause = "POLICY_REJECT"
        confidence = 0.65

    supporting_evidence = []
    for line in ota_log:
        if "FAIL" in str(line) or "code=" in str(line):
            supporting_evidence.append(line)
            break
    if journal_log:
        supporting_evidence.append(journal_log[0])

    return {
        "root_cause": root_cause,
        "confidence": confidence,
        "supporting_evidence": supporting_evidence,
    }


def suggest_user_actions(root_cause, raw_log):
    if root_cause not in USER_ACTIONABLE:
        return {
            "user_actionable": False,
            "actions": [],
            "center_recommended": True,
        }

    actions = []
    if root_cause in {"NET_TIMEOUT", "DNS_FAIL"}:
        actions = [
            "Please ensure the vehicle is in an area with reliable connectivity.",
            "Check that Wi-Fi or cellular signal strength is stable.",
            "Retry the update when the network is stable.",
        ]
    elif root_cause == "HTTP_5XX":
        actions = [
            "This may be a temporary server issue; please try again later.",
            "Check that the network connection is stable.",
        ]

    return {
        "user_actionable": True,
        "actions": actions,
        "center_recommended": False,
    }


def is_more_conservative(root_a, root_b):
    return ROOT_CAUSE_SEVERITY.get(root_a, 3) >= ROOT_CAUSE_SEVERITY.get(root_b, 3)
