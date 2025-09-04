#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/../config/config.env"
OUT="${1:-$HOME/out}"
[[ -s "$OUT/live.txt" ]] || exit 0
[[ -n "${SNMP_COMMUNITIES:-}" ]] || { echo "[i] SNMP communities not set; skipping."; exit 0; }
echo "$SNMP_COMMUNITIES" | tr ' ' '\n' > "$OUT/snmp_communities.txt"
echo "[*] onesixtyone sweep"
while read -r NET; do
  onesixtyone -c "$OUT/snmp_communities.txt" "$NET" | tee -a "$OUT/snmp.txt" || true
done <<< "$(echo "$CIDRS" | tr ',' ' ')"