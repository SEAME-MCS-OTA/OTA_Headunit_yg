import json
import os
import re
import requests

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


class VLMClient:
    def __init__(self, api_url=None, api_key=None, model=None, timeout_sec=30):
        self.api_url = api_url or os.getenv("VLM_API_URL") or "http://210.121.152.22:9000/v1/chat/completions"
        self.api_key = api_key or os.getenv("VLM_API_KEY") or "81cbe888efea8c89da139c5cc8194393c1ead203e11e85a9a5a721428c5a2517"
        self.model = model or os.getenv("VLM_MODEL") or "Qwen/Qwen3-VL-2B-Instruct"
        self.timeout_sec = timeout_sec

        if not self.api_url or not self.model:
            raise RuntimeError("VLM_API_URL and VLM_MODEL must be set.")

    def _post(self, messages, max_tokens=600):
        headers = {"Content-Type": "application/json"}
        if self.api_key:
            headers["Authorization"] = f"Bearer {self.api_key}"

        payload = {
            "model": self.model,
            "messages": messages,
            "temperature": 0.01,
            "max_tokens": max_tokens,
        }
        response = requests.post(
            self.api_url, headers=headers, json=payload, timeout=self.timeout_sec
        )
        response.raise_for_status()
        data = response.json()
        return data["choices"][0]["message"]["content"]

    @staticmethod
    def _compact_log(raw_log):
        context = raw_log.get("context", {}) or {}
        power = context.get("power", {}) or {}
        battery = power.get("battery", {}) or {}
        network = context.get("network", {}) or {}

        compact = {
            "ts": raw_log.get("ts", ""),
            "device": {"device_id": raw_log.get("device", {}).get("device_id", "")},
            "ota": {
                "ota_id": raw_log.get("ota", {}).get("ota_id", ""),
                "current_version": raw_log.get("ota", {}).get("current_version", ""),
                "target_version": raw_log.get("ota", {}).get("target_version", ""),
                "phase": raw_log.get("ota", {}).get("phase", ""),
            },
            "error": raw_log.get("error", {}),
            "context": {
                "region": context.get("region", {}),
                "time": context.get("time", {}),
                "power": {
                    "source": power.get("source", ""),
                    "battery_pct": battery.get("pct", 0),
                },
                "network": {
                    "rssi_dbm": network.get("rssi_dbm", 0),
                    "latency_ms": network.get("latency_ms", 0),
                },
            },
            "evidence": {
                "ota_log": raw_log.get("evidence", {}).get("ota_log", []),
                "journal_log": raw_log.get("evidence", {}).get("journal_log", []),
                "filesystem": raw_log.get("evidence", {}).get("filesystem", []),
            },
        }
        return json.dumps(compact, ensure_ascii=False)

    @staticmethod
    def _extract_json(text):
        text = text.strip()
        if text.startswith("{") and text.endswith("}"):
            return json.loads(text)
        match = re.search(r"\{.*\}", text, re.DOTALL)
        if match:
            return json.loads(match.group(0))
        raise ValueError("No JSON object found in VLM response.")

    def classify(self, raw_log):
        prompt = (
            "Analyze the log below and classify root_cause. Output JSON only.\n"
            "JSON schema: {\"root_cause\":\"\",\"confidence\":0.0,"
            "\"supporting_evidence\":[]}\n"
            "root_cause must be one of: "
            + ", ".join(sorted(ALLOWED_ROOT_CAUSES))
            + "\n"
            "supporting_evidence must quote exact phrases from the input.\n"
            "Input log:\n"
            + self._compact_log(raw_log)
        )
        content = self._post(
            [
                {"role": "system", "content": "You are a careful log analyst."},
                {"role": "user", "content": prompt},
            ],
            max_tokens=400,
        )
        result = self._extract_json(content)
        result["root_cause"] = str(result.get("root_cause", "UNKNOWN")).upper()
        if result["root_cause"] not in ALLOWED_ROOT_CAUSES:
            result["root_cause"] = "UNKNOWN"
        result["confidence"] = float(result.get("confidence", 0.0) or 0.0)
        result["supporting_evidence"] = result.get("supporting_evidence", []) or []
        return result

    def generate_email(self, email_context):
        prompt = (
            "Write a customer email based on the information below.\n"
            "Use a clear, easy-to-read template so anyone can understand the issue and next steps.\n"
            "Be conservative; if the user cannot reasonably resolve it, advise visiting a service center.\n"
            "Output JSON only: {\"subject\":\"\",\"body\":\"\"}\n"
            "Write in English.\n"
            "Format requirements:\n"
            "- Use short paragraphs and bullet points.\n"
            "- Avoid markdown headers (#). Use plain labels like \"Summary:\".\n"
            "- Keep it concise and friendly.\n"
            "Template sections in this order:\n"
            "Summary, What You Can Do, When to Visit a Service Center, Reference Info.\n"
            "Input:\n"
            + json.dumps(email_context, ensure_ascii=False)
        )
        content = self._post(
            [
                {"role": "system", "content": "You write concise, polite support emails."},
                {"role": "user", "content": prompt},
            ],
            max_tokens=600,
        )
        result = self._extract_json(content)
        return {
            "subject": str(result.get("subject", "")).strip(),
            "body": str(result.get("body", "")).strip(),
        }
