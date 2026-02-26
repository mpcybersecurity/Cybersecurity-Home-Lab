# =============================================================================
# CyberLab Configuration
# =============================================================================
# Edit this file to customise your lab BEFORE running Start-CyberLab.ps1.
# All configurable settings are in this file. Do not edit the module files.
# =============================================================================

# --- Storage ---
# Where VMs and downloads will be stored. Must have 150 GB+ free.
$LabPath      = "C:\CyberLab"
$DownloadDir  = "$LabPath\Downloads"
$LogFile      = "$LabPath\cyberlab-setup.log"

# --- VM Names (change if you want custom names in VirtualBox) ---
$KaliVMName   = "CyberLab-Kali"
$SoVMName     = "CyberLab-SecurityOnion"
$Msf2VMName   = "CyberLab-Metasploitable2"
$VulnVMName   = "CyberLab-BasicPentesting1"

# --- RAM Allocations (MB) ---
# IMPORTANT: Security Onion minimum is 12288 (12 GB). Do not go lower.
# Total allocated must leave at least 2 GB for your host OS.
$KaliRAM      = 2048    # Kali Linux
$SoRAM        = 12288   # Security Onion — hard minimum, do not lower
$Msf2RAM      = 512     # Metasploitable 2
$VulnRAM      = 512     # VulnHub extra VM

# --- CPU Allocations ---
$KaliCPUs     = 2
$SoCPUs       = 2
$Msf2CPUs     = 1
$VulnCPUs     = 1

# --- Disk Sizes (MB, dynamically allocated) ---
$SoDiskMB     = 102400  # 100 GB for Security Onion log storage

# --- Network ---
$LabNetName   = "CyberLab"           # VirtualBox internal network name
$LabSubnet    = "192.168.100.0/24"   # Lab IP range

# Static IPs assigned in-VM after boot (documented in summary)
$KaliLabIP    = "192.168.100.10"
$SoMgmtNote  = "DHCP via NAT - check VirtualBox for IP"

# --- Version Check URLs (do not change unless sources move) ---
$VBoxVersionUrl  = "https://download.virtualbox.org/virtualbox/LATEST.TXT"
$VBoxBaseUrl     = "https://download.virtualbox.org/virtualbox"
$KaliSnapshotUrl = "https://cdimage.kali.org/kali-images/kali-last-snapshot/"
$SoGitHubApi     = "https://api.github.com/repos/Security-Onion-Solutions/securityonion/releases/latest"
$SoDownloadBase  = "https://download.securityonion.net/file/securityonion"

# --- Static VM Sources (these versions are stable and do not change) ---
$Msf2Url      = "https://sourceforge.net/projects/metasploitable/files/Metasploitable2/metasploitable-linux-2.0.0.zip/download"
$Msf2Hash     = ""   # SHA256 populated at runtime after first verified download
$VulnVMUrl    = "https://download.vulnhub.com/basicpentesting/Basic_Pentesting_1.ova"

# --- Timeouts ---
$DownloadTimeoutSec = 7200   # 2 hours max for large ISO downloads
$VBoxManageTimeout  = 300    # 5 min max for import operations

# --- Behaviour Flags ---
$SkipIfExists    = $true    # Skip a VM if it already exists in VirtualBox
$StartVMsOnDone  = $false   # Set to $true to auto-start all VMs after setup
$HeadlessTargets = $true    # Run Metasploitable + VulnVM headless (no window)
