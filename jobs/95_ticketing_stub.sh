#!/usr/bin/env bash
# Compile approved findings into a ticket stub for external systems.
# The resulting markdown file can be copied into Jira, ServiceNow, etc.
set -Eeuo pipefail

OUT="${1:-$HOME/out}"
RUNID="$(date +%Y%m%d_%H%M%S)"
TICKET_DIR="$OUT/tickets"
TICKET_FILE="$TICKET_DIR/ticket_${RUNID}.md"

mkdir -p "$TICKET_DIR"

REPORT="$(ls -1t "$OUT"/report_*.md 2>/dev/null | head -n1 || true)"
{
  echo "# Ticket Stub for Findings ($RUNID)"
  echo
  if [[ -n "$REPORT" && -s "$REPORT" ]]; then
    echo "_Source report: $(basename \"$REPORT\")_"
    echo
    awk '/## High-Signal Findings/{flag=1;next}/^##/{if(flag)exit}flag' "$REPORT" 2>/dev/null \
      | sed '/^[[:space:]]*$/d'
    if grep -q "## Service Enumeration Highlights" "$REPORT" 2>/dev/null; then
      echo
      echo "## Service Enumeration Highlights"
      awk '/## Service Enumeration Highlights/{flag=1;next}/^##/{if(flag)exit}flag' "$REPORT" 2>/dev/null \
        | sed '/^[[:space:]]*$/d'
    fi
  else
    echo "*No report found to extract findings.*"
  fi
  echo
  echo "> After review, manually create a ticket in the external system (e.g., Jira, ServiceNow)."
  echo "> Attach relevant evidence and assign to the responsible team."
} > "$TICKET_FILE"

echo "[+] Ticket stub written to $TICKET_FILE"
