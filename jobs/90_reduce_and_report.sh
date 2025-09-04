#!/usr/bin/env bash
set -Eeuo pipefail
OUT="${1:-$HOME/out}"
EVID="${2:-$HOME/evidence}"
RUNID="$(date +%Y%m%d_%H%M%S)"
REPORT="$OUT/report_$RUNID.md"
mkdir -p "$OUT" "$EVID"
# Always start the report so even later failures leave a file behind
{
  echo "# Internal Attack Surface Report ($RUNID)"
  echo
  echo "## Inventory"
  [[ -s "$OUT/live.txt"      ]] && echo "- Live hosts: $(wc -l < "$OUT/live.txt")"
  [[ -s "$OUT/hosts.open"    ]] && echo "- Hosts with open ports: $(wc -l < "$OUT/hosts.open")"
  # Web services count (prefer httpx.json via jq; otherwise fallback to urls.live)
  if [[ -s "$OUT/httpx.json" ]] && command -v jq >/dev/null 2>&1; then
    echo "- Web services discovered: $(jq -r '.[].url' "$OUT/httpx.json" 2>/dev/null | wc -l || echo 0)"
  elif [[ -s "$OUT/urls.live" ]]; then
    echo "- Web services discovered (from urls.live): $(wc -l < "$OUT/urls.live")"
  else
    echo "- Web services discovered: 0"
  fi
  echo
  echo "## High-Signal Findings"
  # Nuclei findings (jsonl)
  if [[ -s "$OUT/nuclei.jsonl" ]] && command -v jq >/dev/null 2>&1; then
    echo
    echo "### Nuclei"
    jq -r '
      select(.info.severity=="critical" or .info.severity=="high")
      | "- \(.matched-at) â€” \(.info.name) [\(.info.severity)]"
    ' "$OUT/nuclei.jsonl" 2>/dev/null || true
  else
    echo "- No nuclei findings (file missing or jq not installed)."
  fi
  # Aggregated high severity vulnerability findings (jsonl)
  if [[ -s "$OUT/vulns_summary.jsonl" ]] && command -v jq >/dev/null 2>&1; then
    echo
    echo "### Aggregated Findings"
    jq -r '
      select(.severity=="critical" or .severity=="high")
      | "- \(.host) \(.port)/\(.service) [\(.severity)] - \(.remediation)"
    ' "$OUT/vulns_summary.jsonl" 2>/dev/null || true
    # Provide counts by severity for a quick overview
    echo
    echo "Totals by severity:"
    jq -r 'select(.severity=="critical" or .severity=="high") | .severity' "$OUT/vulns_summary.jsonl" 2>/dev/null \
      | sort | uniq -c | while read -r count severity; do
          echo "- ${severity^}: $count"
        done
  else
    echo "- No vulnerability summary findings (file missing or jq not installed)."
  fi
  # TLS notes (best-effort grep)
  if [[ -s "$OUT/testssl.txt" ]]; then
    echo
    echo "### TLS quick observations"
    grep -Ei "certificate|expired|TLSv1[^.2]|weak|insecure|vulnerable" "$OUT/testssl.txt" 2>/dev/null \
      | head -n 50 | sed 's/^/- /' || true
  fi
  # Service checks summary
  if [[ -d "$OUT/services" ]]; then
    echo "" >> "$REPORT"
    echo "## Service Enumeration Highlights" >> "$REPORT"
    [[ -s "$OUT/services/ssh/"* ]] && echo "- SSH audits: $(ls "$OUT/services/ssh" 2>/dev/null | wc -l) hosts" >> "$REPORT"
    [[ -s "$OUT/services/rdp_enum.txt" ]] && echo "- RDP encryption info collected." >> "$REPORT"
    [[ -s "$OUT/services/smb_info.txt" ]] && echo "- SMB info & security mode enumerated." >> "$REPORT"
    [[ -s "$OUT/services/ldap_search.txt" ]] && echo "- LDAP anonymous search attempted." >> "$REPORT"
    [[ -s "$OUT/services/winrm_auth.txt" ]] && echo "- WinRM auth methods checked." >> "$REPORT"
    [[ -s "$OUT/services/mssql_info.txt" ]] && echo "- MSSQL info gathered." >> "$REPORT"
    [[ -s "$OUT/services/mysql_info.txt" ]] && echo "- MySQL info/empty-password checks." >> "$REPORT"
    [[ -s "$OUT/services/pgsql_info.txt" ]] && echo "- PostgreSQL version info." >> "$REPORT"
    [[ -s "$OUT/services/redis_info.txt" ]] && echo "- Redis info (auth exposure) checked." >> "$REPORT"
    [[ -s "$OUT/services/vnc_info.txt" ]] && echo "- VNC info gathered." >> "$REPORT"
    [[ -s "$OUT/services/dns_recursion.txt" ]] && echo "- DNS recursion tested." >> "$REPORT"
    [[ -s "$OUT/services/nfs_showmount.txt" ]] && echo "- NFS exports enumerated." >> "$REPORT"
    [[ -s "$OUT/services/snmp_sysdescr.txt" ]] && echo "- SNMP sysDescr gathered (approved communities)." >> "$REPORT"
  fi
  # Screenshots
  if [[ -d "$EVID/screens" ]]; then
    echo
    echo "### Screenshots"
    find "$EVID/screens" -type f -name "*.png" 2>/dev/null | head -n 20 | sed 's#^#- Evidence: #'
  fi
  echo
  echo "> **HITL Gate**: Review this summary and evidence. To approve ticketing, create the file: \`$OUT/APPROVED\`"
  echo
} > "$REPORT"
echo "[+] Report: $REPORT"
