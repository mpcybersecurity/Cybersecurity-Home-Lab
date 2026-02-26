# =============================================================================
# Module 07 — Lab Summary
# Prints the final credential sheet, access guide, and first-attack quickstart.
# Also writes a summary file to the lab directory for future reference.
# =============================================================================

$summaryFile = Join-Path $LabPath "LAB-CREDENTIALS.txt"

$summary = @"
╔══════════════════════════════════════════════════════════════════════════╗
║                    CYBERLAB — SETUP COMPLETE                            ║
║                    mpcybersecurity.co.uk                                ║
╚══════════════════════════════════════════════════════════════════════════╝

  Your cybersecurity home lab is ready. All VMs are configured and
  connected to the CyberLab internal network.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  VM CREDENTIALS AND ACCESS

  ┌──────────────────────────────────────────────────────────────────────┐
  │  KALI LINUX (Attacker)                                               │
  │  VM Name: $KaliVMName                                                │
  │  Username: kali          Password: kali                              │
  │  ⚠  CHANGE THESE ON FIRST LOGIN                                     │
  │  Lab IP: $KaliLabIP (set manually — see guide below)                │
  │  How to open: VirtualBox → Select VM → Start                        │
  └──────────────────────────────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────────────────────────────┐
  │  SECURITY ONION (Defender / Monitor)                                 │
  │  VM Name: $SoVMName                                                  │
  │  Web UI: https://[IP shown during setup wizard]                      │
  │  Login: Email + password you set during the wizard                   │
  │  Management interface: eth0 (NAT) — get IP from: ip a               │
  │  Monitor interface: eth1 (promiscuous — no IP, sees all traffic)     │
  └──────────────────────────────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────────────────────────────┐
  │  METASPLOITABLE 2 (Target)                                           │
  │  VM Name: $Msf2VMName                                                │
  │  Username: msfadmin     Password: msfadmin                           │
  │  Lab IP: Assigned via DHCP — find with: netdiscover -r 192.168.100.0/24
  │  Services: FTP(21), SSH(22), Telnet(23), HTTP(80), SMB(139/445),    │
  │            MySQL(3306), PostgreSQL(5432), VNC(5900), more...         │
  └──────────────────────────────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────────────────────────────┐
  │  BASIC PENTESTING 1 (VulnHub Target)                                 │
  │  VM Name: $VulnVMName                                                │
  │  Lab IP: Assigned via DHCP — find with: netdiscover -r 192.168.100.0/24
  │  Services: HTTP(80), SSH(22), FTP(21)                                │
  │  Walkthrough: https://www.vulnhub.com/entry/basic-pentesting-1,216/ │
  └──────────────────────────────────────────────────────────────────────┘

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  FIRST-TIME SETUP (do this once, in Kali)

  1. Open Kali Linux in VirtualBox
  2. Open a terminal and set your static lab IP:
       sudo ip addr add 192.168.100.10/24 dev eth1
       sudo ip link set eth1 up
     To make it permanent, edit /etc/network/interfaces

  3. Find your target IPs:
       sudo netdiscover -r 192.168.100.0/24

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  YOUR FIRST ATTACK (5 minutes)

  From Kali, run these commands. Watch Security Onion simultaneously.

  Step 1 — Port scan Metasploitable 2:
    nmap -sS -sV [METASPLOITABLE-IP]
    → Security Onion will show Suricata alerts for the scan

  Step 2 — Exploit vsftpd backdoor with Metasploit:
    msfconsole
    use exploit/unix/ftp/vsftpd_234_backdoor
    set RHOSTS [METASPLOITABLE-IP]
    run
    → You get a shell. Security Onion logs the session.

  Step 3 — Check Security Onion:
    Open https://[SECURITY-ONION-IP] in your browser
    → Alerts tab: see Suricata IDS alerts from your scan and exploit
    → Hunt tab: search for traffic from 192.168.100.10 (Kali)
    → Dashboards: visual view of all lab traffic

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  FILES

  Lab path:     $LabPath
  Downloads:    $DownloadDir
  Setup log:    $LogFile
  Credentials:  $summaryFile

  Setup completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  LEARN MORE

  YouTube:  @mpcybersecurity (CTRL+ALT+DEFEND)
  Podcast:  Cyber Diaries — mpcybersecurity.co.uk/podcast
  Blog:     mpcybersecurity.co.uk/blog
  Work with us: mpcybersecurity.co.uk/virtual-ciso

"@

# Print to console
Write-Host $summary -ForegroundColor White

# Save credentials file for future reference
$summary | Set-Content -Path $summaryFile -Encoding UTF8
Write-LabSuccess "Credentials saved to: $summaryFile"
Write-Log "Summary written to $summaryFile"

# Open the credentials file
Start-Process notepad $summaryFile
