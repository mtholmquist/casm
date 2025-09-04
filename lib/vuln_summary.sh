#!/usr/bin/env bash
# Helper to append vulnerability entries in JSONL format
# Usage: add_vuln <file> <host> <service> <severity> <description>
add_vuln() {
  local _file="$1"; shift
  local _host="$1"; shift
  local _service="$1"; shift
  local _severity="$1"; shift
  local _desc="$*"
  _desc=${_desc//"/\"}
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg h "$_host" --arg s "$_service" --arg sev "$_severity" --arg d "$_desc" \
      '{host:$h, service:$s, severity:$sev, description:$d}' >> "$_file"
  else
    printf '{"host":"%s","service":"%s","severity":"%s","description":"%s"}\n' \
      "$_host" "$_service" "$_severity" "$_desc" >> "$_file"
  fi
}
