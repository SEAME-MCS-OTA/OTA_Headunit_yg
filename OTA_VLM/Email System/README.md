# Email System

A lightweight pipeline that ingests raw logs, runs `append_raw_and_result.py`, and generates customer emails.

## Components
- `pipeline.py`: Pipeline entrypoint and CLI.
- `rules.py`: Determines whether the issue is user-actionable.
- `vlm_client.py`: VLM email generation client.

## Usage
Use `append_raw_and_result.py` as the entrypoint to generate emails (default output is `Email System/email_result.jsonl`):
```bash
python append_raw_and_result.py "failed case/NET_TIMEOUT/dummy.jsonl"
```

To send emails via SMTP, set environment variables and pass `--send-email`:
```bash
export SMTP_HOST="smtp.gmail.com"
export SMTP_PORT="587"
export SMTP_USER="your@gmail.com"
export SMTP_PASS="app_password"
export SMTP_FROM="your@gmail.com"
export SMTP_TO="recipient@gmail.com"
python append_raw_and_result.py "failed case/NET_TIMEOUT/dummy.jsonl" --send-email
```

You can also place the same values in `Email System/.env` (do not commit it):
```bash
cp "Email System/.env.example" "Email System/.env"
# edit Email System/.env with your real SMTP credentials
python append_raw_and_result.py "failed case/NET_TIMEOUT/dummy.jsonl" --send-email
```

## Environment variables
Set the following for VLM calls.
```
VLM_API_URL=http://<host>:<port>/v1/chat/completions
VLM_API_KEY=your_key
VLM_MODEL=Qwen/Qwen3-VL-2B-Instruct
```

## Output
- Final root cause decision
- User-actionable flag and actions
- VLM-generated email subject/body

100+235+60 = 395 380 / 15
2235 
-425
1810

