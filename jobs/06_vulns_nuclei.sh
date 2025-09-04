#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/../config/config.env"
source "$(dirname "$0")/../lib/vuln_summary.sh"
OUT="${1:-$HOME/out}"
SUMMARY="$OUT/vulns_summary.jsonl"
# Ensure summary file exists but do not overwrite existing service-check data
touch "$SUMMARY"
[[ -s "$OUT/urls.live" ]] || exit 0
echo "[*] nuclei (curated)"
nuclei -update-templates >/dev/null 2>&1 || true
nuclei -list "$OUT/urls.live" \
  -severity "$NUCLEI_SEVERITY" \
  -tags "$NUCLEI_TAGS" \
  -jsonl -o "$OUT/nuclei.jsonl" || true
# Summarize nuclei findings
if [[ -s "$OUT/nuclei.jsonl" ]] && command -v jq >/dev/null 2>&1; then
  jq -c '{host:(.host // (.matched-at | sub("https?://"; "") | split("/")[0])), service:(.type // "http"), severity:.info.severity, description:.info.name}' "$OUT/nuclei.jsonl" >> "$SUMMARY" || true
fi
# Summarize TLS/testssl findings
if [[ -s "$OUT/testssl.txt" ]]; then
  current_host=""
  while IFS= read -r line; do
    if [[ $line =~ ^Testing[[:space:]]+([0-9A-Za-z:\.-]+) ]]; then
      current_host="${BASH_REMATCH[1]}"
    elif echo "$line" | grep -qiE 'vulnerable|expired|not ok|weak'; then
      add_vuln "$SUMMARY" "$current_host" "tls" "medium" "$line"
    fi
  done < "$OUT/testssl.txt"
fi
