#Requires -Version 5.1
<#
.SYNOPSIS
    CyberLab — One-click cybersecurity home lab deployment.

.DESCRIPTION
    Automatically installs VirtualBox and deploys a fully networked home lab
    containing Kali Linux (attacker), Security Onion (defender/monitor),
    Metasploitable 2, and Basic Pentesting 1 (targets).

    Always downloads the latest stable versions of all components.

.NOTES
    Author:  Marius Poskus | mpcybersecurity.co.uk
    Version: 1.0
    Requires: Windows 10/11 64-bit, 16 GB RAM, 150 GB free disk, VT-x/AMD-V

.EXAMPLE
    Right-click Start-CyberLab.ps1 → "Run with PowerShell"
    Or from an elevated PowerShell prompt: .\Start-CyberLab.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Self-elevate to Administrator if not already
# ---------------------------------------------------------------------------
if (-NOT ([Security.Principal.WindowsPrincipal]
        [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

    Write-Host "Requesting Administrator privileges..." -ForegroundColor Yellow
    Start-Process PowerShell -ArgumentList `
        "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" `
        -Verb RunAs
    exit
}

Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# ---------------------------------------------------------------------------
# Load configuration and shared helpers
# ---------------------------------------------------------------------------
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$ScriptRoot\config.ps1"
. "$ScriptRoot\modules\Helpers.ps1"

# ---------------------------------------------------------------------------
# Initialise log and directories
# ---------------------------------------------------------------------------
$null = New-Item -ItemType Directory -Path $LabPath     -Force
$null = New-Item -ItemType Directory -Path $DownloadDir -Force

Write-Log "====== CyberLab Setup Started $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ======"

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
Clear-Host
Write-Host @"

  ██████╗██╗   ██╗██████╗ ███████╗██████╗ ██╗      █████╗ ██████╗
 ██╔════╝╚██╗ ██╔╝██╔══██╗██╔════╝██╔══██╗██║     ██╔══██╗██╔══██╗
 ██║      ╚████╔╝ ██████╔╝█████╗  ██████╔╝██║     ███████║██████╔╝
 ██║       ╚██╔╝  ██╔══██╗██╔══╝  ██╔══██╗██║     ██╔══██║██╔══██╗
 ╚██████╗   ██║   ██████╔╝███████╗██║  ██║███████╗██║  ██║██████╔╝
  ╚═════╝   ╚═╝   ╚═════╝ ╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═════╝

  Home Lab Automation by MP Cybersecurity | mpcybersecurity.co.uk
  Version 1.0 — Always downloads the latest stable versions

"@ -ForegroundColor Cyan

Write-LabInfo "This script will build your complete cybersecurity home lab."
Write-LabInfo "Total download: ~8 GB | Total install time: ~45-60 minutes"
Write-LabInfo "Log file: $LogFile"
Write-Host ""

$confirm = Read-Host "Press ENTER to begin, or type 'quit' to exit"
if ($confirm -eq 'quit') { exit 0 }

# ---------------------------------------------------------------------------
# Run modules in sequence
# ---------------------------------------------------------------------------
$modules = @(
    @{ Name = "System Prerequisites"; File = "00-Prerequisites.ps1" }
    @{ Name = "VirtualBox Installation"; File = "01-VirtualBox.ps1" }
    @{ Name = "Lab Network Setup"; File = "02-Networking.ps1" }
    @{ Name = "Kali Linux"; File = "03-Kali.ps1" }
    @{ Name = "Security Onion"; File = "04-SecurityOnion.ps1" }
    @{ Name = "Metasploitable 2"; File = "05-Metasploitable.ps1" }
    @{ Name = "Basic Pentesting 1"; File = "06-VulnHub.ps1" }
    @{ Name = "Lab Summary"; File = "07-Summary.ps1" }
)

$totalSteps = $modules.Count
$step = 0

foreach ($module in $modules) {
    $step++
    $modulePath = Join-Path $ScriptRoot "modules\$($module.File)"

    Write-Host ""
    Write-Host "─" * 70 -ForegroundColor DarkGray
    Write-LabStep "[$step/$totalSteps] $($module.Name)"
    Write-Host "─" * 70 -ForegroundColor DarkGray

    try {
        . $modulePath
        Write-Log "Module $($module.File) completed successfully."
    }
    catch {
        Write-LabError "Module '$($module.Name)' failed: $_"
        Write-Log "ERROR in $($module.File): $_"
        Write-Host ""
        Write-LabWarning "Setup stopped at step $step/$totalSteps."
        Write-LabWarning "Check the log for details: $LogFile"
        Write-Host ""
        Write-Host "Common fixes:" -ForegroundColor Yellow
        Write-Host "  - Check REQUIREMENTS.md for system requirements"
        Write-Host "  - Ensure you have 150 GB+ free disk space"
        Write-Host "  - Ensure VT-x/AMD-V is enabled in BIOS"
        Write-Host "  - Disable Hyper-V if WSL2 or Docker is installed"
        Write-Host ""
        Read-Host "Press ENTER to exit"
        exit 1
    }
}

Write-Log "====== CyberLab Setup Completed $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ======"
