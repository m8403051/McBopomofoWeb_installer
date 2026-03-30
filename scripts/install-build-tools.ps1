# Requires: PowerShell 5+
# Purpose: Install required Windows build tools for this project via winget.

$ErrorActionPreference = 'Stop'
$ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$VCRedistCacheDir = Join-Path $ProjectRoot 'cache\vcredist'

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

function Refresh-ProcessPath {
  $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
  $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  $env:Path = "$machinePath;$userPath"
}

function Resolve-Tool([string]$ExeName, [string[]]$Candidates) {
  $cmd = Get-Command $ExeName -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source) {
    return $cmd.Source
  }

  foreach ($path in $Candidates) {
    if ($path -and (Test-Path -LiteralPath $path -PathType Leaf)) {
      return $path
    }
  }

  return $null
}

function Get-VCRedistDownloadUrl([string]$Arch) {
  switch ($Arch.ToLowerInvariant()) {
    'x64' { return 'https://aka.ms/vc14/vc_redist.x64.exe' }
    'x86' { return 'https://aka.ms/vc14/vc_redist.x86.exe' }
    default { throw "Unsupported VC redist architecture: $Arch" }
  }
}

function Get-VCRedistCanonicalPath([string]$Arch) {
  return (Join-Path $VCRedistCacheDir ("vc_redist.{0}.exe" -f $Arch.ToLowerInvariant()))
}

function Get-VCRedistCandidateItems([string]$Arch) {
  $name = "vc_redist.{0}.exe" -f $Arch.ToLowerInvariant()
  $items = New-Object System.Collections.Generic.List[System.IO.FileInfo]

  $candidateDirs = @(
    $VCRedistCacheDir,
    $ProjectRoot,
    (Join-Path $env:USERPROFILE 'Downloads'),
    (Join-Path $env:USERPROFILE 'Desktop'),
    $env:TEMP
  ) | Where-Object { $_ } | Select-Object -Unique

  foreach ($dir in $candidateDirs) {
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
      continue
    }

    $path = Join-Path $dir $name
    if (Test-Path -LiteralPath $path -PathType Leaf) {
      $items.Add((Get-Item -LiteralPath $path))
    }
  }

  return $items
}

function Get-FileVersionOrDefault([System.IO.FileInfo]$Item) {
  try {
    return [version]$Item.VersionInfo.FileVersion
  } catch {
    return [version]'0.0'
  }
}

function Ensure-VCRedistBinary([string]$Arch) {
  New-Item -ItemType Directory -Force -Path $VCRedistCacheDir | Out-Null

  $canonicalPath = Get-VCRedistCanonicalPath $Arch
  $candidates = Get-VCRedistCandidateItems $Arch |
    Sort-Object `
      @{ Expression = { Get-FileVersionOrDefault $_ }; Descending = $true }, `
      @{ Expression = { $_.LastWriteTimeUtc }; Descending = $true }

  if ($candidates.Count -gt 0) {
    $best = $candidates[0]
    if ($best.FullName -ne $canonicalPath) {
      Copy-Item -LiteralPath $best.FullName -Destination $canonicalPath -Force
    }
    Write-Host "[Ready] vc_redist.$Arch.exe -> $canonicalPath (source: $($best.FullName))" -ForegroundColor Yellow
    return $canonicalPath
  }

  $url = Get-VCRedistDownloadUrl $Arch
  Write-Host "[Download] vc_redist.$Arch.exe from $url" -ForegroundColor Cyan
  Invoke-WebRequest -Uri $url -OutFile $canonicalPath
  Write-Host "[Ready] vc_redist.$Arch.exe -> $canonicalPath" -ForegroundColor Green
  return $canonicalPath
}

function Is-Installed([string]$Id) {
  $out = winget list --id $Id --exact --source winget --accept-source-agreements 2>$null | Out-String
  return ($out -match [Regex]::Escape($Id))
}

function Install-Package([string]$Id) {
  if (Is-Installed $Id) {
    Write-Host "[Skip] $Id already installed." -ForegroundColor Yellow
    return
  }

  $maxRetries = 3
  for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
    Write-Host "[Install] $Id (attempt $attempt/$maxRetries)" -ForegroundColor Cyan
    winget install -e --id $Id --source winget --scope machine --silent --disable-interactivity --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -eq 0) {
      return
    }

    Write-Warning "Install failed for $Id (winget exit code: $LASTEXITCODE)"
    if ($attempt -lt $maxRetries) {
      Start-Sleep -Seconds (3 * $attempt)
    }
  }

  if ($Id -eq 'NSIS.NSIS') {
    throw "Failed to install NSIS via winget after $maxRetries attempts. This package downloads from SourceForge and may be blocked/canceled by network policy. Please install NSIS manually, then rerun this script."
  }

  throw "Failed to install $Id after $maxRetries attempts."
}

Assert-Admin
Assert-Winget

$packages = @(
  'Git.Git',
  'OpenJS.NodeJS.LTS',
  'NSIS.NSIS',
  'WiXToolset.WiXToolset',
  '7zip.7zip'
)

foreach ($id in $packages) {
  Install-Package $id
}

Write-Host "`n=== Prepare VC Redistributable Cache ===" -ForegroundColor Green
$vcRedistX64 = Ensure-VCRedistBinary 'x64'
$vcRedistX86 = Ensure-VCRedistBinary 'x86'

Refresh-ProcessPath

Write-Host "\n=== Verify ===" -ForegroundColor Green
$git = Resolve-Tool 'git.exe' @(
  "$env:ProgramFiles\Git\cmd\git.exe",
  "$env:ProgramFiles\Git\bin\git.exe",
  "${env:ProgramFiles(x86)}\Git\cmd\git.exe"
)
if ($git) { & $git --version } else { Write-Warning 'git not found.' }

$node = Resolve-Tool 'node.exe' @(
  "$env:ProgramFiles\nodejs\node.exe",
  "${env:ProgramFiles(x86)}\nodejs\node.exe"
)
if ($node) { & $node --version } else { Write-Warning 'node not found.' }

$npm = Resolve-Tool 'npm.cmd' @(
  "$env:ProgramFiles\nodejs\npm.cmd",
  "${env:ProgramFiles(x86)}\nodejs\npm.cmd"
)
if ($npm) { & $npm --version } else { Write-Warning 'npm not found.' }

$makensis = Resolve-Tool 'makensis.exe' @(
  "${env:ProgramFiles(x86)}\NSIS\makensis.exe",
  "$env:ProgramFiles\NSIS\makensis.exe"
)
if ($makensis) { & $makensis /VERSION } else { Write-Warning 'makensis not found.' }

$wix = Resolve-Tool 'wix.exe' @(
  "$env:ProgramFiles\WiX Toolset v6.0\bin\wix.exe",
  "$env:ProgramFiles\WiX Toolset v5.0\bin\wix.exe",
  "$env:ProgramFiles\WiX Toolset v4.0\bin\wix.exe",
  "$env:LOCALAPPDATA\Programs\WiX Toolset\bin\wix.exe"
)
if ($wix) {
  & $wix --version
} else {
  # WiX v3 does not provide wix.exe; it uses candle.exe/light.exe.
  $candle = Resolve-Tool 'candle.exe' @(
    "${env:ProgramFiles(x86)}\WiX Toolset v3.14\bin\candle.exe",
    "${env:ProgramFiles(x86)}\WiX Toolset v3.11\bin\candle.exe",
    "$env:ProgramFiles\WiX Toolset v3.14\bin\candle.exe",
    "$env:ProgramFiles\WiX Toolset v3.11\bin\candle.exe"
  )
  $light = Resolve-Tool 'light.exe' @(
    "${env:ProgramFiles(x86)}\WiX Toolset v3.14\bin\light.exe",
    "${env:ProgramFiles(x86)}\WiX Toolset v3.11\bin\light.exe",
    "$env:ProgramFiles\WiX Toolset v3.14\bin\light.exe",
    "$env:ProgramFiles\WiX Toolset v3.11\bin\light.exe"
  )

  if ($candle -and $light) {
    & $candle -? | Select-Object -First 1
    Write-Host "[OK] WiX v3 detected (candle/light)." -ForegroundColor Green
  } else {
    Write-Warning 'wix (v4+) or candle/light (v3) not found.'
  }
}

$sevenZip = Resolve-Tool '7z.exe' @(
  "$env:ProgramFiles\7-Zip\7z.exe",
  "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
)
if ($sevenZip) { & $sevenZip | Select-Object -First 2 } else { Write-Warning '7z not found.' }

Write-Host "`n=== VC Redistributable Cache ===" -ForegroundColor Green
Get-Item -LiteralPath $vcRedistX64, $vcRedistX86 |
  Select-Object Name, FullName, Length, @{ Name = 'FileVersion'; Expression = { $_.VersionInfo.FileVersion } } |
  Format-Table -AutoSize

Write-Host "\nDone. If any command is missing, reopen terminal (or reboot) and verify again." -ForegroundColor Green
