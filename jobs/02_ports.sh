#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/../config/config.env"
OUT="${1:-$HOME/out}"
[[ -s "$OUT/live.txt" ]] || { echo "No live.txt"; exit 0; }
echo "[*] Port discovery (naabu)"
naabu -list "$OUT/live.txt" -top-ports "$TOP_PORTS" -rate "$RATE" -silent \
  | tee "$OUT/open.ports"
awk -F: '{print $1}' "$OUT/open.ports" | sort -u > "$OUT/hosts.open"
wc -l "$OUT/hosts.open" | sed 's/^/[+] Hosts with open ports: /'
echo "[*] Service fingerprint (nmap)"
nmap -sV --version-light --top-ports 200 -iL "$OUT/hosts.open" -oA "$OUT/nmap_top200" || true
