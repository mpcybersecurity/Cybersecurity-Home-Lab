# =============================================================================
# Module 05 — Metasploitable 2
# Downloads the Metasploitable 2 ZIP from SourceForge, extracts the VMDK,
# creates a VM around it, and attaches it to the CyberLab internal network
# only (no internet access — this machine is intentionally vulnerable).
# =============================================================================

# Metasploitable 2 is a static release — version 2.0.0 has not been updated
# since 2012 by design. We verify the download but there is no version API.
Write-LabInfo "Setting up Metasploitable 2..."

if ($SkipIfExists -and (Test-VMExists -VMName $Msf2VMName)) {
    Write-LabSuccess "VM '$Msf2VMName' already exists. Skipping."
    Write-Log "Metasploitable 2 VM '$Msf2VMName' already exists — skipped."
    return
}

$msf2ZipPath  = Join-Path $DownloadDir "metasploitable-linux-2.0.0.zip"
$msf2ExtDir   = Join-Path $DownloadDir "Metasploitable2-Extract"
$msf2VmDir    = Join-Path $LabPath "VMs\$Msf2VMName"

# ---------------------------------------------------------------------------
# Step 1: Download Metasploitable 2
# Note: SourceForge redirects — we follow the redirect chain
# ---------------------------------------------------------------------------
Write-LabInfo "Downloading Metasploitable 2 from SourceForge (~800 MB)..."

# SourceForge uses a redirect chain. BITS handles redirects correctly.
Get-LabFile -Url         $Msf2Url `
            -Destination $msf2ZipPath `
            -DisplayName "Metasploitable 2"

# ---------------------------------------------------------------------------
# Step 2: Extract the ZIP
# ---------------------------------------------------------------------------
Write-LabInfo "Extracting Metasploitable 2..."
$null = New-Item -ItemType Directory -Path $msf2ExtDir -Force
Expand-LabZip -ZipPath $msf2ZipPath -DestinationPath $msf2ExtDir

# Find the VMDK file
$vmdk = Get-ChildItem -Path $msf2ExtDir -Filter "*.vmdk" -Recurse | Select-Object -First 1
if (-not $vmdk) {
    throw "Could not find VMDK file in Metasploitable 2 archive. Extraction may have failed."
}
Write-LabSuccess "VMDK found: $($vmdk.Name)"

# Move VMDK to lab VM folder
$null = New-Item -ItemType Directory -Path $msf2VmDir -Force
$msf2VmdkDest = Join-Path $msf2VmDir "$Msf2VMName.vmdk"
if (-not (Test-Path $msf2VmdkDest)) {
    Move-Item -Path $vmdk.FullName -Destination $msf2VmdkDest
}

# ---------------------------------------------------------------------------
# Step 3: Create and register VM
# ---------------------------------------------------------------------------
Write-LabInfo "Creating Metasploitable 2 VM..."

Invoke-VBox -Arguments @(
    "createvm",
    "--name",       $Msf2VMName,
    "--ostype",     "Ubuntu_64",
    "--basefolder", (Join-Path $LabPath "VMs"),
    "--register"
) -Description "Create Metasploitable 2 VM"

# ---------------------------------------------------------------------------
# Step 4: Configure hardware
# ---------------------------------------------------------------------------
Invoke-VBox -Arguments @(
    "modifyvm", $Msf2VMName,
    "--memory", "$Msf2RAM",
    "--cpus",   "$Msf2CPUs",
    "--vram",   "16",
    "--graphicscontroller", "vmsvga",
    "--audio",  "none"
) -Description "Metasploitable 2 hardware"

# ---------------------------------------------------------------------------
# Step 5: Attach existing VMDK
# ---------------------------------------------------------------------------
Invoke-VBox -Arguments @(
    "storagectl", $Msf2VMName,
    "--name",     "SATA Controller",
    "--add",      "sata",
    "--controller", "IntelAhci"
) -Description "Metasploitable 2 SATA controller"

Invoke-VBox -Arguments @(
    "storageattach", $Msf2VMName,
    "--storagectl", "SATA Controller",
    "--port",       "0",
    "--device",     "0",
    "--type",       "hdd",
    "--medium",     $msf2VmdkDest
) -Description "Attach Metasploitable 2 VMDK"

# ---------------------------------------------------------------------------
# Step 6: Network — CyberLab internal ONLY, no internet
# ---------------------------------------------------------------------------
Invoke-VBox -Arguments @(
    "modifyvm", $Msf2VMName,
    "--nic1",    "intnet",
    "--intnet1", $LabNetName,
    "--nic2",    "none"
) -Description "Metasploitable 2 network (isolated)"

Write-LabSuccess "Metasploitable 2 isolated to CyberLab network (no internet)."

# ---------------------------------------------------------------------------
# Step 7: Start VM headless
# ---------------------------------------------------------------------------
if ($StartVMsOnDone -or $HeadlessTargets) {
    Write-LabInfo "Starting Metasploitable 2 (headless)..."
    Invoke-VBox -Arguments @("startvm", $Msf2VMName, "--type", "headless") -Description "Start Metasploitable 2"
    Write-LabSuccess "Metasploitable 2 running (headless)."
    Write-LabInfo   "Connect from Kali via: ssh msfadmin@[DHCP-IP]"
    Write-LabInfo   "To find IP: run 'netdiscover -r 192.168.100.0/24' in Kali"
}

Write-LabSuccess "Metasploitable 2 '$Msf2VMName' ready."
Write-LabInfo   "Default credentials: msfadmin / msfadmin"
Write-LabInfo   "Services: FTP, SSH, Telnet, HTTP, MySQL, SMB, VNC, and many more"
Write-Log "Metasploitable 2 setup complete: $Msf2VMName"
