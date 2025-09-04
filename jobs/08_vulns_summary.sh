#!/usr/bin/env bash
set -Eeuo pipefail
OUT="${1:-$HOME/out}"

# require nuclei results and jq for parsing
if [[ ! -s "$OUT/nuclei.jsonl" ]] || ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

# Extract high/critical vulnerabilities into a normalized summary
# Fields: host, port, service, severity, remediation
jq -r '
  select(.info.severity=="critical" or .info.severity=="high") |
  {
    host: (.host | sub("^https?://"; "") | split("/")[0] | split(":")[0]),
    port: ((.host | sub("^https?://"; "") | split("/")[0] | split(":")[1]) // ""),
    service: (.type // "nuclei"),
    severity: .info.severity,
    remediation: .info.name
  } | @json
' "$OUT/nuclei.jsonl" > "$OUT/vulns_summary.jsonl" 2>/dev/null || true
