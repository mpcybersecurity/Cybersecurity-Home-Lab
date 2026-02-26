# =============================================================================
# Module 02 — Lab Network Setup
# Creates the CyberLab internal network (virtual switch) that all VMs use.
# Internal networks in VirtualBox are created implicitly when referenced, but
# we validate VBoxManage is working and document the setup.
# =============================================================================

Write-LabInfo "Setting up CyberLab network..."
Write-Log "Network setup started. Lab network name: $LabNetName"

# ---------------------------------------------------------------------------
# Step 1: Verify VBoxManage is accessible
# ---------------------------------------------------------------------------
try {
    $vboxVersion = Invoke-VBox -Arguments @("--version") -Silent
    Write-LabSuccess "VBoxManage accessible. VirtualBox: $($vboxVersion | Select-Object -First 1)"
}
catch {
    throw "VBoxManage not accessible after installation. Try restarting your PC and re-running the script."
}

# ---------------------------------------------------------------------------
# Step 2: VirtualBox Internal Network
# In VirtualBox, internal networks are created automatically the first time
# a VM's NIC references them. No explicit creation command is needed.
# We document the intended network and validate it after VMs are created.
# ---------------------------------------------------------------------------
Write-LabInfo "Lab internal network: '$LabNetName' ($LabSubnet)"
Write-LabInfo "This network will be created automatically when VMs are configured."
Write-LabInfo "VMs on this network are isolated from the internet."

# ---------------------------------------------------------------------------
# Step 3: Check host-only network (used for Security Onion management access)
# We use VirtualBox NAT on the management interface instead of host-only to
# keep setup simple — Security Onion web UI is accessible via port forwarding.
# ---------------------------------------------------------------------------
Write-LabInfo "Verifying default VirtualBox NAT is available..."
try {
    $natNetworks = Invoke-VBox -Arguments @("list", "natnets") -Silent
    Write-LabInfo "NAT networks available for management interfaces."
}
catch {
    Write-LabWarning "Could not list NAT networks — this is non-critical, VMs will still use default NAT."
}

# ---------------------------------------------------------------------------
# Step 4: Record network design for summary
# ---------------------------------------------------------------------------
$networkSummary = @"
  Lab Network Design:
  ┌──────────────────────────────────────────────────────────┐
  │  Network Name : CyberLab (VirtualBox Internal Network)   │
  │  Subnet       : $LabSubnet                          │
  │                                                          │
  │  Kali Linux   : eth0 = NAT (internet)                    │
  │                 eth1 = CyberLab ($KaliLabIP)             │
  │  Sec. Onion   : eth0 = NAT (management UI)               │
  │                 eth1 = CyberLab PROMISCUOUS (monitor)    │
  │  Metasploit.2 : eth0 = CyberLab only (no internet)       │
  │  BasicPent. 1 : eth0 = CyberLab only (no internet)       │
  └──────────────────────────────────────────────────────────┘
"@

Write-Host $networkSummary -ForegroundColor DarkGray
Write-Log "Network design recorded."

Write-LabSuccess "Network configuration ready."
