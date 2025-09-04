#!/usr/bin/env bash
set -Eeuo pipefail
OUT="${1:-$HOME/out}"
EVID="${2:-$HOME/evidence}"
mkdir -p "$OUT" "$EVID"
[[ -s "$OUT/hosts.open" ]] || exit 0
# Build URL candidates
awk '{print "http://" $1; print "https://" $1}' "$OUT/hosts.open" | sort -u > "$OUT/urls.candidates"
echo "[*] httpx probe"
httpx -l "$OUT/urls.candidates" -title -tech-detect -status-code -tls-grab -json \
  -o "$OUT/httpx.json" || true
# TLS posture on common TLS ports
grep -E ':(443|8443)$' "$OUT/open.ports" | cut -d: -f1 | sort -u > "$OUT/tls.hosts" || true
if [[ -s "$OUT/tls.hosts" ]]; then
  echo "[*] testssl.sh (fast)"
  xargs -a "$OUT/tls.hosts" -n1 -I{} bash -lc 'testssl.sh --fast --openssl-timeout 2 {}' \
    | tee "$OUT/testssl.txt" || true
fi
# Extract live URLs
if command -v jq >/dev/null 2>&1; then
  jq -r '.[].url' "$OUT/httpx.json" | sort -u > "$OUT/urls.live"
else
  grep -oE '"url":"[^"]+"' "$OUT/httpx.json" | cut -d'"' -f4 | sort -u > "$OUT/urls.live"
fi
# Crawl + screenshots if tools exist
if [[ -s "$OUT/urls.live" ]]; then
  echo "[*] katana crawl"
  katana -list "$OUT/urls.live" -o "$OUT/urls.katana.txt" || true
  if command -v gowitness >/dev/null 2>&1; then
    echo "[*] screenshots (gowitness)"
    mkdir -p "$EVID/screens"
    gowitness file -f "$OUT/urls.live" --threads 8 --timeout 10 --disable-ssl \
      --destination "$EVID/screens" --db-path "$EVID/gowitness.sqlite" || true
  fi
fi