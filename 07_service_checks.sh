#!/usr/bin/env bash
# Non-web service enumeration (safe/read-only)
set -Eeuo pipefail
OUT="${1:-$HOME/out}"
mkdir -p "$OUT/services"
OPEN_PORTS="$OUT/open.ports"
# If no open ports, nothing to do
[[ -s "$OPEN_PORTS" ]] || { echo "[i] $OPEN_PORTS missing/empty; skipping service checks."; exit 0; }
# Helpers
hosts_for_port() { awk -F: -v p="$1" '$2==p{print $1}' "$OPEN_PORTS" | sort -u; }
have() { command -v "$1" >/dev/null 2>&1; }
# Run nmap over a big host list in chunks to avoid arg limits
nmap_chunked() {
  local outfile="$1"; shift
  # read host list from stdin; run nmap in chunks of 128 hosts
  awk '{print $1}' | xargs -r -n128 -P 1 nmap "$@" -oN "$outfile" --append-output
}
echo "[*] Service checks â†’ output in $OUT/services"
################################
# SSH (22) - ssh-audit (safe)
################################
if have ssh-audit; then
  SSH_HOSTS="$(hosts_for_port 22 || true)"
  if [[ -n "$SSH_HOSTS" ]]; then
    echo "[*] ssh-audit on $(echo "$SSH_HOSTS" | wc -w) host(s)"
    mkdir -p "$OUT/services/ssh"
    if have parallel; then
      # Use GNU parallel if available
      parallel -j 8 --will-cite --lb \
        'ssh-audit -n {}:22 > "'"$OUT"'/services/ssh/{}.txt" 2>/dev/null || true' \
        ::: $SSH_HOSTS || true
    else
      # Fallback to xargs concurrency
      echo $SSH_HOSTS | tr ' ' '\n' | \
        xargs -r -n1 -P 8 -I{} bash -lc 'ssh-audit -n {}:22 > "'"$OUT"'/services/ssh/{}.txt" 2>/dev/null || true'
    fi
  fi
fi
################################
# RDP (3389) - encryption info
################################
RDP_HOSTS="$(hosts_for_port 3389 || true)"
if [[ -n "$RDP_HOSTS" ]]; then
  echo "[*] nmap rdp-enum-encryption"
  : > "$OUT/services/rdp_enum.txt"
  echo $RDP_HOSTS | tr ' ' '\n' | nmap_chunked "$OUT/services/rdp_enum.txt" -Pn -n --script rdp-enum-encryption -p3389 || true
fi
################################
# SMB (445) - info/security mode
################################
SMB_HOSTS="$(hosts_for_port 445 || true)"
if [[ -n "$SMB_HOSTS" ]]; then
  echo "[*] nmap smb2-security-mode,smb-os-discovery"
  : > "$OUT/services/smb_info.txt"
  echo $SMB_HOSTS | tr ' ' '\n' | nmap_chunked "$OUT/services/smb_info.txt" -Pn -n --script "smb2-security-mode,smb2-time,smb-os-discovery,smb2-capabilities" -p445 || true
fi
################################
# LDAP (389) - anonymous search (safe)
################################
LDAP389_HOSTS="$(hosts_for_port 389 || true)"
if [[ -n "$LDAP389_HOSTS" ]]; then
  echo "[*] nmap ldap-search (389)"
  : > "$OUT/services/ldap_search.txt"
  echo $LDAP389_HOSTS | tr ' ' '\n' | nmap_chunked "$OUT/services/ldap_search.txt" -Pn -n --script ldap-search -p389 || true
fi
################################
# WinRM (5985/5986) - auth methods
################################
WINRM_HOSTS="$( (hosts_for_port 5985; hosts_for_port 5986) | sort -u || true)"
if [[ -n "$WINRM_HOSTS" ]]; then
  echo "[*] nmap http-windows-auth (WinRM)"
  : > "$OUT/services/winrm_auth.txt"
  echo $WINRM_HOSTS | tr ' ' '\n' | nmap_chunked "$OUT/services/winrm_auth.txt" -Pn -n --script http-windows-auth -p5985,5986 || true
fi
################################
# MSSQL (1433) - info/NTLM info
################################
MSSQL_HOSTS="$(hosts_for_port 1433 || true)"
if [[ -n "$MSSQL_HOSTS" ]]; then
  echo "[*] nmap ms-sql-info,ms-sql-ntlm-info"
  : > "$OUT/services/mssql_info.txt"
  echo $MSSQL_HOSTS | tr ' ' '\n' | nmap_chunked "$OUT/services/mssql_info.txt" -Pn -n --script "ms-sql-info,ms-sql-ntlm-info" -p1433 || true
fi
################################
# MySQL (3306) - info/empty password (safe)
################################
MYSQL_HOSTS="$(hosts_for_port 3306 || true)"
if [[ -n "$MYSQL_HOSTS" ]]; then
  echo "[*] nmap mysql-info,mysql-empty-password"
  : > "$OUT/services/mysql_info.txt"
  echo $MYSQL_HOSTS | tr ' ' '\n' | nmap_chunked "$OUT/services/mysql_info.txt" -Pn -n --script "mysql-info,mysql-empty-password" -p3306 || true
fi
################################
# PostgreSQL (5432) - version
################################
PG_HOSTS="$(hosts_for_port 5432 || true)"
if [[ -n "$PG_HOSTS" ]]; then
  echo "[*] nmap pgsql-version"
  : > "$OUT/services/pgsql_info.txt"
  echo $PG_HOSTS | tr ' ' '\n' | nmap_chunked "$OUT/services/pgsql_info.txt" -Pn -n --script pgsql-version -p5432 || true
fi
################################
# Redis (6379) - info (safe)
################################
REDIS_HOSTS="$(hosts_for_port 6379 || true)"
if [[ -n "$REDIS_HOSTS" ]]; then
  echo "[*] nmap redis-info"
  : > "$OUT/services/redis_info.txt"
  echo $REDIS_HOSTS | tr ' ' '\n' | nmap_chunked "$OUT/services/redis_info.txt" -Pn -n --script redis-info -p6379 || true
fi
################################
# VNC (5900-5905) - info
################################
VNC_HOSTS="$(awk -F: '$2 ~ /^590[0-5]$/ {print $1}' "$OPEN_PORTS" | sort -u || true)"
if [[ -n "$VNC_HOSTS" ]]; then
  echo "[*] nmap vnc-info"
  : > "$OUT/services/vnc_info.txt"
  echo $VNC_HOSTS | tr ' ' '\n' | nmap_chunked "$OUT/services/vnc_info.txt" -Pn -n --script vnc-info -p5900-5905 || true
fi
################################
# DNS (53) - recursion
################################
DNS_HOSTS="$(hosts_for_port 53 || true)"
if [[ -n "$DNS_HOSTS" ]]; then
  echo "[*] nmap dns-recursion"
  : > "$OUT/services/dns_recursion.txt"
  echo $DNS_HOSTS | tr ' ' '\n' | nmap_chunked "$OUT/services/dns_recursion.txt" -Pn -n --script dns-recursion -p53 || true
fi
################################
# NFS (2049) - showmount
################################
NFS_HOSTS="$(hosts_for_port 2049 || true)"
if [[ -n "$NFS_HOSTS" ]]; then
  echo "[*] nmap nfs-showmount"
  : > "$OUT/services/nfs_showmount.txt"
  echo $NFS_HOSTS | tr ' ' '\n' | nmap_chunked "$OUT/services/nfs_showmount.txt" -Pn -n --script nfs-showmount -p2049 || true
fi
################################
# SNMP (161) - ONLY if communities file present/approved
################################
SNMP_HOSTS="$(hosts_for_port 161 || true)"
if [[ -n "$SNMP_HOSTS" && -s "$OUT/snmp_communities.txt" && $(have snmpwalk && echo ok) == "ok" ]]; then
  echo "[*] SNMP sysDescr (approved communities)"
  : > "$OUT/services/snmp_sysdescr.txt"
  while read -r H; do
    while read -r COMM; do
      timeout 3 snmpwalk -v2c -c "$COMM" -OQv "$H" 1.3.6.1.2.1.1.1.0 \
        >> "$OUT/services/snmp_sysdescr.txt" 2>/dev/null || true
    done < "$OUT/snmp_communities.txt"
  done <<< "$SNMP_HOSTS"
fi
echo "[+] Service checks complete."