# =============================================================================
# Helpers.ps1 — Shared utility functions used by all modules
# =============================================================================

# ---------------------------------------------------------------------------
# Console output helpers
# ---------------------------------------------------------------------------
function Write-LabStep   ($msg) { Write-Host "  ► $msg" -ForegroundColor Cyan }
function Write-LabInfo   ($msg) { Write-Host "    $msg" -ForegroundColor White }
function Write-LabSuccess($msg) { Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-LabWarning($msg) { Write-Host "  ⚠ $msg" -ForegroundColor Yellow }
function Write-LabError  ($msg) { Write-Host "  ✗ $msg" -ForegroundColor Red }

function Write-Log ($msg) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "[$timestamp] $msg" -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------
# Download a file using BITS with retry logic and progress display
# ---------------------------------------------------------------------------
function Get-LabFile {
    param(
        [string]$Url,
        [string]$Destination,
        [string]$DisplayName,
        [string]$ExpectedHash = ""
    )

    # Skip if file already exists and hash matches
    if (Test-Path $Destination) {
        Write-LabInfo "File already downloaded: $(Split-Path $Destination -Leaf)"
        if ($ExpectedHash -and (Get-FileHash $Destination -Algorithm SHA256).Hash -eq $ExpectedHash) {
            Write-LabSuccess "Checksum verified (cached)."
            return
        }
        elseif (-not $ExpectedHash) {
            Write-LabInfo "No checksum provided — using cached file."
            return
        }
        else {
            Write-LabWarning "Cached file checksum mismatch — re-downloading."
            Remove-Item $Destination -Force
        }
    }

    $null = New-Item -ItemType Directory -Path (Split-Path $Destination) -Force
    Write-LabInfo "Downloading: $DisplayName"
    Write-LabInfo "Source: $Url"
    Write-LabInfo "Destination: $Destination"
    Write-Log "Downloading $DisplayName from $Url"

    $maxRetries = 3
    for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
        try {
            # BITS provides resume-on-failure and proper progress
            Start-BitsTransfer `
                -Source      $Url `
                -Destination $Destination `
                -DisplayName "CyberLab: $DisplayName" `
                -Description "Attempt $attempt of $maxRetries" `
                -Priority    Normal `
                -ErrorAction Stop

            Write-LabSuccess "Download complete."
            Write-Log "Download complete: $Destination"
            break
        }
        catch {
            Write-LabWarning "Download attempt $attempt failed: $_"
            Write-Log "Download attempt $attempt failed: $_"
            if ($attempt -eq $maxRetries) {
                throw "Download failed after $maxRetries attempts: $DisplayName"
            }
            Write-LabInfo "Retrying in 10 seconds..."
            Start-Sleep -Seconds 10
        }
    }

    # Verify hash if provided
    if ($ExpectedHash) {
        Write-LabInfo "Verifying checksum..."
        $actual = (Get-FileHash $Destination -Algorithm SHA256).Hash
        if ($actual -ne $ExpectedHash) {
            Remove-Item $Destination -Force
            throw "Checksum verification failed for $DisplayName.`nExpected: $ExpectedHash`nActual:   $actual"
        }
        Write-LabSuccess "Checksum verified."
    }
}

# ---------------------------------------------------------------------------
# Run VBoxManage with error capture
# ---------------------------------------------------------------------------
function Invoke-VBox {
    param(
        [string[]]$Arguments,
        [string]$Description = "",
        [switch]$Silent
    )

    $vboxManage = Get-VBoxManagePath

    if (-not $Silent) {
        Write-Log "VBoxManage: $Arguments"
    }

    $result = & $vboxManage @Arguments 2>&1
    $exit   = $LASTEXITCODE

    if ($exit -ne 0) {
        $errMsg = $result | Out-String
        Write-Log "VBoxManage error ($exit): $errMsg"
        throw "VBoxManage failed ($Description): $errMsg"
    }

    return $result
}

# ---------------------------------------------------------------------------
# Get VBoxManage executable path
# ---------------------------------------------------------------------------
function Get-VBoxManagePath {
    # Try PATH first
    $cmd = Get-Command "VBoxManage" -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    # Try default install locations
    $paths = @(
        "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe"
        "${env:ProgramFiles(x86)}\Oracle\VirtualBox\VBoxManage.exe"
    )
    foreach ($p in $paths) {
        if (Test-Path $p) { return $p }
    }

    throw "VBoxManage not found. Is VirtualBox installed?"
}

# ---------------------------------------------------------------------------
# Check if a VM already exists in VirtualBox
# ---------------------------------------------------------------------------
function Test-VMExists {
    param([string]$VMName)
    try {
        $result = Invoke-VBox -Arguments @("showvminfo", $VMName, "--machinereadable") -Silent
        return $true
    }
    catch {
        return $false
    }
}

# ---------------------------------------------------------------------------
# Fetch JSON from URL (GitHub API etc.)
# ---------------------------------------------------------------------------
function Get-JsonFromUrl {
    param([string]$Url)
    $headers = @{
        "User-Agent" = "CyberLab-Setup/1.0"
        "Accept"     = "application/json"
    }
    return Invoke-RestMethod -Uri $Url -Headers $headers -UseBasicParsing
}

# ---------------------------------------------------------------------------
# Extract a ZIP file
# ---------------------------------------------------------------------------
function Expand-LabZip {
    param(
        [string]$ZipPath,
        [string]$DestinationPath
    )
    Write-LabInfo "Extracting: $(Split-Path $ZipPath -Leaf)"
    $null = New-Item -ItemType Directory -Path $DestinationPath -Force
    Expand-Archive -Path $ZipPath -DestinationPath $DestinationPath -Force
    Write-LabSuccess "Extraction complete."
}

# ---------------------------------------------------------------------------
# Extract a 7z file using 7-Zip (installed by module 01 if needed)
# ---------------------------------------------------------------------------
function Expand-Lab7z {
    param(
        [string]$ArchivePath,
        [string]$DestinationPath
    )
    $sevenZip = Get-7ZipPath
    Write-LabInfo "Extracting (7z): $(Split-Path $ArchivePath -Leaf)"
    $null = New-Item -ItemType Directory -Path $DestinationPath -Force
    $result = & $sevenZip x $ArchivePath -o"$DestinationPath" -y 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "7-Zip extraction failed: $result"
    }
    Write-LabSuccess "Extraction complete."
}

function Get-7ZipPath {
    $paths = @(
        "$env:ProgramFiles\7-Zip\7z.exe"
        "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
    )
    foreach ($p in $paths) {
        if (Test-Path $p) { return $p }
    }
    throw "7-Zip not found. Run module 01-VirtualBox first."
}
