# Installation

This project relies on several external utilities invoked by the job scripts in `jobs/`.
The table below lists each script and the non-standard commands it uses.

| Job script | External commands |
|------------|------------------|
| `01_discovery.sh` | `fping`, `nmap` |
| `02_ports.sh` | `naabu`, `nmap` |
| `03_web.sh` | `httpx`, `testssl.sh`, `jq`, `katana`, `gowitness` |
| `04_windows_ad.sh` | `nbtscan`, `enum4linux-ng`, `dig`, `ldapsearch`, `bloodhound-python` |
| `05_snmp_tls.sh` | `onesixtyone` |
| `06_vulns_nuclei.sh` | `nuclei` |
| `07_service_checks.sh` | `ssh-audit`, `parallel`, `nmap`, `snmpwalk` |
| `08_vulns_summary.sh` | `jq` |
| `90_reduce_and_report.sh` | `jq` |

## Python requirements
Install Python-based tools with:

```bash
pip install -r requirements.txt
```

## System packages (APT)
Install common command‑line dependencies:

```bash
sudo apt-get update
sudo apt-get install -y fping nmap jq nbtscan dnsutils ldap-utils onesixtyone parallel snmp testssl.sh
```

## Go-based utilities
Ensure Go is installed, then install the following tools:

```bash
go install github.com/projectdiscovery/naabu/v2/cmd/naabu@latest
go install github.com/projectdiscovery/httpx/cmd/httpx@latest
go install github.com/projectdiscovery/katana/cmd/katana@latest
go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go install github.com/sensepost/gowitness@latest
```

These commands install binaries to `$(go env GOPATH)/bin`, so ensure that directory is in your `PATH`.
