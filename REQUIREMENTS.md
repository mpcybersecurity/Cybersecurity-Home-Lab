# CyberLab — Home Lab Automation Script
## Requirements & Architecture Document
> Version 1.0 | February 2026
> For: Marius Poskus cybersecurity education audience
> Status: Pre-implementation planning document

---

## 1. Overview

### What This Is

CyberLab is a one-click PowerShell script that automatically builds and deploys a fully networked cybersecurity home lab on Windows using VirtualBox.

A student runs a single script. The script installs VirtualBox, downloads and configures all virtual machines, sets up a private internal network, and produces a credential sheet. The student ends up with a working attack-and-defend lab without needing to understand hypervisors, networking, or Linux installation.

### What the Lab Contains

| VM | Role | Purpose |
|----|------|---------|
| **Kali Linux** | Attacker | Offensive tools — Metasploit, nmap, Burp Suite, Wireshark, and 600+ pre-installed tools |
| **Security Onion** | Defender / Monitor | Network traffic analysis, IDS alerts, log aggregation — visualise attacks as they happen |
| **Metasploitable 2** | Target | Intentionally vulnerable Linux — dozens of exploitable services |
| **DVWA** | Target | Damn Vulnerable Web Application — SQLi, XSS, LFI, command injection |

### What Students Can Practice

- **Offensive:** Port scanning, service enumeration, exploitation with Metasploit, web application attacks, privilege escalation
- **Defensive:** Watching Suricata IDS fire alerts in Security Onion as Kali attacks, analysing Zeek logs, investigating network flows, building detection rules
- **The feedback loop:** Attack from Kali → watch Security Onion detect it → understand what the attack looks like from both sides simultaneously

---

## 2. System Requirements

### Minimum — will work, performance will be slow

| Component | Minimum |
|-----------|---------|
| **RAM** | 16 GB host RAM |
| **Disk** | 250 GB free space (SSD strongly preferred) |
| **CPU** | 4 physical cores with VT-x or AMD-V enabled |
| **OS** | Windows 10 64-bit (version 1903 or later) or Windows 11 |
| **Virtualization** | VT-x / AMD-V enabled in BIOS (usually on by default on modern hardware) |

### Recommended — comfortable performance

| Component | Recommended |
|-----------|-------------|
| **RAM** | 32 GB host RAM |
| **Disk** | 500 GB free space, NVMe SSD |
| **CPU** | 6–8 physical cores |
| **OS** | Windows 11 64-bit |
| **Virtualization** | VT-x / AMD-V + SLAT enabled in BIOS |

### Why Security Onion drives the requirements

Security Onion 2.4 in Evaluation mode requires a minimum of **12 GB RAM allocated to the VM**. This is the binding constraint. On a 16 GB host:
- Security Onion: 12 GB
- Kali Linux: 2 GB
- Remaining VMs: share ~1 GB (tight — Metasploitable 2 and DVWA run fine on 512 MB each)
- Host OS: remaining ~1 GB (very tight)

On a 16 GB machine, the lab will run but the host may feel sluggish while all VMs are active. 32 GB is the comfortable starting point.

### Disk space breakdown

| Component | Download Size | Installed Size |
|-----------|-------------|----------------|
| VirtualBox 7.2.6 | ~110 MB | ~350 MB |
| Kali Linux 2025.4 OVA | ~3 GB (compressed) | ~14 GB (VM disk) |
| Security Onion 2.4 ISO | ~3.5 GB | ~100 GB (VM disk, dynamically allocated) |
| Metasploitable 2 | ~800 MB (compressed) | ~8 GB (VM disk) |
| DVWA OVA | ~500 MB | ~4 GB (VM disk) |
| **Total download** | **~8 GB** | |
| **Total installed** | | **~126 GB** |

**Minimum free disk before running:** 150 GB (to allow headroom).

### Virtualization check

The script will check for VT-x/AMD-V automatically. If it is not enabled, the script will exit with instructions. To enable manually:
1. Restart the PC
2. Enter BIOS (usually F2, F10, Delete, or Esc on startup)
3. Find "Virtualization Technology," "Intel VT-x," or "AMD-V" — set to Enabled
4. Save and restart

---

## 3. Software Prerequisites

The script handles all of these automatically. This section documents what gets installed.

| Software | Version | How installed |
|----------|---------|---------------|
| **VirtualBox** | 7.2.6 | Script downloads and silently installs |
| **VirtualBox Extension Pack** | 7.2.6 (matched) | Script installs via VBoxManage |
| **Kali Linux** | 2025.4 | Pre-built OVA downloaded and imported |
| **Security Onion** | 2.4.201 | ISO downloaded, VM created and configured |
| **Metasploitable 2** | 2.0.0 | OVA/VMDK downloaded and imported |
| **DVWA** | Latest | OVA downloaded and imported |

**No manual software installation required from the student.** The script runs as Administrator and handles everything.

---

## 4. Network Architecture

### Design Principles

1. **Isolation** — vulnerable VMs must not have internet access. If Metasploitable 2 reaches the internet, it is a risk to the student's network and to others.
2. **Visibility** — Security Onion must see all traffic between Kali and the targets, without being in the traffic path (passive monitoring).
3. **Usability** — Kali needs internet access for tool updates. Security Onion needs a management interface for its web UI.

### Network Topology

```
                         ┌─────────────────────┐
                         │   HOST MACHINE        │
                         │   (Windows 11)        │
                         └─────────┬─────────────┘
                                   │
                         ┌─────────┴─────────┐
                         │  VirtualBox NAT   │  ← Internet access
                         └────┬─────────┬────┘
                              │         │
                   ┌──────────┴──┐  ┌───┴──────────────┐
                   │  KALI LINUX │  │  SECURITY ONION   │
                   │  (Attacker) │  │  (Monitor/Defend) │
                   │  eth0: NAT  │  │  eth0: NAT (mgmt) │
                   │  eth1: Lab  │  │  eth1: Lab PROMISC│
                   └──────┬──────┘  └───────┬───────────┘
                          │                 │ (passive - sees all)
                          └────────┬────────┘
                                   │
                     ┌─────────────┴──────────────┐
                     │  CyberLab Internal Network  │
                     │  192.168.100.0/24           │
                     └──────┬──────────────┬───────┘
                            │              │
                 ┌──────────┴──┐    ┌──────┴──────────┐
                 │ METASPLOIT- │    │      DVWA        │
                 │   ABLE 2    │    │  (Web App Target)│
                 │  (Target)   │    │                  │
                 │  eth0: Lab  │    │   eth0: Lab      │
                 └─────────────┘    └──────────────────┘
```

### Network Interfaces Per VM

| VM | Interface | Type | IP | Purpose |
|----|-----------|------|-----|---------|
| Kali Linux | eth0 | VirtualBox NAT | DHCP (10.0.2.x) | Internet access for updates |
| Kali Linux | eth1 | CyberLab Internal | 192.168.100.10 (static) | Attack traffic |
| Security Onion | eth0 | VirtualBox NAT | DHCP (10.0.2.x) | Management UI access |
| Security Onion | eth1 | CyberLab Internal | No IP (promiscuous) | Passive monitoring — sees all traffic |
| Metasploitable 2 | eth0 | CyberLab Internal | 192.168.100.50 (DHCP) | Target — no internet |
| DVWA | eth0 | CyberLab Internal | 192.168.100.51 (DHCP) | Target — no internet |

### Why Promiscuous Mode on Security Onion's eth1

Normally a network interface only receives traffic addressed to it. In promiscuous mode, the interface receives **all** traffic on the network segment — including traffic between other VMs. This is what allows Security Onion to act as a passive network sensor without being in the traffic path. It sees Kali's port scans, exploitation attempts, and shell sessions — all without the targets knowing it is watching.

VirtualBox internal networks support this via `--nicpromisc allow-all`.

### Internal Network Name

The script creates an internal network named `CyberLab` in VirtualBox. This is the virtual switch all lab VMs connect to.

---

## 5. VM Specifications

### Kali Linux

| Setting | Value | Notes |
|---------|-------|-------|
| Source | Pre-built OVA (kali.org) | Avoids unattended ISO install |
| Version | 2025.4 | Latest at time of writing |
| RAM | 2,048 MB | Adequate for GUI + tools |
| CPU | 2 cores | |
| Disk | ~14 GB (dynamic) | Pre-configured in OVA |
| Network 1 | VirtualBox NAT | Internet access |
| Network 2 | CyberLab Internal | Lab attack traffic |
| Default credentials | kali / kali | Student must change on first login |
| Download URL | https://www.kali.org/get-kali/#kali-virtual-machines | Compressed ~3 GB |

### Security Onion

| Setting | Value | Notes |
|---------|-------|-------|
| Source | ISO | No pre-built OVA available |
| Version | 2.4.201 | Latest stable |
| RAM | **12,288 MB** (12 GB) | Hard minimum for evaluation mode |
| CPU | 2 cores | Minimum; 4 recommended |
| Disk | 100 GB (dynamic) | Log storage; grows over time |
| Network 1 | VirtualBox NAT | Management interface — accesses web UI |
| Network 2 | CyberLab Internal | Monitoring interface — promiscuous mode |
| Setup | Semi-automated | 3-minute wizard on first boot (see Section 8) |
| Web UI | https://[management-IP] | Login created during setup wizard |
| ISO URL | https://download.securityonion.net/file/securityonion/securityonion-2.4.201-20260114.iso | ~3.5 GB |

### Metasploitable 2

| Setting | Value | Notes |
|---------|-------|-------|
| Source | SourceForge (Rapid7) | Stable direct download |
| Version | 2.0.0 | Classic — well-documented |
| RAM | 512 MB | Very lightweight |
| CPU | 1 core | |
| Disk | ~8 GB (VMDK) | |
| Network | CyberLab Internal only | No internet access — isolated |
| Default credentials | msfadmin / msfadmin | Intentionally weak |
| Services running | FTP, SSH, Telnet, HTTP, MySQL, PostgreSQL, VNC, Samba, and many more | All intentionally vulnerable |
| Download URL | https://sourceforge.net/projects/metasploitable/files/Metasploitable2/metasploitable-linux-2.0.0.zip/download | ~800 MB |

### DVWA (Damn Vulnerable Web Application)

| Setting | Value | Notes |
|---------|-------|-------|
| Source | OVA / configured appliance | |
| RAM | 512 MB | Minimal web server VM |
| CPU | 1 core | |
| Disk | ~4 GB | |
| Network | CyberLab Internal only | No internet access — isolated |
| Services | Apache + PHP + MySQL with DVWA | Web app vulnerabilities |
| Access URL | http://192.168.100.51/dvwa | From Kali browser |
| Default credentials | admin / password | Intentionally weak |
| Vulnerabilities | SQLi, XSS (stored/reflected), CSRF, LFI, command injection, file upload, brute force | Graduated difficulty levels |

---

## 6. Script Architecture

### Entry Point

`Start-CyberLab.ps1` — the only file a student interacts with. Right-click → "Run with PowerShell." Requires Administrator.

The script runs as an orchestrator — it calls each module in sequence, checks for failures, and provides clear progress output throughout.

### Module Sequence

```
Start-CyberLab.ps1
│
├── [00] Prerequisites check
│     ├── Running as Administrator?
│     ├── Windows version compatible?
│     ├── CPU virtualization enabled (VT-x/AMD-V)?
│     ├── Available RAM ≥ 16 GB?
│     ├── Free disk ≥ 150 GB on target drive?
│     └── Internet connectivity?
│
├── [01] VirtualBox installation
│     ├── Is VirtualBox already installed? (check registry)
│     ├── Download VirtualBox 7.2.6 installer
│     ├── Verify SHA256 checksum
│     ├── Silent install
│     ├── Download Extension Pack
│     ├── Install Extension Pack via VBoxManage
│     └── Add VBoxManage to PATH
│
├── [02] Network setup
│     ├── Create "CyberLab" internal network (VirtualBox virtual switch)
│     └── Create NAT network for management interfaces
│
├── [03] Kali Linux
│     ├── Download Kali 2025.4 VirtualBox OVA (~3 GB)
│     ├── Verify checksum
│     ├── Import OVA via VBoxManage
│     ├── Set RAM to 2048 MB, CPUs to 2
│     ├── Add second network adapter → CyberLab internal
│     └── Set adapter 1 to VirtualBox NAT
│
├── [04] Security Onion
│     ├── Download Security Onion 2.4.201 ISO (~3.5 GB)
│     ├── Verify checksum
│     ├── Create new VM (no OVA — must be created from scratch)
│     ├── Set RAM to 12288 MB, CPUs to 2
│     ├── Create 100 GB dynamic disk
│     ├── Attach ISO to DVD drive
│     ├── Adapter 1: VirtualBox NAT (management)
│     ├── Adapter 2: CyberLab internal, promiscuous mode allow-all
│     ├── Start VM in GUI mode
│     └── ⚠️ PAUSE — print first-boot wizard instructions (see Section 8)
│
├── [05] Metasploitable 2
│     ├── Download metasploitable-linux-2.0.0.zip (~800 MB)
│     ├── Extract VMDK file
│     ├── Create new VM
│     ├── Attach existing VMDK
│     ├── Set RAM to 512 MB, CPUs to 1
│     ├── Adapter 1: CyberLab internal ONLY
│     └── Start VM headless
│
├── [06] DVWA
│     ├── Download DVWA OVA (~500 MB)
│     ├── Import OVA via VBoxManage
│     ├── Set RAM to 512 MB, CPUs to 1
│     ├── Adapter 1: CyberLab internal ONLY
│     └── Start VM headless
│
└── [07] Summary
      ├── Print credential sheet (all VMs, IPs, usernames, passwords)
      ├── Print Security Onion web UI URL and first-login instructions
      ├── Print "Your first attack" quickstart guide
      └── Print troubleshooting tips
```

### Config File — `config.ps1`

All user-adjustable settings in one place:

```powershell
# CyberLab Configuration
# Edit this file before running Start-CyberLab.ps1 if you want to customise

# VM Storage location (default: C:\CyberLab)
$LabPath = "C:\CyberLab"

# RAM allocations (MB) — adjust based on your host RAM
$KaliRAM    = 2048    # Kali Linux
$SecOnionRAM = 12288  # Security Onion — DO NOT go below 12288
$MsfRAM     = 512     # Metasploitable 2
$DvwaRAM    = 512     # DVWA

# CPU allocations
$KaliCPUs    = 2
$SecOnionCPUs = 2
$MsfCPUs     = 1
$DvwaCPUs    = 1

# Lab network
$LabNetwork  = "CyberLab"
$LabSubnet   = "192.168.100.0/24"
$KaliLabIP   = "192.168.100.10"

# Download directory (temp — cleaned up after install)
$DownloadDir = "$env:TEMP\CyberLab-Downloads"

# Optional extra VulnHub VM (set URL to OVA download link, leave blank to skip)
$ExtraVMUrl  = ""
$ExtraVMName = ""
$ExtraVMRAM  = 512
```

---

## 7. Download Sources and Checksums

All downloads are from official or well-established public sources. The script verifies SHA256 checksums before importing.

| File | Source | URL | Size |
|------|--------|-----|------|
| VirtualBox 7.2.6 | Oracle (official) | https://download.virtualbox.org/virtualbox/7.2.6/VirtualBox-7.2.6-Win.exe | ~110 MB |
| VirtualBox Ext Pack | Oracle (official) | https://download.virtualbox.org/virtualbox/7.2.6/Oracle_VirtualBox_Extension_Pack-7.2.6.vbox-extpack | ~12 MB |
| Kali Linux OVA | Kali.org (official) | https://www.kali.org/get-kali/#kali-virtual-machines | ~3 GB |
| Security Onion ISO | Security Onion Solutions | https://download.securityonion.net/file/securityonion/securityonion-2.4.201-20260114.iso | ~3.5 GB |
| Metasploitable 2 | SourceForge / Rapid7 | https://sourceforge.net/projects/metasploitable/files/Metasploitable2/metasploitable-linux-2.0.0.zip/download | ~800 MB |
| DVWA | GitHub / OVA mirror | TBD — confirm stable OVA source during implementation | ~500 MB |

> **Note on download time:** At a typical 50 Mbps UK broadband connection, the total ~8 GB download takes approximately 25–30 minutes. The script shows real-time progress for each download.

---

## 8. Security Onion First-Boot Setup (Semi-Manual Steps)

Security Onion 2.4 has a first-boot installation wizard that cannot be fully automated without complex guest-additions integration. The script handles all VM creation and configuration, then pauses when Security Onion boots and displays the following instructions to the student.

### What the student sees on screen

```
╔══════════════════════════════════════════════════════════════════════╗
║          SECURITY ONION SETUP — ACTION REQUIRED (3 minutes)         ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  Security Onion has started in the VirtualBox window.               ║
║  Follow these steps in that window now:                             ║
║                                                                      ║
║  1. Log in with:  username: onion   password: onion                 ║
║                                                                      ║
║  2. When the installer starts, choose:                              ║
║       → EVALUATION (for home lab use)                               ║
║                                                                      ║
║  3. Accept the defaults for:                                         ║
║       → Hostname: securityonion                                      ║
║       → Management interface: select the FIRST adapter (NAT)        ║
║       → Monitoring interface: select the SECOND adapter              ║
║                                                                      ║
║  4. Set your Security Onion admin credentials:                       ║
║       → Email: admin@lab.local                                       ║
║       → Password: (choose something you'll remember)                 ║
║                                                                      ║
║  5. When setup completes, note the URL shown (https://x.x.x.x)      ║
║     — this is your Security Onion web dashboard                      ║
║                                                                      ║
║  When setup is complete, press ENTER here to continue...            ║
╚══════════════════════════════════════════════════════════════════════╝
```

### Why this can't be fully automated

Security Onion 2.4's `sosetup` configuration file approach (`sosetup -f config`) works in Linux environments where the ISO can be pre-seeded or where guest tools allow file injection before first boot. In a VirtualBox scenario where we are bootstrapping the VM from scratch:
- We cannot write files into the guest before it has booted
- The setup wizard runs on first boot before any automation tooling is available
- The wizard itself takes under 3 minutes and requires 4 clicks

The alternative — VirtualBox Guest Additions + VBoxManage guestcontrol — requires Guest Additions to be installed in Security Onion first, creating a circular dependency. This is the honest trade-off: 3 minutes of student interaction vs. weeks of brittle automation engineering.

**Future enhancement:** A pre-configured Security Onion OVA could eliminate this step entirely. If Security Onion Solutions ever releases one, the script can be updated.

---

## 9. Lab Use Guide — After Setup

### Access Points

| Resource | How to access | Credentials |
|----------|-------------|-------------|
| Kali Linux | Open VM in VirtualBox — full desktop | kali / kali |
| Security Onion web UI | Browser on host: https://[SO management IP] | Email + password set during setup |
| Metasploitable 2 | SSH from Kali: `ssh msfadmin@192.168.100.50` | msfadmin / msfadmin |
| DVWA web app | Firefox in Kali: http://192.168.100.51/dvwa | admin / password |

### First Attack — Quickstart (nmap → Metasploit → Security Onion)

**Step 1: Open Kali and run a port scan**
```bash
nmap -sS -sV 192.168.100.50
```
Watch Security Onion dashboard — within seconds you will see Suricata fire IDS alerts for the scan.

**Step 2: Exploit a service with Metasploit**
```bash
msfconsole
use exploit/unix/ftp/vsftpd_234_backdoor
set RHOSTS 192.168.100.50
run
```
Security Onion will log the connection and Zeek will record the FTP session.

**Step 3: Review in Security Onion**
- Open Alerts → see Suricata rule triggers
- Open Hunt → search for traffic from 192.168.100.10 (Kali)
- Open PCAP → download and analyse the raw packet capture

This is the core feedback loop — attack and immediately see the detection evidence.

### Security Onion Key Interfaces

| Interface | URL | Purpose |
|-----------|-----|---------|
| Alerts | /alerts | Real-time IDS alerts from Suricata |
| Hunt | /hunt | Interactive threat hunting across all logs |
| Dashboards | /dashboards | Visual summaries of network traffic |
| PCAP | /pcap | Download raw packet captures |
| Cases | /cases | Incident investigation and tracking |

---

## 10. Known Limitations

| Limitation | Impact | Workaround |
|-----------|--------|------------|
| Security Onion requires 3-minute manual setup | Slightly breaks "one-click" promise | Clear instructions provided in-script |
| Total download is ~8 GB | 25–30 min on average broadband | Progress shown, downloads can be resumed |
| Security Onion requires 12 GB RAM | Hard requirement — lab won't run on 8 GB hosts | Requirements check upfront; clear error message |
| Windows only (v1.0) | Linux/Mac students excluded | Bash version planned for v1.1 |
| No Hyper-V compatibility | Hyper-V and VirtualBox conflict on Windows | Script detects Hyper-V and warns; student must disable it |
| DVWA stable OVA source TBD | Download URL may change | Fallback: Docker-based DVWA as alternative |
| VulnHub download rate limits | 3 MB/s cap on direct downloads | Use torrent for additional VMs beyond the included ones |
| Kali OVA direct link format varies | URL format changes between releases | Script fetches latest URL dynamically from kali.org |

### Hyper-V Conflict (Important)

VirtualBox and Hyper-V cannot run simultaneously on Windows. Hyper-V is enabled by default if the student uses:
- WSL 2 (Windows Subsystem for Linux)
- Windows Sandbox
- Docker Desktop (Hyper-V backend)

The script checks for Hyper-V and advises accordingly:
```
⚠️  Hyper-V is enabled on this machine.
    VirtualBox requires Hyper-V to be disabled.

    To disable Hyper-V:
    1. Open an Administrator PowerShell and run:
       bcdedit /set hypervisorlaunchtype off
    2. Restart your PC
    3. Run this script again

    Note: Disabling Hyper-V will stop WSL 2 and Docker Desktop.
    You can re-enable with: bcdedit /set hypervisorlaunchtype auto
```

---

## 11. Troubleshooting Reference

| Error | Cause | Fix |
|-------|-------|-----|
| "VT-x is not available" | Virtualization disabled in BIOS | Enable VT-x/AMD-V in BIOS settings |
| "Not enough memory" | Host RAM < 16 GB, or too many apps open | Close applications; consider reducing SecOnion RAM to 10 GB (minimum, unstable) |
| Security Onion won't start | RAM too low, or Hyper-V conflict | Check RAM allocation; disable Hyper-V |
| Kali can't reach Metasploitable | Network adapters misconfigured | Run: `VBoxManage showvminfo Kali` and verify eth1 is on CyberLab internal |
| Security Onion shows no alerts | Monitoring interface not promiscuous | Run: `VBoxManage modifyvm SecurityOnion --nicpromisc2 allow-all` |
| Download fails / checksum mismatch | Corrupted download or changed file | Delete the file from download directory and re-run the script |
| VirtualBox installer fails | Already installed (different version) | Uninstall existing VirtualBox first, then re-run |
| "Access denied" running script | Not running as Administrator | Right-click `Start-CyberLab.ps1` → "Run with PowerShell" → when prompted, allow admin |
| PowerShell execution policy error | Scripts blocked by execution policy | Run: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser` |

---

## 12. File Structure

```
homelab-setup/
├── Start-CyberLab.ps1           ← Main entry point (run this)
├── config.ps1                   ← User-configurable settings
├── REQUIREMENTS.md              ← This document
├── README.md                    ← Quick start for students
└── modules/
    ├── 00-Prerequisites.ps1     ← System checks
    ├── 01-VirtualBox.ps1        ← VirtualBox install
    ├── 02-Networking.ps1        ← Network creation
    ├── 03-Kali.ps1              ← Kali Linux deploy
    ├── 04-SecurityOnion.ps1     ← Security Onion deploy
    ├── 05-Metasploitable.ps1    ← Metasploitable 2 deploy
    ├── 06-DVWA.ps1              ← DVWA deploy
    └── 07-Summary.ps1           ← Output + credential sheet
```

---

## 13. Implementation Phases

| Phase | Deliverable | Session |
|-------|------------|---------|
| **Phase 0** | This requirements document | Current session |
| **Phase 1** | `00-Prerequisites.ps1` — system checks and error handling | Next session |
| **Phase 2** | `01-VirtualBox.ps1` + `02-Networking.ps1` — base infrastructure | Next session |
| **Phase 3** | `03-Kali.ps1` + `05-Metasploitable.ps1` + `06-DVWA.ps1` — VM deployment | Session 3 |
| **Phase 4** | `04-SecurityOnion.ps1` — Security Onion VM + wizard instructions | Session 3 |
| **Phase 5** | `Start-CyberLab.ps1` orchestrator + `07-Summary.ps1` + `README.md` | Session 4 |
| **Phase 6** | Testing, edge case handling, Hyper-V detection, error recovery | Session 4 |
| **Phase 7** | Bash version for Linux/Mac | Future |

---

## 14. Design Decisions Log

| Decision | Option chosen | Option rejected | Reason |
|----------|-------------|-----------------|--------|
| Script language | PowerShell | Python, Batch | Native on all Windows targets; full VBoxManage access; no dependencies |
| Kali deployment | Pre-built OVA | Install from ISO | OVA import takes 5 min vs. 30 min unattended install; official source |
| Security Onion automation | Semi-automated (3-min wizard) | Full automation via guestcontrol | Circular dependency; wizard is 3 min; engineering cost not worth it |
| Vulnerable VM selection | Metasploitable 2 + DVWA | Other VulnHub machines | Stable download sources; best documentation; most beginner exercises available |
| Network type | VirtualBox Internal Network | Host-only adapter | Internal network provides better isolation; no routing to host network |
| Promiscuous monitoring | eth1 promiscuous on internal | Span port / mirror | VirtualBox internal network with allow-all achieves equivalent effect |
| VM storage | Dynamically allocated disks | Fixed size | Faster setup; disk only grows as needed |

---

*CyberLab Home Lab Setup | Requirements v1.0 | February 2026*
*For Marius Poskus — mpcybersecurity.co.uk*
