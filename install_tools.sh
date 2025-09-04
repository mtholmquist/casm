#!/usr/bin/env bash
# Convenience installer for CASM dependencies
set -euo pipefail

# Install system packages
if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y fping nmap jq nbtscan dnsutils ldap-utils onesixtyone parallel snmp testssl.sh
fi

# Install Python tools
pip install -r requirements.txt
# Ensure enum4linux-ng is installed from its GitHub repository
pip install git+https://github.com/cddmp/enum4linux-ng.git

# Install Go-based utilities
if command -v go >/dev/null 2>&1; then
  go install github.com/projectdiscovery/naabu/v2/cmd/naabu@latest
  go install github.com/projectdiscovery/httpx/cmd/httpx@latest
  go install github.com/projectdiscovery/katana/cmd/katana@latest
  go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
  go install github.com/sensepost/gowitness@latest
fi

echo "[+] Installation complete"
