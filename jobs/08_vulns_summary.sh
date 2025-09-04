#!/usr/bin/env bash
set -Eeuo pipefail
OUT="${1:-$HOME/out}"

# require jq for parsing
command -v jq >/dev/null 2>&1 || exit 0

SUMMARY="$OUT/vulns_summary.jsonl"
: > "$SUMMARY"

# Extract high/critical nuclei results if present
if [[ -s "$OUT/nuclei.jsonl" ]]; then
  jq -r '
    select(.info.severity=="critical" or .info.severity=="high") |
    {
      host: (.host | sub("^https?://"; "") | split("/")[0] | split(":")[0]),
      port: ((.host | sub("^https?://"; "") | split("/")[0] | split(":")[1]) // ""),
      service: (.type // "nuclei"),
      severity: .info.severity,
      remediation: .info.name
    } | @json
  ' "$OUT/nuclei.jsonl" >> "$SUMMARY" 2>/dev/null || true
fi

# Append service vulnerabilities if present
if [[ -s "$OUT/services_vulns.jsonl" ]]; then
  cat "$OUT/services_vulns.jsonl" >> "$SUMMARY"
fi

# Remove file if no findings
[[ -s "$SUMMARY" ]] || rm -f "$SUMMARY"
