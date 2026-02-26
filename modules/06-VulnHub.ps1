# =============================================================================
# Module 06 — VulnHub: Basic Pentesting 1
# Downloads the OVA directly from VulnHub CDN, imports into VirtualBox,
# and attaches to CyberLab internal network only (no internet access).
#
# Basic Pentesting 1 is ideal for beginners:
#   - Web server with multiple vulnerabilities
#   - SSH misconfigurations
#   - Privilege escalation paths
#   - Well-documented walkthroughs available online
#   - VulnHub page: https://www.vulnhub.com/entry/basic-pentesting-1,216/
# =============================================================================

Write-LabInfo "Setting up VulnHub: Basic Pentesting 1..."

if ($SkipIfExists -and (Test-VMExists -VMName $VulnVMName)) {
    Write-LabSuccess "VM '$VulnVMName' already exists. Skipping."
    Write-Log "VulnHub VM '$VulnVMName' already exists — skipped."
    return
}

$vulnOvaPath = Join-Path $DownloadDir "Basic_Pentesting_1.ova"

# ---------------------------------------------------------------------------
# Step 1: Download OVA from VulnHub CDN
# ---------------------------------------------------------------------------
Write-LabInfo "Downloading Basic Pentesting 1 OVA from VulnHub..."
Write-LabInfo "Note: VulnHub direct downloads are capped at ~3 MB/s — be patient."

Get-LabFile -Url         $VulnVMUrl `
            -Destination $vulnOvaPath `
            -DisplayName "VulnHub Basic Pentesting 1"

# ---------------------------------------------------------------------------
# Step 2: Import OVA into VirtualBox
# ---------------------------------------------------------------------------
Write-LabInfo "Importing Basic Pentesting 1 into VirtualBox..."

Invoke-VBox -Arguments @(
    "import", $vulnOvaPath,
    "--vsys", "0",
    "--vmname", $VulnVMName,
    "--memory", "$VulnRAM",
    "--cpus",   "$VulnCPUs",
    "--eula",   "accept"
) -Description "Import Basic Pentesting 1 OVA"

Write-LabSuccess "OVA imported."

# ---------------------------------------------------------------------------
# Step 3: Network — CyberLab internal ONLY
# ---------------------------------------------------------------------------
Invoke-VBox -Arguments @(
    "modifyvm", $VulnVMName,
    "--nic1",    "intnet",
    "--intnet1", $LabNetName,
    "--nic2",    "none"
) -Description "Basic Pentesting 1 network (isolated)"

Write-LabSuccess "Basic Pentesting 1 isolated to CyberLab network (no internet)."

# ---------------------------------------------------------------------------
# Step 4: Start VM headless (optional)
# ---------------------------------------------------------------------------
if ($StartVMsOnDone -or $HeadlessTargets) {
    Write-LabInfo "Starting Basic Pentesting 1 (headless)..."
    Invoke-VBox -Arguments @("startvm", $VulnVMName, "--type", "headless") -Description "Start Basic Pentesting 1"
    Write-LabSuccess "Basic Pentesting 1 running (headless)."
    Write-LabInfo   "Find IP from Kali: netdiscover -r 192.168.100.0/24"
}

Write-LabSuccess "Basic Pentesting 1 '$VulnVMName' ready."
Write-LabInfo   "Attack surface: web server (port 80), SSH (port 22), FTP (port 21)"
Write-LabInfo   "Walkthrough available: https://www.vulnhub.com/entry/basic-pentesting-1,216/"
Write-Log "VulnHub Basic Pentesting 1 setup complete: $VulnVMName"
