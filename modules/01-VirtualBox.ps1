# =============================================================================
# Module 01 — VirtualBox Installation
# Fetches the LATEST version number from Oracle's server, downloads the
# installer and Extension Pack, verifies checksums, and installs silently.
# Also ensures 7-Zip is available for later Kali extraction.
# =============================================================================

# ---------------------------------------------------------------------------
# Step 1: Resolve latest VirtualBox version dynamically
# ---------------------------------------------------------------------------
Write-LabInfo "Checking latest VirtualBox version from Oracle..."

try {
    $latestVersion = (Invoke-WebRequest -Uri $VBoxVersionUrl -UseBasicParsing -TimeoutSec 30).Content.Trim()
    Write-LabSuccess "Latest VirtualBox version: $latestVersion"
    Write-Log "VirtualBox latest version resolved: $latestVersion"
}
catch {
    throw "Could not fetch VirtualBox version from Oracle. Check internet connection. Error: $_"
}

# Build download URLs from the resolved version
$vboxInstallerUrl  = "$VBoxBaseUrl/$latestVersion/VirtualBox-$latestVersion-Win.exe"
$vboxExtPackUrl    = "$VBoxBaseUrl/$latestVersion/Oracle_VirtualBox_Extension_Pack-$latestVersion.vbox-extpack"
$vboxSHA256Url     = "$VBoxBaseUrl/$latestVersion/SHA256SUMS"

$vboxInstallerPath = Join-Path $DownloadDir "VirtualBox-$latestVersion-Win.exe"
$vboxExtPackPath   = Join-Path $DownloadDir "VirtualBox-ExtPack-$latestVersion.vbox-extpack"

# ---------------------------------------------------------------------------
# Step 2: Check if VirtualBox is already installed at this version
# ---------------------------------------------------------------------------
$installedVersion = $null
$regPaths = @(
    "HKLM:\SOFTWARE\Oracle\VirtualBox"
    "HKLM:\SOFTWARE\WOW6432Node\Oracle\VirtualBox"
)
foreach ($reg in $regPaths) {
    if (Test-Path $reg) {
        $installedVersion = (Get-ItemProperty $reg -ErrorAction SilentlyContinue).VersionExt
        if (-not $installedVersion) {
            $installedVersion = (Get-ItemProperty $reg -ErrorAction SilentlyContinue).Version
        }
        break
    }
}

if ($installedVersion -and $installedVersion -like "$latestVersion*") {
    Write-LabSuccess "VirtualBox $latestVersion already installed. Skipping install."
    Write-Log "VirtualBox $installedVersion already present."
}
else {
    if ($installedVersion) {
        Write-LabWarning "Older VirtualBox $installedVersion detected — will upgrade to $latestVersion."
    }

    # ---------------------------------------------------------------------------
    # Step 3: Fetch SHA256 checksum file and extract the installer hash
    # ---------------------------------------------------------------------------
    Write-LabInfo "Fetching checksums..."
    try {
        $sha256Content = (Invoke-WebRequest -Uri $vboxSHA256Url -UseBasicParsing -TimeoutSec 30).Content
        $installerFile = "VirtualBox-$latestVersion-Win.exe"
        $hashLine      = ($sha256Content -split "`n") | Where-Object { $_ -match [regex]::Escape($installerFile) } | Select-Object -First 1
        $expectedHash  = if ($hashLine) { ($hashLine -split "\s+")[0].ToUpper() } else { "" }
        Write-Log "VirtualBox installer expected SHA256: $expectedHash"
    }
    catch {
        Write-LabWarning "Could not fetch checksum file. Download will proceed without hash verification."
        $expectedHash = ""
    }

    # ---------------------------------------------------------------------------
    # Step 4: Download VirtualBox installer
    # ---------------------------------------------------------------------------
    Get-LabFile -Url         $vboxInstallerUrl `
                -Destination $vboxInstallerPath `
                -DisplayName "VirtualBox $latestVersion for Windows" `
                -ExpectedHash $expectedHash

    # ---------------------------------------------------------------------------
    # Step 5: Silent install
    # ---------------------------------------------------------------------------
    Write-LabInfo "Installing VirtualBox $latestVersion (silent)..."
    Write-LabInfo "This may take 2–3 minutes..."

    $installArgs = @("--silent", "--ignore-reboot", "-msiparams", "ALLUSERS=1")
    $proc = Start-Process -FilePath $vboxInstallerPath `
                          -ArgumentList $installArgs `
                          -Wait -PassThru -NoNewWindow

    if ($proc.ExitCode -notin @(0, 3010)) {  # 3010 = reboot required but install succeeded
        throw "VirtualBox installer exited with code $($proc.ExitCode). Check Windows Event Log for details."
    }

    # Refresh PATH so VBoxManage is available in this session
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("PATH", "User")

    Write-LabSuccess "VirtualBox $latestVersion installed."
    Write-Log "VirtualBox $latestVersion installed successfully."
}

# ---------------------------------------------------------------------------
# Step 6: Extension Pack
# ---------------------------------------------------------------------------
Write-LabInfo "Checking VirtualBox Extension Pack..."

$extPackInstalled = $false
try {
    $extList = Invoke-VBox -Arguments @("list", "extpacks") -Silent
    $extPackInstalled = $extList -match "Oracle VirtualBox Extension Pack" -and $extList -match $latestVersion
}
catch { $extPackInstalled = $false }

if ($extPackInstalled) {
    Write-LabSuccess "Extension Pack $latestVersion already installed."
}
else {
    # Fetch Extension Pack hash from SHA256SUMS
    $extPackFile = "Oracle_VirtualBox_Extension_Pack-$latestVersion.vbox-extpack"
    $extHashLine = if ($sha256Content) {
        ($sha256Content -split "`n") | Where-Object { $_ -match [regex]::Escape($extPackFile) } | Select-Object -First 1
    }
    $extHash = if ($extHashLine) { ($extHashLine -split "\s+")[0].ToUpper() } else { "" }

    Get-LabFile -Url         $vboxExtPackUrl `
                -Destination $vboxExtPackPath `
                -DisplayName "VirtualBox Extension Pack $latestVersion" `
                -ExpectedHash $extHash

    Write-LabInfo "Installing Extension Pack (auto-accepting license)..."
    Invoke-VBox -Arguments @(
        "extpack", "install", "--replace",
        "--accept-license=56be48f923303c8cababb0bb4c478284b688ed23",
        $vboxExtPackPath
    ) -Description "Install Extension Pack"

    Write-LabSuccess "Extension Pack installed."
    Write-Log "VirtualBox Extension Pack $latestVersion installed."
}

# ---------------------------------------------------------------------------
# Step 7: 7-Zip (needed to extract Kali's .7z archive)
# ---------------------------------------------------------------------------
Write-LabInfo "Checking for 7-Zip..."

$sevenZipPaths = @(
    "$env:ProgramFiles\7-Zip\7z.exe"
    "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
)
$sevenZipFound = $sevenZipPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($sevenZipFound) {
    Write-LabSuccess "7-Zip found: $sevenZipFound"
}
else {
    Write-LabInfo "7-Zip not found — downloading and installing..."

    # Get latest 7-Zip version from their API
    try {
        $sevenZipPage = (Invoke-WebRequest -Uri "https://www.7-zip.org/download.html" -UseBasicParsing).Content
        $sevenZipMatch = [regex]::Match($sevenZipPage, 'href="a/7z(\d+(?:\.\d+)?)-x64\.exe"')
        $sevenZipVer  = $sevenZipMatch.Groups[1].Value
        $sevenZipUrl  = "https://www.7-zip.org/a/7z$sevenZipVer-x64.exe"
    }
    catch {
        # Fallback to known stable version
        $sevenZipVer = "2409"
        $sevenZipUrl = "https://www.7-zip.org/a/7z$sevenZipVer-x64.exe"
    }

    Write-LabInfo "Latest 7-Zip version: $sevenZipVer"
    $sevenZipInstaller = Join-Path $DownloadDir "7z-$sevenZipVer-x64.exe"

    Get-LabFile -Url $sevenZipUrl -Destination $sevenZipInstaller -DisplayName "7-Zip $sevenZipVer"

    $proc = Start-Process -FilePath $sevenZipInstaller -ArgumentList "/S" -Wait -PassThru -NoNewWindow
    if ($proc.ExitCode -ne 0) {
        throw "7-Zip installer failed with exit code $($proc.ExitCode)"
    }

    Write-LabSuccess "7-Zip installed."
    Write-Log "7-Zip $sevenZipVer installed."
}

Write-LabSuccess "VirtualBox setup complete — version $latestVersion ready."
