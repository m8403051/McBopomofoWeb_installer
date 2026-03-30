# Requires: PowerShell 5+
# Purpose: Uninstall build tools installed by install-build-tools.ps1 via winget.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Assert-Admin {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Please run this script as Administrator.'
  }
}

function Assert-Winget {
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw 'winget is not available. Please install/update Microsoft App Installer first.'
  }
}

function Is-Installed([string]$Id) {
  $out = winget list --id $Id --exact --source winget --accept-source-agreements 2>$null | Out-String
  return ($out -match [Regex]::Escape($Id))
}

function Uninstall-Package([string]$Id) {
  if (-not (Is-Installed $Id)) {
    Write-Host "[Skip] $Id is not installed." -ForegroundColor Yellow
    return
  }

  Write-Host "[Uninstall] $Id" -ForegroundColor Cyan

  winget uninstall -e --id $Id --source winget --scope machine --silent --accept-source-agreements
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "Machine scope uninstall failed for $Id, retry without scope..."
    winget uninstall -e --id $Id --source winget --silent --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
      throw "Failed to uninstall $Id (winget exit code: $LASTEXITCODE)"
    }
  }
}

Assert-Admin
Assert-Winget

$packages = @(
  '7zip.7zip',
  'WiXToolset.WiXToolset',
  'NSIS.NSIS',
  'OpenJS.NodeJS.LTS',
  'Git.Git'
)

foreach ($id in $packages) {
  Uninstall-Package $id
}

Write-Host "\n=== Verify ===" -ForegroundColor Green
foreach ($id in $packages) {
  if (Is-Installed $id) {
    Write-Warning "$id is still installed."
  } else {
    Write-Host "[OK] $id removed"
  }
}

Write-Host "\nDone. Reopen terminal (or reboot) if old PATH still appears." -ForegroundColor Green
