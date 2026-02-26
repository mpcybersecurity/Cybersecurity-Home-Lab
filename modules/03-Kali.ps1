# =============================================================================
# Module 03 — Kali Linux
# Resolves the latest Kali VirtualBox image from the official CDN snapshot
# directory, downloads the .7z archive, extracts the .ova, and imports it
# into VirtualBox with two network adapters:
#   eth0 = NAT (internet access for tool updates)
#   eth1 = CyberLab internal (attack traffic to targets)
# =============================================================================

# ---------------------------------------------------------------------------
# Step 1: Resolve latest Kali VirtualBox image URL dynamically
# ---------------------------------------------------------------------------
Write-LabInfo "Resolving latest Kali Linux VirtualBox image..."

$kaliOvaPath  = $null
$kaliFileName = $null
$kaliUrl      = $null

try {
    # The kali-last-snapshot directory always points to the current release
    $snapshotPage = (Invoke-WebRequest -Uri $KaliSnapshotUrl -UseBasicParsing -TimeoutSec 30).Content

    # Find the VirtualBox amd64 7z file link
    $matches = [regex]::Matches($snapshotPage, 'href="(kali-linux-[\d.]+[^"]*-virtualbox-amd64\.7z)"')
    if ($matches.Count -eq 0) {
        # Fallback: try .ova directly
        $matches = [regex]::Matches($snapshotPage, 'href="(kali-linux-[\d.]+[^"]*-virtualbox-amd64\.ova)"')
    }

    if ($matches.Count -gt 0) {
        $kaliFileName = $matches[0].Groups[1].Value
        $kaliUrl      = $KaliSnapshotUrl + $kaliFileName
        Write-LabSuccess "Latest Kali image: $kaliFileName"
        Write-Log "Kali image resolved: $kaliUrl"
    }
    else {
        throw "Could not parse Kali image filename from snapshot directory."
    }
}
catch {
    # If dynamic resolution fails, use a known-good pattern fallback
    Write-LabWarning "Dynamic version check failed: $_"
    Write-LabWarning "Falling back to kali.org download page..."
    try {
        $kaliPage = (Invoke-WebRequest -Uri "https://www.kali.org/get-kali/#kali-virtual-machines" -UseBasicParsing -TimeoutSec 30).Content
        $m = [regex]::Match($kaliPage, '"(https://cdimage\.kali\.org[^"]*virtualbox-amd64\.7z)"')
        if ($m.Success) {
            $kaliUrl      = $m.Groups[1].Value
            $kaliFileName = Split-Path $kaliUrl -Leaf
            Write-LabSuccess "Kali image from main page: $kaliFileName"
            Write-Log "Kali image resolved via main page: $kaliUrl"
        } else {
            throw "Could not resolve Kali download URL from main page either."
        }
    }
    catch {
        throw "Could not resolve Kali Linux download URL. Check internet connection and try again. Error: $_"
    }
}

# Determine if the download is a .7z archive or a direct .ova
$isSevenZip   = $kaliFileName -match "\.7z$"
$downloadPath = Join-Path $DownloadDir $kaliFileName
$extractDir   = Join-Path $DownloadDir "Kali-Extract"

# ---------------------------------------------------------------------------
# Step 2: Fetch SHA256 checksum from Kali CDN
# ---------------------------------------------------------------------------
$kaliHash = ""
try {
    $checksumUrl  = ($kaliUrl -replace "\.7z$", ".7z.sha256sum") -replace "\.ova$", ".ova.sha256sum"
    $checksumData = (Invoke-WebRequest -Uri $checksumUrl -UseBasicParsing -TimeoutSec 15).Content
    $kaliHash     = ($checksumData -split "\s+")[0].ToUpper()
    Write-LabInfo "Expected SHA256: $kaliHash"
    Write-Log "Kali expected hash: $kaliHash"
}
catch {
    Write-LabWarning "Could not fetch Kali checksum. Download will proceed without hash verification."
}

# ---------------------------------------------------------------------------
# Step 3: Check if VM already exists
# ---------------------------------------------------------------------------
if ($SkipIfExists -and (Test-VMExists -VMName $KaliVMName)) {
    Write-LabSuccess "VM '$KaliVMName' already exists in VirtualBox. Skipping."
    Write-Log "Kali VM '$KaliVMName' already exists — skipped."
    return
}

# ---------------------------------------------------------------------------
# Step 4: Download Kali image
# ---------------------------------------------------------------------------
Get-LabFile -Url         $kaliUrl `
            -Destination $downloadPath `
            -DisplayName "Kali Linux (latest) — this is ~3 GB and will take a while" `
            -ExpectedHash $kaliHash

# ---------------------------------------------------------------------------
# Step 5: Extract if 7z archive
# ---------------------------------------------------------------------------
if ($isSevenZip) {
    Write-LabInfo "Extracting Kali .7z archive..."
    Expand-Lab7z -ArchivePath $downloadPath -DestinationPath $extractDir
    # Find the .ova inside the extracted directory
    $ovaFile = Get-ChildItem -Path $extractDir -Filter "*.ova" -Recurse | Select-Object -First 1
    if (-not $ovaFile) {
        # Some Kali releases extract to a .vbox + .vmdk pair — look for .ovf too
        $ovaFile = Get-ChildItem -Path $extractDir -Filter "*.ovf" -Recurse | Select-Object -First 1
    }
    if (-not $ovaFile) {
        throw "Could not find .ova or .ovf file in extracted Kali archive. Contents: $(Get-ChildItem $extractDir -Recurse | Select-Object Name)"
    }
    $kaliOvaPath = $ovaFile.FullName
    Write-LabSuccess "Kali OVA/OVF found: $($ovaFile.Name)"
} else {
    $kaliOvaPath = $downloadPath
}

# ---------------------------------------------------------------------------
# Step 6: Import Kali OVA into VirtualBox
# ---------------------------------------------------------------------------
Write-LabInfo "Importing Kali Linux into VirtualBox..."
Write-LabInfo "This takes 3–5 minutes..."

Invoke-VBox -Arguments @(
    "import", $kaliOvaPath,
    "--vsys", "0",
    "--vmname", $KaliVMName,
    "--memory", "$KaliRAM",
    "--cpus",   "$KaliCPUs",
    "--eula",   "accept"
) -Description "Import Kali OVA"

Write-LabSuccess "Kali OVA imported."

# ---------------------------------------------------------------------------
# Step 7: Configure network adapters
# ---------------------------------------------------------------------------
Write-LabInfo "Configuring Kali network adapters..."

# Adapter 1: VirtualBox NAT (internet access)
Invoke-VBox -Arguments @(
    "modifyvm", $KaliVMName,
    "--nic1", "nat"
) -Description "Kali NIC1 NAT"

# Adapter 2: CyberLab internal network (attack traffic)
Invoke-VBox -Arguments @(
    "modifyvm", $KaliVMName,
    "--nic2",    "intnet",
    "--intnet2", $LabNetName
) -Description "Kali NIC2 CyberLab internal"

Write-LabSuccess "Network adapters configured."

# ---------------------------------------------------------------------------
# Step 8: Configure VM settings
# ---------------------------------------------------------------------------
Invoke-VBox -Arguments @(
    "modifyvm", $KaliVMName,
    "--clipboard-mode", "bidirectional",
    "--draganddrop",    "bidirectional",
    "--vram",           "128",
    "--graphicscontroller", "vmsvga"
) -Description "Kali display/clipboard settings"

# Store VM path for summary
$global:KaliVMConfigured = $true

Write-LabSuccess "Kali Linux '$KaliVMName' ready."
Write-LabInfo   "Default credentials: kali / kali"
Write-LabInfo   "⚠  Change these credentials on first login."
Write-Log "Kali Linux setup complete: $KaliVMName"
