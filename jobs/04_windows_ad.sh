#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/../config/config.env"
OUT="${1:-$HOME/out}"
mkdir -p "$OUT/enum4linux" "$OUT/ldap"
[[ -s "$OUT/open.ports" ]] || exit 0
echo "[*] nbtscan (sample)"
head -n 200 "$OUT/live.txt" | xargs -I{} bash -lc 'nbtscan {}' \
  | tee "$OUT/nbtscan.txt" || true
# enum4linux-ng against SMB hosts
grep -E ':(139|445)$' "$OUT/open.ports" | cut -d: -f1 | sort -u | \
  xargs -P "${SMB_THREADS:-4}" -I{} bash -lc 'echo "enum4linux-ng on {}"; enum4linux-ng -A {} -oY "'"$OUT"'/enum4linux/{}.yml" || true'
# Find DCs via SRV (if dig present)
DOMSUF=$(grep -E '^search' /etc/resolv.conf | awk '{$1="";print $0}' | xargs -n1 | head -n1)
if [[ -n "$DOMSUF" && -x "$(command -v dig)" ]]; then
  echo "[*] DNS SRV for LDAP"
  dig +short _ldap._tcp.dc._msdcs."$DOMSUF" SRV | awk '{print $4}' | sed 's/\.$//' | sort -u > "$OUT/ad.dcs"
fi
# LDAP base contexts (anonymous if allowed)
if [[ -s "$OUT/ad.dcs" ]]; then
  DC=$(head -n1 "$OUT/ad.dcs")
  echo "[*] LDAP namingContexts via $DC"
  ldapsearch -x -H "ldap://$DC" -b "" -s base namingContexts > "$OUT/ldap/namingcontexts.ldif" || true
fi
# BloodHound (optional; provide creds via env)
# Example: BLOOD_USER='DOM\\user' BLOOD_PW='...' ./04_windows_ad.sh
if [[ -n "${BLOOD_USER:-}" && -n "${BLOOD_PW:-}" && -s "$OUT/ad.dcs" && -x "$(command -v bloodhound-python)" ]]; then
  DC=$(head -n1 "$OUT/ad.dcs")
  echo "[*] bloodhound-python"
  bloodhound-python -d "$DOMSUF" -u "$BLOOD_USER" -p "$BLOOD_PW" -dc "$DC" \
    -c All -ns "$DC" -json -o "$OUT/bloodhound" || true
fi
