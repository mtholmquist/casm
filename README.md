# CASM

## Overview
CASM is a modular pipeline that performs internal attack-surface reconnaissance and triage. It strings together common open-source tools to discover hosts, enumerate services, and highlight high-signal security findings. Output artifacts, evidence, and reports are generated automatically and gated for human review before ticket creation.

## Repository Layout
```
├── config/                # Configuration defaults (config.env)
├── docs/                  # Supplemental documentation
├── jobs/                  # Individual pipeline stages
├── lib/                   # Helper libraries (e.g., net utilities)
├── tests/                 # Minimal unit tests for helper functions
├── install_tools.sh       # Convenience installer for dependencies
├── requirements.txt       # Python-based tools
├── run.sh                 # Orchestrator script
└── LICENSE                # Apache-2.0 license
```

## Prerequisites
A Unix-like environment with Bash ≥4 and standard coreutils is assumed. The pipeline relies on several external tools. A convenience installer is provided:

```bash
./install_tools.sh
```

This script installs system packages, Python requirements (including `enum4linux-ng` from its GitHub repository), and Go-based utilities. See [docs/install.md](docs/install.md) for a detailed table of job scripts and their external commands as well as manual installation steps.

## Deployment
1. **Clone** this repository onto the orchestrator machine.
2. **Install** dependencies with `./install_tools.sh` or manually per `docs/install.md`.
3. **Adjust permissions** so all `*.sh` files are executable (`chmod +x jobs/*.sh run.sh`).

## Configuration
Edit `config/config.env` before running:

```bash
# --- REQUIRED ---
CIDRS="10.184.208.0/24"     # Comma-separated CIDRs scanned by default

# Port scanning options
TOP_PORTS=1000              # naabu top ports
RATE=1500                   # naabu packet rate

# SMB, SNMP, Nuclei tuning
SMB_THREADS=4
SNMP_COMMUNITIES=""         # leave blank unless explicitly approved
NUCLEI_SEVERITY="critical,high,medium"
NUCLEI_TAGS="cves,exposures,misconfiguration,default-login"
```

Values can be overridden at runtime when `run.sh` prompts for targets.

## Running the Pipeline
```bash
./run.sh
```
The orchestrator performs the following high-level flow:

1. **Target collection** – prompts for IPs/CIDRs, normalizes them, and writes `CIDRS` into `config.env`. Output, evidence, and archive directories are timestamped.
2. Sequentially executes each job script (see details below).
3. After reporting, the pipeline pauses for human-in-the-loop approval before generating ticket stubs.
4. Archives all artifacts to a dated tarball.

### Output Locations
* `~/out/<label>/` – consolidated machine-readable results and reports
* `~/evidence/<label>/` – screenshots and other bulky artifacts
* `~/archive/<label>/` – compressed archive of the run

## Pipeline Stages
| Stage | Script | Description |
|-------|--------|-------------|
| **01 – Discovery** | `jobs/01_discovery.sh` | ICMP sweep via `fping`; if blocked, falls back to `nmap -sn` TCP ping. Builds `live.txt` with responsive hosts. |
| **02 – Port Scan** | `jobs/02_ports.sh` | Uses `naabu` to enumerate top ports and `nmap -sV` for light service fingerprinting. Produces `open.ports`, `hosts.open`, and `nmap_top200.*`. |
| **03 – Web Enumeration** | `jobs/03_web.sh` | Constructs URL candidates from open hosts. `httpx` probes titles/tech/TLS, `testssl.sh` inspects 443/8443, `katana` crawls discovered URLs, and (optionally) `gowitness` captures screenshots. |
| **07 – Service Checks** | `jobs/07_service_checks.sh` | For common non-web services (SSH, RDP, SMB, LDAP, WinRM, SQL, Redis, VNC, DNS, NFS, SNMP) runs safe NSE scripts or helpers (`ssh-audit`, `nmap`, etc.). Extracts simple misconfiguration findings into `services_vulns.jsonl`. |
| **04 – Windows / AD** | `jobs/04_windows_ad.sh` | Windows-specific network recon: `nbtscan`, `enum4linux-ng`, DNS SRV enumeration with `dig`, anonymous LDAP search, and optional BloodHound collection (requires credentials). |
| **05 – SNMP & TLS** | `jobs/05_snmp_tls.sh` | Runs `onesixtyone` against discovered hosts using approved community strings. |
| **06 – Vulnerability Scan** | `jobs/06_vulns_nuclei.sh` | Executes `nuclei` against live URLs, restricted by severity/tags, saving JSONL output. |
| **08 – Vulnerability Summary** | `jobs/08_vulns_summary.sh` | Uses `jq` to combine high/critical nuclei findings with service misconfigurations into `vulns_summary.jsonl`. |
| **90 – Reduce & Report** | `jobs/90_reduce_and_report.sh` | Generates a Markdown report summarizing host counts, notable findings, TLS observations, and includes links to evidence. |
| **HITL Gate** | (built into `run.sh`) | Requires operator confirmation before continuing. Touching `out/APPROVED` or answering `y` permits ticketing. |
| **95 – Ticket Stub** | `jobs/95_ticketing_stub.sh` | Converts sections of the latest report into `tickets/ticket_<timestamp>.md` for manual entry into external systems. |
| **Archive** | (end of `run.sh`) | Synchronizes `out/` and `evidence/` to `archive/` and compresses them. |

## Evidence Review & Ticketing
After the report is generated:

1. Inspect `out/report_<timestamp>.md` and any screenshots/evidence.
2. Approve the run by entering `y` at the prompt (or touching `out/APPROVED` if non-interactive).
3. A ticket stub is created under `out/tickets/` containing high-signal findings. Follow the instructions in **docs/manual_ticketing.md** to copy the stub into Jira/ServiceNow and attach supporting evidence.

## Archiving
Upon completion, artifacts are mirrored into `~/archive/<label>/` and packed as `run_<timestamp>.tgz` for long-term storage or off-host analysis.

## Tests
A minimal unit test exists for the `mask2prefix` helper (`tests/test_mask2prefix.sh`). Run it with:

```bash
tests/test_mask2prefix.sh
```

## License
Licensed under the [Apache License 2.0](LICENSE).

---

The repository provides a flexible starting point for internal attack-surface mapping. Tailor the configuration, extend job scripts, or integrate additional tooling to fit your environment.
