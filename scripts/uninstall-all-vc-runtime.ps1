# Requires: PowerShell 5+
# Purpose: Enumerate and uninstall Microsoft Visual C++ Redistributable packages
# on a Windows 11 x64 machine. This is intended as a manual cleanup helper for
# installer validation, not for normal end-user uninstall flow.

[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [switch]$IncludeARM,
  [switch]$WhatIfOnly
)

$ErrorActionPreference = 'Stop'

function Assert-Admin {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Please run this script in an elevated PowerShell session.'
  }
}

function Get-UninstallEntries {
  $paths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
  )

  foreach ($path in $paths) {
    Get-ItemProperty -Path $path -ErrorAction SilentlyContinue |
      Where-Object {
        $_.DisplayName -match '^Microsoft Visual C\+\+ .* Redistributable' -and
        $_.UninstallString
      } |
      Sort-Object DisplayName, DisplayVersion -Unique
  }
}

function Should-IncludeEntry($Entry, [bool]$AllowArm) {
  if ($AllowArm) {
    return $true
  }
  return ($Entry.DisplayName -notmatch '\bARM64\b')
}

function Get-UninstallCommand($Entry) {
  $raw = ($Entry.UninstallString -as [string]).Trim()
  if (-not $raw) {
    return $null
  }

  if ($raw -match 'MsiExec\.exe') {
    $args = $raw -replace '^\s*"?MsiExec\.exe"?\s*', ''
    $productCodeMatch = [regex]::Match($args, '\{[0-9A-Fa-f\-]{36}\}')

    if ($productCodeMatch.Success) {
      $productCode = $productCodeMatch.Value
      $args = "/x $productCode"
    } else {
      $args = [regex]::Replace($args, '(^|\s)/i(?=\s|\{)', '$1/x', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
      if ($args -notmatch '(^|\s)/x(\s|$|\{)') {
        $args = "/x $args"
      }
    }

    if ($args -notmatch '(^|\s)/quiet(\s|$)' -and $args -notmatch '(^|\s)/qn(\s|$)') {
      $args += ' /qn'
    }
    if ($args -notmatch '(^|\s)/norestart(\s|$)') {
      $args += ' /norestart'
    }
    return [pscustomobject]@{
      FilePath = "$env:SystemRoot\System32\msiexec.exe"
      Arguments = $args.Trim()
    }
  }

  $filePath = $null
  $arguments = ''
  if ($raw.StartsWith('"')) {
    $endQuote = $raw.IndexOf('"', 1)
    if ($endQuote -gt 1) {
      $filePath = $raw.Substring(1, $endQuote - 1)
      $arguments = $raw.Substring($endQuote + 1).Trim()
    }
  }

  if (-not $filePath) {
    $firstSpace = $raw.IndexOf(' ')
    if ($firstSpace -gt 0) {
      $filePath = $raw.Substring(0, $firstSpace)
      $arguments = $raw.Substring($firstSpace + 1).Trim()
    } else {
      $filePath = $raw
    }
  }

  if ($arguments -notmatch '(^|\s)/(quiet|passive)\b') {
    $arguments += ' /quiet'
  }
  if ($arguments -notmatch '(^|\s)/(norestart)\b') {
    $arguments += ' /norestart'
  }

  return [pscustomobject]@{
    FilePath = $filePath
    Arguments = $arguments.Trim()
  }
}

Assert-Admin

$entries = @(Get-UninstallEntries | Where-Object { Should-IncludeEntry $_ $IncludeARM.IsPresent })

if ($entries.Count -eq 0) {
  Write-Host 'No Microsoft Visual C++ Redistributable entries found.' -ForegroundColor Yellow
  return
}

Write-Host 'Detected Microsoft Visual C++ Redistributables:' -ForegroundColor Cyan
$entries |
  Select-Object DisplayName, DisplayVersion, PSChildName |
  Format-Table -AutoSize

foreach ($entry in $entries) {
  $cmd = Get-UninstallCommand $entry
  if (-not $cmd) {
    Write-Warning "Skipping entry without usable uninstall command: $($entry.DisplayName)"
    continue
  }

  $display = "$($entry.DisplayName) $($entry.DisplayVersion)"
  if ($WhatIfOnly) {
    Write-Host "[WhatIf] $display" -ForegroundColor Yellow
    Write-Host "         $($cmd.FilePath) $($cmd.Arguments)"
    continue
  }

  if ($PSCmdlet.ShouldProcess($display, 'Uninstall Visual C++ Redistributable')) {
    Write-Host "[Uninstall] $display" -ForegroundColor Cyan
    $process = Start-Process -FilePath $cmd.FilePath -ArgumentList $cmd.Arguments -Wait -PassThru
    Write-Host "[ExitCode] $($process.ExitCode)" -ForegroundColor DarkGray
  }
}

Write-Host 'Done.' -ForegroundColor Green
