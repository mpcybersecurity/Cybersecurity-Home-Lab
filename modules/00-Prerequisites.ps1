# =============================================================================
# Module 00 — System Prerequisites
# Checks that the host machine meets all requirements before anything is
# downloaded or installed. Fails fast with clear instructions.
# =============================================================================

Write-LabInfo "Checking system requirements..."

$errors   = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

# ---------------------------------------------------------------------------
# 1. Operating System
# ---------------------------------------------------------------------------
$os = Get-CimInstance Win32_OperatingSystem
$osBuild = [int]$os.BuildNumber

Write-LabInfo "OS: $($os.Caption) (Build $osBuild)"

if ($os.OSArchitecture -notmatch "64") {
    $errors.Add("32-bit operating system detected. VirtualBox 7.x requires a 64-bit OS.")
}
if ($osBuild -lt 18362) {  # Windows 10 1903
    $errors.Add("Windows 10 version 1903 (Build 18362) or later required. Current build: $osBuild")
}

# ---------------------------------------------------------------------------
# 2. RAM
# ---------------------------------------------------------------------------
$totalRAMgb = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
Write-LabInfo "Total RAM: ${totalRAMgb} GB"

if ($totalRAMgb -lt 15.5) {  # Allow slight variance from reported vs actual
    $errors.Add("Insufficient RAM: ${totalRAMgb} GB detected. Minimum 16 GB required (Security Onion alone needs 12 GB).")
}
elseif ($totalRAMgb -lt 30) {
    $warnings.Add("16 GB RAM detected. Lab will run but host may be slow while all VMs are active. 32 GB recommended.")
}

# ---------------------------------------------------------------------------
# 3. Free Disk Space
# ---------------------------------------------------------------------------
$drive      = Split-Path $LabPath -Qualifier
$diskInfo   = Get-PSDrive ($drive.TrimEnd(':')) -ErrorAction SilentlyContinue
if (-not $diskInfo) {
    $diskInfo = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$drive'"
    $freeGB   = [math]::Round($diskInfo.FreeSpace / 1GB, 1)
} else {
    $freeGB   = [math]::Round($diskInfo.Free / 1GB, 1)
}

Write-LabInfo "Free disk space on ${drive}: ${freeGB} GB"

if ($freeGB -lt 150) {
    $errors.Add("Insufficient disk space: ${freeGB} GB free on $drive. Minimum 150 GB required.")
}
elseif ($freeGB -lt 250) {
    $warnings.Add("${freeGB} GB free on $drive. 250+ GB recommended for comfortable operation.")
}

# ---------------------------------------------------------------------------
# 4. CPU — Core count and Virtualisation
# ---------------------------------------------------------------------------
$cpu       = Get-CimInstance Win32_Processor | Select-Object -First 1
$coreCount = ($cpu | Measure-Object -Property NumberOfCores -Sum).Sum
Write-LabInfo "CPU: $($cpu.Name.Trim()) | $coreCount cores"

if ($coreCount -lt 4) {
    $warnings.Add("Only $coreCount CPU cores detected. 4+ cores recommended for running multiple VMs simultaneously.")
}

# Check virtualisation via WMI (firmware-level VT-x / AMD-V)
$virtEnabled = $false
try {
    $vtx = Get-CimInstance -Namespace "root\cimv2" -ClassName Win32_Processor |
           Select-Object -ExpandProperty VirtualizationFirmwareEnabled
    $virtEnabled = $vtx -contains $true
}
catch {
    # Fallback: check via SystemInfo
    $sysInfo = systeminfo 2>$null | Select-String "Hyper-V Requirements"
    $virtEnabled = ($sysInfo -match "Yes")
}

if ($virtEnabled) {
    Write-LabSuccess "CPU Virtualization (VT-x / AMD-V): Enabled"
} else {
    $errors.Add(
        "CPU Virtualization (VT-x / AMD-V) is not enabled or could not be detected.`n" +
        "    To fix: Restart PC → Enter BIOS (F2/F10/Del) → Enable 'Intel VT-x' or 'AMD-V' → Save → Restart."
    )
}

# ---------------------------------------------------------------------------
# 5. Hyper-V conflict detection
# ---------------------------------------------------------------------------
$hyperVRunning = (Get-Service -Name vmms -ErrorAction SilentlyContinue)?.Status -eq "Running"
$hyperVFeature = (Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -ErrorAction SilentlyContinue)?.State -eq "Enabled"

if ($hyperVRunning -or $hyperVFeature) {
    $errors.Add(
        "Hyper-V is enabled. VirtualBox cannot run alongside Hyper-V.`n" +
        "    To fix (run in elevated PowerShell, then restart):`n" +
        "      bcdedit /set hypervisorlaunchtype off`n" +
        "    NOTE: This disables WSL 2 and Docker Desktop (Hyper-V backend).`n" +
        "    To re-enable later: bcdedit /set hypervisorlaunchtype auto"
    )
}

# ---------------------------------------------------------------------------
# 6. Internet connectivity
# ---------------------------------------------------------------------------
Write-LabInfo "Checking internet connectivity..."
try {
    $null = Invoke-WebRequest -Uri "https://download.virtualbox.org" -UseBasicParsing -TimeoutSec 10
    Write-LabSuccess "Internet connectivity: OK"
}
catch {
    $errors.Add("No internet connection detected. Internet is required to download VirtualBox and VM images.")
}

# ---------------------------------------------------------------------------
# 7. PowerShell version
# ---------------------------------------------------------------------------
$psVersion = $PSVersionTable.PSVersion
Write-LabInfo "PowerShell version: $($psVersion.Major).$($psVersion.Minor)"
if ($psVersion.Major -lt 5 -or ($psVersion.Major -eq 5 -and $psVersion.Minor -lt 1)) {
    $errors.Add("PowerShell 5.1 or later required. Current: $($psVersion.Major).$($psVersion.Minor)")
}

# ---------------------------------------------------------------------------
# 8. BITS Service (needed for downloads)
# ---------------------------------------------------------------------------
$bits = Get-Service -Name BITS -ErrorAction SilentlyContinue
if ($bits.Status -ne "Running" -and $bits.StartType -eq "Disabled") {
    $warnings.Add("Background Intelligent Transfer Service (BITS) is disabled. Downloads may be slower.")
} else {
    if ($bits.Status -ne "Running") {
        Start-Service -Name BITS -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
# Report results
# ---------------------------------------------------------------------------
Write-Host ""

foreach ($w in $warnings) {
    Write-LabWarning $w
    Write-Log "PREREQUISITE WARNING: $w"
}

if ($errors.Count -gt 0) {
    Write-Host ""
    Write-LabError "Prerequisites check FAILED. The following must be resolved before setup can continue:"
    Write-Host ""
    foreach ($e in $errors) {
        Write-Host "  ✗ $e" -ForegroundColor Red
        Write-Host ""
        Write-Log "PREREQUISITE ERROR: $e"
    }
    throw "Prerequisites not met. Resolve the issues above and re-run the script."
}

Write-LabSuccess "All prerequisites met. Proceeding with installation."
Write-Log "Prerequisites check passed."
