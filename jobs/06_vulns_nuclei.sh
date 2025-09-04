#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/../config/config.env"
OUT="${1:-$HOME/out}"
[[ -s "$OUT/urls.live" ]] || exit 0
echo "[*] nuclei (curated)"
nuclei -update-templates >/dev/null 2>&1 || true
nuclei -list "$OUT/urls.live" \
  -severity "$NUCLEI_SEVERITY" \
  -tags "$NUCLEI_TAGS" \
  -jsonl -o "$OUT/nuclei.jsonl" || true
