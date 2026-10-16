#!/usr/bin/env python3
"""
Personal-account capture: receive GitHub webhooks and forward to Google SecOps.

Why this exists: a bare personal account has no org audit-log API. Repo webhooks
are the most reliable way to capture activity (push, repository visibility, member,
public, etc.). IMPORTANT: webhook JSON is NOT the same schema as the audit log,
so ship it under a CUSTOM log type (default GITHUB_WEBHOOK) and write your YARA-L
against that schema - the built-in GITHUB audit parser will not parse webhooks.

Setup:
  1. Repo > Settings > Webhooks > Add webhook
       Payload URL: http://<this-host>:8080/webhook
       Content type: application/json
       Events: "Send me everything" (or pick pushes, repository, member, ...)
  2. export SECOPS_INGEST_URL=...   SECOPS_TOKEN=...   LOG_TYPE=GITHUB_WEBHOOK
  3. python3 forward-webhooks.py

Confirm the ingestion endpoint/body shape for your instance:
  https://cloud.google.com/chronicle/docs/reference/ingestion-api
"""
import base64
import json
import os
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer

INGEST_URL = os.environ.get("SECOPS_INGEST_URL", "")
TOKEN = os.environ.get("SECOPS_TOKEN", "")
LOG_TYPE = os.environ.get("LOG_TYPE", "GITHUB_WEBHOOK")
PORT = int(os.environ.get("PORT", "8080"))


def ship(raw: bytes, event: str):
    if not INGEST_URL or not TOKEN:
        print(f"[dry-run] {event}: {len(raw)} bytes (set SECOPS_INGEST_URL/TOKEN to ship)")
        return
    body = {"inline_source": {"logs": [{"data": base64.b64encode(raw).decode()}]}}
    req = urllib.request.Request(
        INGEST_URL,
        data=json.dumps(body).encode(),
        headers={"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            print(f"[+] shipped {event} ({LOG_TYPE}) -> {r.status}")
    except Exception as e:
        print(f"[!] ship failed for {event}: {e}")


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length)
        event = self.headers.get("X-GitHub-Event", "unknown")
        ship(raw, event)
        self.send_response(204)
        self.end_headers()

    def log_message(self, *a):  # quiet default logging
        pass


if __name__ == "__main__":
    print(f"[*] listening on :{PORT}/webhook  log_type={LOG_TYPE}")
    HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
