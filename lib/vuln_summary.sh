#!/usr/bin/env bash
# Helper to append vulnerability entries in JSONL format
# Usage: add_vuln <file> <host> <service> <severity> <description>
add_vuln() {
  local _file="$1"; shift
  local _host="$1"; shift
  local _service="$1"; shift
  local _severity="$1"; shift
  local _desc="$*"
  jq -n --arg h "$_host" --arg s "$_service" --arg sev "$_severity" --arg d "$_desc" \
    '{host:$h, service:$s, severity:$sev, description:$d}' >> "$_file"
}
