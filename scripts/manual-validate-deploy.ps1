# Requires: PowerShell 5+
# Purpose: Validate deployment without installer (script + logs).

[CmdletBinding()]
param(
  [string]$WorkspaceDir,
  [string]$McBopomofoWebDir,
  [string]$PimeSourceDir = "${env:ProgramFiles(x86)}\PIME",
  [string]$TargetDir = "${env:ProgramFiles(x86)}\PIME",
  [string]$PimeVersion = '1.3.0-stable',
  [string]$DefaultConfigPath,
  [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot

if (-not $WorkspaceDir) {
  $WorkspaceDir = Join-Path $ProjectRoot 'workspace'
}
if (-not $McBopomofoWebDir) {
  $McBopomofoWebDir = Join-Path $WorkspaceDir 'McBopomofoWeb'
}

$LogDir = Join-Path $ProjectRoot 'logs'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$LogFile = Join-Path $LogDir ("manual-validate-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
Start-Transcript -LiteralPath $LogFile -Force | Out-Null

function Step([string]$Text) {
  Write-Host "`n=== $Text ===" -ForegroundColor Cyan
}

function Assert-Admin {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Please run this script as Administrator.'
  }
}

function Assert-Command([string]$Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Missing required command: $Name"
  }
}

function Resolve-Tool([string]$ExeName, [string[]]$Candidates = @()) {
  $cmd = Get-Command $ExeName -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source) { return $cmd.Source }
  foreach ($p in $Candidates) {
    if ($p -and (Test-Path -LiteralPath $p -PathType Leaf)) { return $p }
  }
  return $null
}

function Invoke-External([string]$FilePath, [string[]]$Arguments = @()) {
  Write-Host ("$FilePath " + ($Arguments -join ' '))
  & $FilePath @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "Command failed (exit $LASTEXITCODE): $FilePath $($Arguments -join ' ')"
  }
}

function Reset-Dir([string]$Path) {
  if (Test-Path -LiteralPath $Path) {
    Remove-Item -LiteralPath $Path -Recurse -Force
  }
  New-Item -ItemType Directory -Path $Path | Out-Null
}

function Stop-ProcessIfRunning([string]$Name) {
  $procs = Get-Process -Name $Name -ErrorAction SilentlyContinue
  if ($procs) {
    $procs | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 300
  }
}

function Test-PimeRuntimeComplete([string]$DirPath) {
  if (-not (Test-Path -LiteralPath $DirPath -PathType Container)) {
    return $false
  }
  foreach ($f in @('PIMELauncher.exe','backends.json','x86\PIMETextService.dll','node\node.exe')) {
    if (-not (Test-Path -LiteralPath (Join-Path $DirPath $f) -PathType Leaf)) {
      return $false
    }
  }
  return $true
}

function Write-NodeOnlyBackendsJson([string]$Path) {
  $json = @(
    [ordered]@{
      name       = 'node'
      command    = 'node\\node.exe'
      workingDir = 'node'
      params     = 'server.js'
    }
  ) | ConvertTo-Json -Depth 5

  Set-Content -LiteralPath $Path -Value $json -Encoding UTF8
}

function Prepare-PimeRuntime([string]$Workspace, [string]$Version) {
  $sevenZip = Resolve-Tool '7z.exe' @(
    "$env:ProgramFiles\7-Zip\7z.exe",
    "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
  )
  if (-not $sevenZip) {
    throw '7z.exe not found. Please install 7-Zip first.'
  }

  $releaseDir = Join-Path $Workspace 'pime_release'
  New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null

  $setupName = "PIME-$Version-setup.exe"
  $setupPath = Join-Path $releaseDir $setupName
  $safeBase = Join-Path $env:TEMP "mcbopomofo_pime_$Version"
  $safeSetupPath = Join-Path $safeBase $setupName
  $extractDir = Join-Path $safeBase 'extracted'
  $url = "https://github.com/EasyIME/PIME/releases/download/v$Version/$setupName"

  if (-not (Test-Path -LiteralPath $setupPath -PathType Leaf)) {
    Step "Download prebuilt PIME $Version"
    $null = Invoke-WebRequest -Uri $url -OutFile $setupPath
  } else {
    Write-Host "Using cached: $setupPath"
  }

  New-Item -ItemType Directory -Force -Path $safeBase | Out-Null
  Copy-Item -LiteralPath $setupPath -Destination $safeSetupPath -Force

  Reset-Dir $extractDir
  $null = Invoke-External $sevenZip @('x', '-y', "-o$extractDir", $safeSetupPath)

  return (Resolve-Path -LiteralPath $extractDir).Path
}

try {
  Step 'Environment checks'
  Assert-Admin
  Assert-Command git
  Assert-Command node
  Assert-Command npm

  Step 'Prepare McBopomofoWeb source'
  New-Item -ItemType Directory -Force -Path $WorkspaceDir | Out-Null
  if (-not (Test-Path -LiteralPath $McBopomofoWebDir -PathType Container)) {
    Invoke-External 'git' @('clone', 'https://github.com/openvanilla/McBopomofoWeb.git', $McBopomofoWebDir)
  }

  if (-not $SkipBuild) {
    Step 'Build McBopomofoWeb output/pime'
    Push-Location $McBopomofoWebDir
    try {
      Invoke-External 'npm' @('install')
      Invoke-External 'npm' @('run', 'build:pime')
    } finally {
      Pop-Location
    }
  }

  $mcbOutput = Join-Path $McBopomofoWebDir 'output\pime'
  if (-not (Test-Path -LiteralPath (Join-Path $mcbOutput 'ime.json') -PathType Leaf)) {
    throw "Missing mcbopomofo output: $mcbOutput"
  }

  Step 'Prepare PIME runtime source'
  if (-not (Test-PimeRuntimeComplete -DirPath $PimeSourceDir)) {
    Write-Warning "PIME runtime missing/incomplete at: $PimeSourceDir"
    $PimeSourceDir = Prepare-PimeRuntime -Workspace $WorkspaceDir -Version $PimeVersion
  }

  foreach ($f in @('PIMELauncher.exe','backends.json','x86\PIMETextService.dll','node\node.exe')) {
    if (-not (Test-Path -LiteralPath (Join-Path $PimeSourceDir $f))) {
      throw "Required PIME file missing: $f"
    }
  }

  Step 'Deploy files to target'
  Write-Host "TargetDir: $TargetDir"
  New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null

  # Stop running processes first
  Stop-ProcessIfRunning -Name 'PIMELauncher'
  Stop-ProcessIfRunning -Name 'node'

  # Copy runtime
  Copy-Item -LiteralPath (Join-Path $PimeSourceDir 'PIMELauncher.exe') -Destination (Join-Path $TargetDir 'PIMELauncher.exe') -Force
  Copy-Item -LiteralPath (Join-Path $PimeSourceDir 'backends.json') -Destination (Join-Path $TargetDir 'backends.json') -Force
  Copy-Item -LiteralPath (Join-Path $PimeSourceDir 'x86') -Destination (Join-Path $TargetDir 'x86') -Recurse -Force
  if (Test-Path -LiteralPath (Join-Path $PimeSourceDir 'x64')) {
    Copy-Item -LiteralPath (Join-Path $PimeSourceDir 'x64') -Destination (Join-Path $TargetDir 'x64') -Recurse -Force
  }
  Copy-Item -LiteralPath (Join-Path $PimeSourceDir 'node') -Destination (Join-Path $TargetDir 'node') -Recurse -Force
  if (Test-Path -LiteralPath (Join-Path $PimeSourceDir 'python')) {
    Copy-Item -LiteralPath (Join-Path $PimeSourceDir 'python') -Destination (Join-Path $TargetDir 'python') -Recurse -Force
  }

  # Copy mcbopomofo module
  $imDir = Join-Path $TargetDir 'node\input_methods\McBopomofo'
  if (Test-Path -LiteralPath $imDir) {
    Remove-Item -LiteralPath $imDir -Recurse -Force
  }
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $imDir) | Out-Null
  Copy-Item -LiteralPath $mcbOutput -Destination $imDir -Recurse -Force

  # Keep only node backend / mcbopomofo module
  Write-NodeOnlyBackendsJson -Path (Join-Path $TargetDir 'backends.json')

  # Optional default config (copy only if user config doesn't exist)
  $cfgCandidate = $DefaultConfigPath
  if (-not $cfgCandidate) {
    $projectCfg = Join-Path $ProjectRoot 'config.json'
    if (Test-Path -LiteralPath $projectCfg -PathType Leaf) {
      $cfgCandidate = $projectCfg
    } else {
      $mcbCfg = Join-Path $mcbOutput 'config.json'
      if (Test-Path -LiteralPath $mcbCfg -PathType Leaf) {
        $cfgCandidate = $mcbCfg
      }
    }
  }
  if ($cfgCandidate) {
    $userCfgDir = Join-Path $env:APPDATA 'PIME\mcbopomofo'
    $userCfg = Join-Path $userCfgDir 'config.json'
    New-Item -ItemType Directory -Force -Path $userCfgDir | Out-Null
    if (-not (Test-Path -LiteralPath $userCfg -PathType Leaf)) {
      Copy-Item -LiteralPath $cfgCandidate -Destination $userCfg -Force
      Write-Host "Default config copied to: $userCfg"
    }
  }

  Step 'Register TSF DLLs'
  & "$env:WINDIR\SysWOW64\regsvr32.exe" /s (Join-Path $TargetDir 'x86\PIMETextService.dll')
  if ($LASTEXITCODE -ne 0) { throw "x86 regsvr32 failed: $LASTEXITCODE" }

  $x64dll = Join-Path $TargetDir 'x64\PIMETextService.dll'
  if (Test-Path -LiteralPath $x64dll) {
    & "$env:WINDIR\System32\regsvr32.exe" /s $x64dll
    if ($LASTEXITCODE -ne 0) { throw "x64 regsvr32 failed: $LASTEXITCODE" }
  }

  Step 'Write registry + start launcher'
  New-Item -Path 'HKLM:\Software\PIME' -Force | Out-Null
  $null = & reg.exe add "HKLM\Software\PIME" /ve /t REG_SZ /d "$TargetDir" /f
  New-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'PIMELauncher' -Value (Join-Path $TargetDir 'PIMELauncher.exe') -PropertyType String -Force | Out-Null

  Start-Process (Join-Path $TargetDir 'PIMELauncher.exe')
  Start-Sleep -Seconds 2

  Step 'Quick verification'
  Test-Path (Join-Path $TargetDir 'x86\PIMETextService.dll') | Write-Host
  Test-Path (Join-Path $TargetDir 'x64\PIMETextService.dll') | Write-Host
  Test-Path (Join-Path $TargetDir 'node\input_methods\McBopomofo\ime.json') | Write-Host

  $pimeLog = Join-Path $env:LOCALAPPDATA 'PIME\Log\PIMELauncher.log'
  if (Test-Path -LiteralPath $pimeLog) {
    $size = (Get-Item -LiteralPath $pimeLog).Length
    Write-Host "PIMELauncher.log: $pimeLog (size=$size bytes)"
  } else {
    Write-Warning "PIMELauncher.log not found yet: $pimeLog"
  }

  Write-Host "`nSUCCESS. Please sign out/sign in (or reboot) and check input method list." -ForegroundColor Green
}
finally {
  Stop-Transcript | Out-Null
  Write-Host "Transcript: $LogFile"
}
