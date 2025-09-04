#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/../config/config.env"
OUT="${1:-$HOME/out}"; mkdir -p "$OUT"
CIDRS=$(echo "$CIDRS" | tr ',' ' ')
: "${CIDRS:?Set CIDRS in config.env}"
: > "$OUT/live.txt"
for NET in $CIDRS; do
  echo "[*] Discovery on $NET"
  if ! fping -a -g "$NET" 2>/dev/null | sort -u | tee "$OUT/live.$(echo "$NET"|tr '/' '_').icmp.txt"; then
    echo "[!] ICMP blocked? TCP SYN ping on 80,443"
    nmap -n -sn -PS80,443 "$NET" -oG - | awk '/Up$/{print $2}' | sort -u \
      | tee "$OUT/live.$(echo "$NET"|tr '/' '_').tcp.txt"
  fi
done
cat "$OUT"/live.*.txt 2>/dev/null | sort -u > "$OUT/live.txt"
wc -l "$OUT/live.txt" | sed 's/^/[+] Live hosts: /'
