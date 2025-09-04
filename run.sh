#!/usr/bin/env bash
# Internal ASM orchestrator (robust)
set -Eeo pipefail

BASE="$HOME/internal-asm"
CONF="$BASE/config/config.env"

OUT_ROOT="$HOME/out"         # Windows-backed
EVID_ROOT="$HOME/evidence"   # Windows-backed
ARCH_ROOT="$HOME/archive"    # Windows-backed

# error trap for visibility
trap 'echo "[ERROR] line $LINENO: command exited with $?" >&2' ERR

# dotted-netmask -> CIDR prefix
mask2prefix() {
  case "$1" in
    255.255.255.255) echo 32 ;; 255.255.255.252) echo 30 ;;
    255.255.255.248) echo 29 ;; 255.255.255.240) echo 28 ;;
    255.255.255.224) echo 27 ;; 255.255.255.192) echo 26 ;;
    255.255.255.128) echo 25 ;; 255.255.255.0)   echo 24 ;;
    255.255.254.0)   echo 23 ;; 255.255.252.0)   echo 22 ;;
    255.255.248.0)   echo 21 ;; 255.255.240.0)   echo 20 ;;
    255.255.224.0)   echo 19 ;; 255.255.192.0)   echo 18 ;;
    255.255.128.0)   echo 17 ;; 255.255.0.0)     echo 16 ;;
    255.254.0.0)     echo 15 ;; 255.252.0.0)     echo 14 ;;
    255.248.0.0)     echo 13 ;; 255.240.0.0)     echo 12 ;;
    255.224.0.0)     echo 11 ;; 255.192.0.0)     echo 10 ;;
    255.128.0.0)     echo 9  ;; 255.0.0.0)       echo 8  ;;
    *) echo "" ;;
  esac
}

# ---- prompt for targets ----
if [[ -t 0 ]]; then
  read -rp "Targets (IP/CIDR; comma/space separated): " RAW || {
    echo "[!] No input received." >&2; exit 1; }
else
  echo "[!] No TTY for prompt; run interactively." >&2; exit 1
fi
RAW="${RAW//,/ }"
RAW="$(echo "$RAW" | xargs 2>/dev/null || echo "$RAW")"  # condense whitespace

# ---- parse into normalized CIDRs ----
read -r -a arr <<< "$RAW"
norms=()
i=0
while (( i < ${#arr[@]} )); do
  t="${arr[$i]}"
  if [[ "$t" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
    norms+=( "$t" )
  elif [[ "$t" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    if (( i+1 < ${#arr[@]} )) && [[ "${arr[$i+1]}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
      pfx="$(mask2prefix "${arr[$i+1]}")"
      if [[ -n "$pfx" ]]; then norms+=( "$t/$pfx" ); ((i+=1)); else norms+=( "$t/32" ); fi
    else
      norms+=( "$t/32" )
    fi
  fi
  ((i+=1))   # <â€” SAFE increment (doesn't trip set -e)
done

if (( ${#norms[@]} == 0 )); then
  echo "[!] No valid targets parsed. e.g.: 10.0.0.0/24 | 10.0.0.0 255.255.255.0 | 10.0.0.10" >&2
  exit 1
fi

# ---- ensure config & write CIDRS ----
mkdir -p "$(dirname "$CONF")"
cidr_csv="$(IFS=, ; echo "${norms[*]}")"
if [[ -f "$CONF" ]] && grep -qE '^CIDRS=' "$CONF" 2>/dev/null; then
  sed -i -E "s|^CIDRS=.*$|CIDRS=\"$cidr_csv\"|g" "$CONF"
else
  grep -qE '^CIDRS=' "$CONF" 2>/dev/null || echo "CIDRS=\"$cidr_csv\"" >> "$CONF"
fi

# ---- timestamped label ----
NOW="$(date +%Y%m%d_%H%M%S)"
label_parts=(); for c in "${norms[@]}"; do label_parts+=( "$(echo "$c" | tr '/' '-')" ); done
BASELABEL="$(IFS=__ ; echo "${label_parts[*]}")"
[[ ${#BASELABEL} -gt 80 ]] && BASELABEL="multi_${#norms[@]}nets"
LABEL="${BASELABEL}__${NOW}"

OUT="$OUT_ROOT/$LABEL"
EVID="$EVID_ROOT/$LABEL"
ARCH="$ARCH_ROOT/$LABEL/$NOW"

# ---- validate dirs writable (Windows binds) ----
mkdir -p "$OUT" "$EVID" "$ARCH"
touch "$OUT/.writetest" "$EVID/.writetest" "$ARCH/.writetest"
rm -f "$OUT/.writetest" "$EVID/.writetest" "$ARCH/.writetest"

echo "== Targets: ${norms[*]}"
echo "== OUT  : $OUT"
echo "== EVID : $EVID"
echo "== ARCH : $ARCH"
echo "== Starting pipelineâ€¦"

run_stage () {
  local name="$1"; shift
  echo "[*] $name"
  if "$@"; then
    echo "[+] $name done"
  else
    echo "[WARN] $name failed or skipped" >&2
  fi
}

run_stage "01_discover"            "$BASE/jobs/01_discover.sh"           "$OUT"
run_stage "02_ports"               "$BASE/jobs/02_ports.sh"              "$OUT"
run_stage "03_web"                 "$BASE/jobs/03_web.sh"                "$OUT" "$EVID"
run_stage "07_service_checks"      "$BASE/jobs/07_service_checks.sh"     "$OUT"
run_stage "04_windows_ad"          "$BASE/jobs/04_windows_ad.sh"         "$OUT"
run_stage "05_snmp_tls"            "$BASE/jobs/05_snmp_tls.sh"           "$OUT"
run_stage "06_vulns_nuclei"        "$BASE/jobs/06_vulns_nuclei.sh"       "$OUT"
run_stage "90_reduce_and_report"   "$BASE/jobs/90_reduce_and_report.sh"  "$OUT" "$EVID"

# ---- HITL gate ----
if [[ ! -f "$OUT/APPROVED" ]]; then
  echo "[!] Waiting for HITL approval in $OUT. Touch $OUT/APPROVED to continue."
  exit 2
fi

# ---- archive ----
echo "[*] Archiving artifactsâ€¦"
mkdir -p "$ARCH/out" "$ARCH/evidence"
rsync -a --delete "$OUT/"  "$ARCH/out/"      || true
rsync -a --delete "$EVID/" "$ARCH/evidence/" || true
tar -C "$ARCH_ROOT/$LABEL" -czf "$ARCH_ROOT/$LABEL/run_${NOW}.tgz" "$NOW" || true
echo "[+] Archived to $ARCH_ROOT/$LABEL/run_${NOW}.tgz"