#!/usr/bin/env bash
# Pull an ORGANIZATION audit log and push to Google SecOps as log type GITHUB.
# This is the RECOMMENDED capture path: org audit-log JSON parses cleanly with
# the built-in SecOps GitHub parser. (Personal accounts have no equivalent API -
# use forward-webhooks.py instead, or run the lab in a free org.)
#
# Env:
#   ORG                  your GitHub org login
#   GH_TOKEN             a token with read:audit_log (gh auth token works)
#   SECOPS_INGEST_URL    the SecOps logs:import endpoint for your instance
#   SECOPS_TOKEN         bearer token (e.g. `gcloud auth print-access-token`)
#
# NOTE: confirm the exact ingestion endpoint + body shape against current docs:
#   https://cloud.google.com/chronicle/docs/reference/ingestion-api
set -euo pipefail
: "${ORG:?}"; : "${GH_TOKEN:=$(gh auth token)}"
: "${SECOPS_INGEST_URL:?Set your SecOps logs:import URL}"
: "${SECOPS_TOKEN:?Set your SecOps bearer token}"

SINCE="${SINCE:-$(date -u -d '-1 hour' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-1H +%Y-%m-%dT%H:%M:%SZ)}"
echo "[*] Pulling $ORG audit log since $SINCE"

# fetch audit-log entries (REST API)
ENTRIES=$(curl -s -H "Authorization: Bearer $GH_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/orgs/$ORG/audit-log?per_page=100&phrase=created:>$SINCE")

COUNT=$(echo "$ENTRIES" | jq 'length')
echo "[*] $COUNT entries"
[ "$COUNT" -eq 0 ] && { echo "[*] nothing to ship"; exit 0; }

# wrap each entry as a base64 log line for logs:import (inline_source)
LOGS=$(echo "$ENTRIES" | jq -c '[ .[] | {data: (.|tojson|@base64) } ]')
BODY=$(jq -n --argjson logs "$LOGS" '{inline_source: {logs: $logs}}')

curl -s -X POST "$SECOPS_INGEST_URL" \
  -H "Authorization: Bearer $SECOPS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$BODY" | jq .
echo "[+] shipped $COUNT entries as log type GITHUB"
