# =============================================================================
# Module 04 — Security Onion
# Resolves the latest Security Onion ISO via GitHub Releases API, creates and
# configures the VM, then pauses for the student to complete the first-boot
# setup wizard (3 minutes, cannot be fully automated without circular deps).
#
# Network adapters:
#   eth0 = NAT (management interface — web UI access)
#   eth1 = CyberLab internal, PROMISCUOUS (passive monitoring sensor)
# =============================================================================

# ---------------------------------------------------------------------------
# Step 1: Resolve latest Security Onion release from GitHub API
# ---------------------------------------------------------------------------
Write-LabInfo "Checking latest Security Onion release from GitHub..."

$soVersion    = $null
$soIsoUrl     = $null
$soIsoName    = $null

try {
    $release = Get-JsonFromUrl -Url $SoGitHubApi

    # Look for an ISO asset in the release
    $isoAsset = $release.assets | Where-Object { $_.name -match "\.iso$" } | Select-Object -First 1

    if ($isoAsset) {
        $soVersion = $release.tag_name -replace "^v", ""
        $soIsoName = $isoAsset.name
        $soIsoUrl  = $isoAsset.browser_download_url
        Write-LabSuccess "Latest Security Onion: $soVersion ($soIsoName)"
        Write-Log "Security Onion version resolved via GitHub: $soVersion"
    }
    else {
        throw "No ISO asset found in the latest GitHub release."
    }
}
catch {
    Write-LabWarning "GitHub API resolution failed: $_"
    Write-LabWarning "Falling back to Security Onion CDN..."

    # Fallback: parse Security Onion download page
    try {
        $soPage   = (Invoke-WebRequest -Uri "https://docs.securityonion.net/en/2.4/download.html" -UseBasicParsing -TimeoutSec 20).Content
        $soMatch  = [regex]::Match($soPage, 'https://download\.securityonion\.net/file/securityonion/(securityonion-[\d.]+-\d+\.iso)')
        if ($soMatch.Success) {
            $soIsoName = $soMatch.Groups[1].Value
            $soIsoUrl  = "https://download.securityonion.net/file/securityonion/$soIsoName"
            $soVersion = [regex]::Match($soIsoName, 'securityonion-([\d.]+)-').Groups[1].Value
            Write-LabSuccess "Security Onion from CDN: $soIsoName"
            Write-Log "Security Onion version resolved via CDN: $soIsoUrl"
        } else {
            throw "Could not parse Security Onion URL from docs page."
        }
    }
    catch {
        throw "Could not resolve Security Onion download URL. Check internet and try again. Error: $_"
    }
}

$soIsoPath    = Join-Path $DownloadDir $soIsoName
$soDiskPath   = Join-Path $LabPath "VMs\$SoVMName\$SoVMName.vdi"

# ---------------------------------------------------------------------------
# Step 2: Fetch checksum from Security Onion CDN
# ---------------------------------------------------------------------------
$soHash = ""
try {
    $soHashUrl  = $soIsoUrl + ".sha256"
    $soHashData = (Invoke-WebRequest -Uri $soHashUrl -UseBasicParsing -TimeoutSec 15).Content
    $soHash     = ($soHashData -split "\s+")[0].Trim().ToUpper()
    Write-LabInfo "Expected SHA256: $soHash"
    Write-Log "Security Onion expected hash: $soHash"
}
catch {
    Write-LabWarning "Could not fetch Security Onion checksum. Proceeding without verification."
}

# ---------------------------------------------------------------------------
# Step 3: Check if VM already exists
# ---------------------------------------------------------------------------
if ($SkipIfExists -and (Test-VMExists -VMName $SoVMName)) {
    Write-LabSuccess "VM '$SoVMName' already exists. Skipping."
    Write-Log "Security Onion VM '$SoVMName' already exists — skipped."
    return
}

# ---------------------------------------------------------------------------
# Step 4: Download Security Onion ISO
# ---------------------------------------------------------------------------
Write-LabInfo "Security Onion ISO is ~3.5 GB — this is the longest download."
Get-LabFile -Url         $soIsoUrl `
            -Destination $soIsoPath `
            -DisplayName "Security Onion $soVersion" `
            -ExpectedHash $soHash

# ---------------------------------------------------------------------------
# Step 5: Create the VM
# ---------------------------------------------------------------------------
Write-LabInfo "Creating Security Onion VM..."

$vmDir = Join-Path $LabPath "VMs\$SoVMName"
$null  = New-Item -ItemType Directory -Path $vmDir -Force

Invoke-VBox -Arguments @(
    "createvm",
    "--name",       $SoVMName,
    "--ostype",     "Linux_64",
    "--basefolder", (Join-Path $LabPath "VMs"),
    "--register"
) -Description "Create Security Onion VM"

# ---------------------------------------------------------------------------
# Step 6: Configure RAM, CPU, display
# ---------------------------------------------------------------------------
Invoke-VBox -Arguments @(
    "modifyvm", $SoVMName,
    "--memory",   "$SoRAM",
    "--cpus",     "$SoCPUs",
    "--vram",     "16",
    "--graphicscontroller", "vmsvga",
    "--audio",    "none",
    "--usb",      "off"
) -Description "Security Onion VM hardware settings"

# ---------------------------------------------------------------------------
# Step 7: Create and attach storage
# ---------------------------------------------------------------------------
Write-LabInfo "Creating $([math]::Round($SoDiskMB/1024, 0)) GB virtual disk for Security Onion..."

Invoke-VBox -Arguments @(
    "createmedium", "disk",
    "--filename", $soDiskPath,
    "--size",     "$SoDiskMB",
    "--format",   "VDI"
) -Description "Create Security Onion disk"

# Add SATA controller
Invoke-VBox -Arguments @(
    "storagectl", $SoVMName,
    "--name",     "SATA Controller",
    "--add",      "sata",
    "--controller", "IntelAhci"
) -Description "Security Onion SATA controller"

# Attach the VDI
Invoke-VBox -Arguments @(
    "storageattach", $SoVMName,
    "--storagectl", "SATA Controller",
    "--port",       "0",
    "--device",     "0",
    "--type",       "hdd",
    "--medium",     $soDiskPath
) -Description "Attach Security Onion disk"

# Add IDE controller for DVD
Invoke-VBox -Arguments @(
    "storagectl", $SoVMName,
    "--name",     "IDE Controller",
    "--add",      "ide"
) -Description "Security Onion IDE controller"

# Attach ISO to DVD drive
Invoke-VBox -Arguments @(
    "storageattach", $SoVMName,
    "--storagectl", "IDE Controller",
    "--port",       "1",
    "--device",     "0",
    "--type",       "dvddrive",
    "--medium",     $soIsoPath
) -Description "Attach Security Onion ISO"

# Boot order: DVD first
Invoke-VBox -Arguments @(
    "modifyvm", $SoVMName,
    "--boot1", "dvd",
    "--boot2", "disk",
    "--boot3", "none",
    "--boot4", "none"
) -Description "Security Onion boot order"

# ---------------------------------------------------------------------------
# Step 8: Configure network adapters
# ---------------------------------------------------------------------------
Write-LabInfo "Configuring Security Onion network adapters..."

# Adapter 1 (eth0): NAT — management interface, web UI accessible via host
Invoke-VBox -Arguments @(
    "modifyvm", $SoVMName,
    "--nic1", "nat"
) -Description "Security Onion NIC1 NAT management"

# Adapter 2 (eth1): CyberLab internal, PROMISCUOUS — passive monitoring
Invoke-VBox -Arguments @(
    "modifyvm", $SoVMName,
    "--nic2",        "intnet",
    "--intnet2",     $LabNetName,
    "--nicpromisc2", "allow-all"
) -Description "Security Onion NIC2 promiscuous monitoring"

Write-LabSuccess "Security Onion VM created and configured."
Write-Log "Security Onion VM configured. Version: $soVersion"

# ---------------------------------------------------------------------------
# Step 9: Start Security Onion and pause for wizard
# ---------------------------------------------------------------------------
Write-LabInfo "Starting Security Onion for first-boot setup..."
Invoke-VBox -Arguments @("startvm", $SoVMName, "--type", "gui") -Description "Start Security Onion"

Start-Sleep -Seconds 5  # Give the window time to open

Write-Host ""
Write-Host ("═" * 70) -ForegroundColor Yellow
Write-Host "  SECURITY ONION SETUP — ACTION REQUIRED (3 minutes)" -ForegroundColor Yellow
Write-Host ("═" * 70) -ForegroundColor Yellow
Write-Host ""
Write-Host "  Security Onion has started in the VirtualBox window." -ForegroundColor White
Write-Host "  Complete these steps in that window now:" -ForegroundColor White
Write-Host ""
Write-Host "  1. Wait for the login prompt, then log in:" -ForegroundColor Cyan
Write-Host "       Username: onion" -ForegroundColor White
Write-Host "       Password: onion" -ForegroundColor White
Write-Host ""
Write-Host "  2. The setup wizard will start automatically." -ForegroundColor Cyan
Write-Host "     When asked for install type — choose:" -ForegroundColor White
Write-Host "       ► EVALUATION" -ForegroundColor Green
Write-Host ""
Write-Host "  3. Accept all defaults EXCEPT:" -ForegroundColor Cyan
Write-Host "       ► Management interface: select adapter 1 (the NAT/DHCP one)" -ForegroundColor White
Write-Host "       ► Monitoring interface: select adapter 2 (no IP assigned)" -ForegroundColor White
Write-Host ""
Write-Host "  4. Set your Security Onion admin account:" -ForegroundColor Cyan
Write-Host "       ► Email:    admin@lab.local" -ForegroundColor White
Write-Host "       ► Password: (choose one you'll remember)" -ForegroundColor White
Write-Host ""
Write-Host "  5. When setup completes, note the URL it shows:" -ForegroundColor Cyan
Write-Host "       https://[IP-ADDRESS]" -ForegroundColor White
Write-Host "     This is your Security Onion web dashboard." -ForegroundColor White
Write-Host ""
Write-Host ("─" * 70) -ForegroundColor DarkGray
Write-Host ""

$null = Read-Host "When Security Onion setup is COMPLETE, press ENTER to continue..."

Write-LabSuccess "Security Onion '$SoVMName' setup complete."
Write-Log "Security Onion setup wizard completed by user. Version: $soVersion"

$global:SoVersion = $soVersion
