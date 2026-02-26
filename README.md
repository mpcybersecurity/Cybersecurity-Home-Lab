# CyberLab — One-Click Cybersecurity Home Lab

> **Built by [MP Cybersecurity](https://mpcybersecurity.co.uk) | Marius Poskus, CISM**
> For anyone learning offensive and defensive security — no hypervisor experience required.

[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-blue)](https://www.microsoft.com/windows)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue)](https://docs.microsoft.com/powershell)
[![VirtualBox](https://img.shields.io/badge/VirtualBox-Latest-orange)](https://www.virtualbox.org)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

---

## What Is This?

CyberLab is a single PowerShell script that builds a complete, fully networked cybersecurity home lab on your Windows PC — automatically.

**You run one script. You get a working lab.**

No manual VirtualBox configuration. No ISO installations. No networking headaches. The script downloads the latest stable versions of everything, verifies checksums, configures the virtual network, and hands you a credential sheet when it's done.

The lab is designed for one specific learning outcome: **attack from one machine and immediately watch those attacks being detected on another.** This is the fastest way to understand both offensive and defensive security at the same time.

---

## What Gets Built

```
┌─────────────────────────────────────────────────────────────────┐
│                     CyberLab Network                            │
│                                                                 │
│   ┌─────────────┐      ┌──────────────────────┐                │
│   │ KALI LINUX  │      │   SECURITY ONION     │                │
│   │  Attacker   │      │  Defender / Monitor  │                │
│   │             │      │                      │                │
│   │ eth0: NAT   │      │ eth0: NAT (web UI)   │                │
│   │ eth1: Lab ──┼──────┼── eth1: PROMISCUOUS  │                │
│   └──────┬──────┘      └──────────────────────┘                │
│          │  CyberLab Internal Network (192.168.100.0/24)        │
│          ├───────────────────────┐                             │
│   ┌──────┴──────┐      ┌─────────┴───────────┐                │
│   │ METASPLOIT- │      │   BASIC PENTESTING  │                │
│   │   ABLE 2   │      │         1            │                │
│   │   Target   │      │       Target         │                │
│   │  (no net)  │      │     (no net)         │                │
│   └────────────┘      └─────────────────────┘                 │
└─────────────────────────────────────────────────────────────────┘
```

| VM | Role | What it does |
|----|------|-------------|
| **Kali Linux** | Attacker | Full offensive toolkit — Metasploit, nmap, Burp Suite, Wireshark, 600+ tools |
| **Security Onion** | Defender / Monitor | Suricata IDS, Zeek logs, full packet capture, web dashboard — see attacks happen in real time |
| **Metasploitable 2** | Target | Classic intentionally vulnerable Linux — FTP backdoors, weak SSH, unpatched services, web vulnerabilities |
| **Basic Pentesting 1** | Target | VulnHub machine — web server, SSH, privilege escalation paths, beginner-friendly |

---

## System Requirements

### Minimum

| Component | Minimum |
|-----------|---------|
| OS | Windows 10 64-bit (build 18362+) or Windows 11 |
| RAM | **16 GB** (Security Onion requires 12 GB alone) |
| Free Disk | **150 GB** (SSD strongly preferred) |
| CPU | 4 cores with **VT-x or AMD-V enabled in BIOS** |
| Internet | Required during setup (~8 GB download) |

### Recommended

| Component | Recommended |
|-----------|-------------|
| RAM | **32 GB** (comfortable performance with all VMs running) |
| Free Disk | **250 GB+** NVMe SSD |
| CPU | 6–8 cores |

> **⚠ Hyper-V Note:** VirtualBox and Hyper-V cannot run simultaneously. If you use WSL 2 or Docker Desktop (Hyper-V backend), you must disable Hyper-V first. The script will detect this and tell you exactly what to run.

---

## Quick Start

### 1. Check your system meets the requirements above

Specifically: VT-x/AMD-V enabled in BIOS, 16 GB+ RAM, 150 GB+ free disk.

### 2. Download CyberLab

```
git clone https://github.com/mpcybersecurity/cybersecurity-home-lab.git
cd cyberlab
```

Or [download the ZIP](https://github.com/mpcybersecurity/cyberlab/archive/refs/heads/main.zip) and extract it.

### 3. (Optional) Edit `config.ps1`

Open `config.ps1` to change the storage location, RAM allocations, or VM names. Defaults work for most setups.

### 4. Run the script

**Right-click `Start-CyberLab.ps1` → "Run with PowerShell"**

Or from an elevated PowerShell prompt:
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
.\Start-CyberLab.ps1
```

The script will self-elevate to Administrator if needed.

### 5. Wait and follow prompts

Total time: **45–75 minutes** (mostly download time, depending on your connection).

The only step requiring your input is the **Security Onion first-boot wizard** (~3 minutes). The script pauses and gives you step-by-step instructions when this happens.

### 6. Lab is ready

A credential sheet prints to the console and saves to `C:\CyberLab\LAB-CREDENTIALS.txt`.

---

## What the Script Does — Step by Step

| Step | What happens |
|------|-------------|
| **0** | Checks system requirements: RAM, disk, CPU virtualisation, Hyper-V conflict, internet, PowerShell version |
| **1** | Fetches the **latest VirtualBox version** from Oracle, downloads and silently installs it + the Extension Pack. Also installs 7-Zip for Kali extraction. |
| **2** | Creates the `CyberLab` internal network — the isolated virtual switch all target VMs connect to |
| **3** | Fetches the **latest Kali Linux** VirtualBox image from the official CDN, extracts and imports it, sets up two network adapters (NAT + lab) |
| **4** | Fetches the **latest Security Onion** ISO via GitHub Releases API, creates a 100 GB VM, configures the promiscuous monitoring adapter, starts the VM, and pauses for the 3-minute first-boot wizard |
| **5** | Downloads Metasploitable 2, extracts the VMDK, creates a VM around it, attaches to lab network only (no internet) |
| **6** | Downloads Basic Pentesting 1 OVA from VulnHub, imports it, attaches to lab network only (no internet) |
| **7** | Prints credential sheet, saves it to a file, shows the first-attack quickstart guide |

---

## Version Checking

Every run checks for the **latest stable version** of each component:

| Component | How version is resolved |
|-----------|------------------------|
| **VirtualBox** | `https://download.virtualbox.org/virtualbox/LATEST.TXT` — Oracle's official latest version file |
| **VirtualBox Extension Pack** | Matched automatically to the VirtualBox version |
| **7-Zip** | Parsed from 7-zip.org download page |
| **Kali Linux** | `https://cdimage.kali.org/kali-images/kali-last-snapshot/` — Kali's official latest-release directory |
| **Security Onion** | GitHub Releases API: `api.github.com/repos/Security-Onion-Solutions/securityonion/releases/latest` |
| **Metasploitable 2** | Static (v2.0.0 — this machine hasn't been updated by design; SHA256 verified) |
| **Basic Pentesting 1** | Static (VulnHub CDN — stable URL, SHA256 verified where available) |

All downloads are verified with SHA256 checksums before being used.

---

## After Setup — Using Your Lab

### Start the lab

Open VirtualBox. You'll see four VMs. Start them in this order:

1. **Security Onion** — wait for it to fully boot (~2 min)
2. **Metasploitable 2** — start headless or with GUI
3. **Basic Pentesting 1** — start headless or with GUI
4. **Kali Linux** — your main working machine

### Find target IPs

From Kali terminal:
```bash
sudo netdiscover -r 192.168.100.0/24
```
Or:
```bash
nmap -sn 192.168.100.0/24
```

### Set Kali's lab IP (do once after first boot)

```bash
sudo ip addr add 192.168.100.10/24 dev eth1
sudo ip link set eth1 up
```

### Access Security Onion web dashboard

Get Security Onion's management IP:
```bash
# In the Security Onion VM terminal:
ip a show eth0
```
Then open `https://[that-IP]` in your browser on the host machine.

Login with the email + password you set during the first-boot wizard.

---

## Your First Attack (5 minutes)

Run these from Kali. Keep the Security Onion dashboard open — watch it react.

**Step 1 — Scan Metasploitable 2**
```bash
nmap -sS -sV -O [METASPLOITABLE-IP]
```
→ Within seconds, Suricata fires alerts in Security Onion. Check the Alerts tab.

**Step 2 — Exploit a known vulnerability**
```bash
msfconsole
use exploit/unix/ftp/vsftpd_234_backdoor
set RHOSTS [METASPLOITABLE-IP]
run
```
→ You get a root shell. Security Onion logs the entire session in Zeek. Check Hunt → search for your Kali IP.

**Step 3 — Review the detection evidence**
- **Alerts** → Suricata IDS alerts triggered by your attack
- **Hunt** → Full session logs from Zeek
- **PCAP** → Download the raw packet capture — see every byte of the exploit
- **Dashboards** → Visual overview of all lab traffic

This is the full attack-detect-investigate loop in under 5 minutes.

---

## What to Practice

### Offensive (from Kali)

| Technique | Tool | Target |
|-----------|------|--------|
| Port scanning | `nmap` | Metasploitable 2, Basic Pentesting 1 |
| Service enumeration | `nmap -sV`, `netcat` | Both targets |
| Exploitation | `msfconsole` | Metasploitable 2 (dozens of modules available) |
| Web app attacks | `Burp Suite`, `nikto`, `sqlmap` | Metasploitable 2 (port 80), Basic Pentesting 1 |
| Brute force | `hydra`, `medusa` | SSH, FTP on both targets |
| Password cracking | `john`, `hashcat` | After gaining access and extracting hashes |
| Privilege escalation | Manual enumeration | Both targets |

### Defensive (in Security Onion)

| Activity | Where in Security Onion |
|----------|------------------------|
| Watch IDS alerts fire in real time | Alerts tab |
| Investigate a suspicious IP | Hunt → search source IP |
| Analyse a full session | Hunt → filter by connection UID |
| Download and open a PCAP | PCAP tab → open in Wireshark on Kali |
| Write a custom detection rule | Suricata custom rules via `so-rule` |
| Build a detection case | Cases tab → create investigation |

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "VT-x is not available" | Enable VT-x/AMD-V in BIOS. Restart PC, press F2/F10/Del on boot, find Virtualization setting, enable it. |
| Hyper-V conflict detected | Run in elevated PS: `bcdedit /set hypervisorlaunchtype off` then restart. Re-enable with: `bcdedit /set hypervisorlaunchtype auto` |
| Not enough RAM | Close other applications. If host has only 16 GB, reduce `$KaliRAM` to 1024 in `config.ps1` to free up space. |
| Download fails repeatedly | Check internet connection. BITS will retry automatically 3 times. Delete the partial file from `C:\CyberLab\Downloads\` and re-run. |
| VirtualBox install fails | Uninstall any existing VirtualBox version first via Settings → Apps. Re-run the script. |
| Security Onion won't start | Verify RAM: `$SoRAM` must be at least 12288 in `config.ps1`. Lower values cause crash on boot. |
| Security Onion shows no alerts | The monitoring interface (eth1) must be promiscuous. Run: `VBoxManage modifyvm CyberLab-SecurityOnion --nicpromisc2 allow-all` |
| Can't find target VM IPs | From Kali: `sudo netdiscover -r 192.168.100.0/24` or `nmap -sn 192.168.100.0/24` |
| PowerShell script blocked | Run: `Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process` in an elevated PS window, then re-run. |
| Script stops mid-way | Check `C:\CyberLab\cyberlab-setup.log` for the exact error. Most failures include a specific fix in the error message. |
| Kali OVA extraction fails | 7-Zip should install automatically. If it didn't, install from [7-zip.org](https://www.7-zip.org) and re-run. |

---

## File Structure

```
cyberlab/
├── Start-CyberLab.ps1          ← Run this (entry point)
├── config.ps1                  ← Customise RAM, paths, VM names here
├── REQUIREMENTS.md             ← Detailed architecture and design document
├── README.md                   ← This file
└── modules/
    ├── Helpers.ps1             ← Shared functions (download, VBoxManage, logging)
    ├── 00-Prerequisites.ps1    ← System requirement checks
    ├── 01-VirtualBox.ps1       ← VirtualBox + Extension Pack + 7-Zip install
    ├── 02-Networking.ps1       ← Lab network setup and documentation
    ├── 03-Kali.ps1             ← Kali Linux download + import + configure
    ├── 04-SecurityOnion.ps1    ← Security Onion download + VM + wizard
    ├── 05-Metasploitable.ps1   ← Metasploitable 2 download + import + configure
    ├── 06-VulnHub.ps1          ← Basic Pentesting 1 download + import + configure
    └── 07-Summary.ps1          ← Credential sheet + first-attack guide
```

---

## Configuration Reference

All settings live in `config.ps1`. Common adjustments:

| Setting | Default | When to change |
|---------|---------|----------------|
| `$LabPath` | `C:\CyberLab` | Change if C: drive doesn't have space |
| `$KaliRAM` | `2048` | Reduce to `1024` if tight on RAM |
| `$SoRAM` | `12288` | **Do not go below 12288** — Security Onion will crash |
| `$HeadlessTargets` | `$true` | Set to `$false` to see target VMs in windows |
| `$StartVMsOnDone` | `$false` | Set to `$true` to auto-start all VMs after setup |
| `$SkipIfExists` | `$true` | Set to `$false` to force re-import of existing VMs |
| `$VulnVMUrl` | VulnHub CDN URL | Replace with any other VulnHub OVA URL to swap the extra target |

---

## Adding More VulnHub Machines

To add any other VulnHub machine to the lab:

1. Find a VM on [vulnhub.com](https://www.vulnhub.com) with an OVA or VMDK download
2. Set `$VulnVMUrl` in `config.ps1` to the download URL
3. Set `$VulnVMName` to what you want it called in VirtualBox
4. Re-run the script — it will skip existing VMs and only add the new one

Good beginner VulnHub machines to try next:
- [Mr. Robot: 1](https://www.vulnhub.com/entry/mr-robot-1,151/) — web, brute force, privilege escalation
- [DC: 1](https://www.vulnhub.com/entry/dc-1,292/) — Drupal, Linux enumeration
- [Kioptrix Level 1](https://www.vulnhub.com/entry/kioptrix-level-1-1,22/) — classic SMB exploitation

---

## Security Notice

**This lab is for educational use on your own machine only.**

- Target VMs are intentionally vulnerable. They have no internet access (by design).
- Do not bridge these VMs to your home network — they will be accessible to other devices.
- Do not run these VMs on corporate or shared networks.
- The lab is isolated to the CyberLab internal network. Only Kali and Security Onion have NAT internet access.

---

## Learn More

This lab was built by **Marius Poskus** — a CISM-certified fractional CISO and cybersecurity educator.

- **Website:** [mpcybersecurity.co.uk](https://mpcybersecurity.co.uk)
- **Podcast:** [Cyber Diaries](https://mpcybersecurity.co.uk/podcast) — weekly conversations with CISOs, founders, and security practitioners
- **YouTube:** [@mpcybersecurity](https://www.youtube.com/@mpcybersecurity) (CTRL+ALT+DEFEND)
- **LinkedIn:** [Marius Poskus](https://uk.linkedin.com/in/marius-poskus)
- **vCISO Services:** [mpcybersecurity.co.uk/virtual-ciso](https://mpcybersecurity.co.uk/virtual-ciso)

If this lab helped you — share it with someone else learning security.

---

## Contributing

PRs welcome. Particularly useful contributions:
- Additional VulnHub module (e.g. `06b-MrRobot.ps1`)
- Bash version for Linux/Mac hosts
- Automated Security Onion setup via guestcontrol (advanced)
- ARM64 / Apple Silicon support via UTM

Please open an issue before starting significant work.

---

## Licence

MIT — free to use, share, and modify. Attribution appreciated.

---

*CyberLab by [MP Cybersecurity](https://mpcybersecurity.co.uk) — mpcybersecurity.co.uk*
