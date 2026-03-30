# Requires: PowerShell 5+
# Build McBopomofo for Windows installer.
# Strategy: Use prebuilt PIME runtime + McBopomofoWeb build:pime output.

[CmdletBinding()]
param(
  [string]$WorkspaceDir,
  [string]$McBopomofoWebDir,
  [string]$PimeSourceDir,
  [string]$PimeVersion = '1.3.0-stable',
  [string]$ExpectedMcBopomofoWebCommit = 'a488c4d36dcef60ed7f7445798b0597c4c874022',
  [string]$DefaultConfigPath,
  [string]$DistDir,
  [string]$Version = (Get-Date -Format 'yyyy.MM.dd'),
  [string]$VCRedistX64Path,
  [string]$VCRedistX86Path,
  [switch]$FullOnly,
  [switch]$LiteOnly,
  [switch]$SkipClone
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

if (-not $WorkspaceDir) {
  $WorkspaceDir = Join-Path $ProjectRoot 'workspace'
}

if (-not $DistDir) {
  $DistDir = Join-Path $ProjectRoot 'dist'
}

if (-not $McBopomofoWebDir) {
  $McBopomofoWebDir = Join-Path $WorkspaceDir 'McBopomofoWeb'
}

$BuildDir = Join-Path $ProjectRoot 'build'
$StageDir = Join-Path $BuildDir 'staging'
$CoreStageDir = Join-Path $StageDir 'core'
$CoreLicenseDir = Join-Path $CoreStageDir 'licenses'
$CoreFontDir = Join-Path $CoreStageDir 'fonts'
$HelperStageDir = Join-Path $StageDir 'helpers'
$VCRedistStageDir = Join-Path $StageDir 'vcredist'
$NsisScript = Join-Path $ProjectRoot 'installer\McBopomofoPIME.nsi'
$WorkspacePimeExtractedDir = Join-Path $WorkspaceDir 'pime_release\extracted'
$McBopomofoWebOverlayDir = Join-Path $ProjectRoot 'upstream-patches\McBopomofoWeb'
$InstalledPimeDir = "${env:ProgramFiles(x86)}\PIME"
$VCRedistCacheDir = Join-Path $ProjectRoot 'cache\vcredist'
$FontCacheDir = Join-Path $ProjectRoot 'cache\fonts\bpmfvs'
$PimeSourceTag = "v{0}" -f $PimeVersion

function Resolve-Tool([string]$ExeName, [string[]]$Candidates = @()) {
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

function Assert-File([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Required file not found: $Path"
  }
}

function Assert-Dir([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    throw "Required directory not found: $Path"
  }
}

function Reset-Dir([string]$Path) {
  if (Test-Path -LiteralPath $Path) {
    Remove-Item -LiteralPath $Path -Recurse -Force
  }
  New-Item -ItemType Directory -Path $Path | Out-Null
}

function Apply-McBopomofoWebOverlay([string]$OverlayDir, [string]$TargetDir) {
  if (-not (Test-Path -LiteralPath $OverlayDir -PathType Container)) {
    return
  }

  Write-Host "Applying McBopomofoWeb overlay from $OverlayDir" -ForegroundColor DarkCyan
  Copy-Item -LiteralPath (Join-Path $OverlayDir '*') -Destination $TargetDir -Recurse -Force
}

function Copy-IfExists([string]$Source, [string]$Dest) {
  if (Test-Path -LiteralPath $Source) {
    Copy-Item -LiteralPath $Source -Destination $Dest -Recurse -Force
  }
}

function Resolve-RequiredTool([string]$DisplayName, [string[]]$Commands, [string[]]$Candidates = @()) {
  foreach ($cmd in $Commands) {
    $resolved = Resolve-Tool $cmd $Candidates
    if ($resolved) {
      return $resolved
    }
  }
  throw "Missing required command: $DisplayName"
}

function Write-ExactNodeBackendsJson([string]$Path) {
  # PIMELauncher accepts the original array form used by staged/runtime payloads.
  $nodeOnlyConfig = @(
    [ordered]@{
      name       = 'node'
      command    = 'node\node.exe'
      workingDir = 'node'
      params     = 'server.js'
    }
  )
  $json = ConvertTo-Json -InputObject $nodeOnlyConfig -Depth 4
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)

  [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, $utf8NoBom)
}

function Invoke-External([string]$FilePath, [string[]]$Arguments = @()) {
  & $FilePath @Arguments
  if ($LASTEXITCODE -ne 0) {
    $argText = ($Arguments -join ' ')
    throw "Command failed (exit $LASTEXITCODE): $FilePath $argText"
  }
}

function Invoke-ExternalCapture([string]$FilePath, [string[]]$Arguments = @()) {
  $output = & $FilePath @Arguments 2>&1
  if ($LASTEXITCODE -ne 0) {
    $argText = ($Arguments -join ' ')
    throw "Command failed (exit $LASTEXITCODE): $FilePath $argText"
  }
  return ($output | Out-String).Trim()
}

function Invoke-ExternalWithExitCode([string]$FilePath, [string[]]$Arguments = @()) {
  & $FilePath @Arguments
  return $LASTEXITCODE
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

function Get-FileVersionOrDefault([System.IO.FileInfo]$Item) {
  try {
    return [version]$Item.VersionInfo.FileVersion
  } catch {
    return [version]'0.0'
  }
}

function Get-VCRedistCandidateItems([string]$Arch) {
  $name = "vc_redist.{0}.exe" -f $Arch.ToLowerInvariant()
  $items = New-Object System.Collections.Generic.List[System.IO.FileInfo]
  $candidateDirs = @(
    $VCRedistCacheDir,
    (Join-Path $WorkspaceDir 'vcredist'),
    $WorkspaceDir,
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

function Resolve-VCRedistBinary([string]$Arch, [string]$ExplicitPath) {
  if ($ExplicitPath) {
    Assert-File $ExplicitPath
    return (Resolve-Path -LiteralPath $ExplicitPath).Path
  }

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
    return $canonicalPath
  }

  $url = Get-VCRedistDownloadUrl $Arch
  Write-Host "Downloading vc_redist.$Arch.exe: $url" -ForegroundColor Cyan
  Invoke-WebRequest -Uri $url -OutFile $canonicalPath
  return $canonicalPath
}

function Write-Utf8NoBomFile([string]$Path, [string]$Content) {
  $dir = Split-Path -Parent $Path
  if ($dir) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Expand-ZipArchive([string]$ZipPath, [string]$DestinationPath) {
  Reset-Dir $DestinationPath
  Expand-Archive -LiteralPath $ZipPath -DestinationPath $DestinationPath -Force
}

function Get-BpmfvsPackageSpecs() {
  return @(
    [ordered]@{ Archive = 'BpmfZihiKaiStd.zip'; Family = 'BpmfZihiKaiStd' },
    [ordered]@{ Archive = 'BpmfZihiSans.zip'; Family = 'BpmfZihiSans' },
    [ordered]@{ Archive = 'BpmfZihiSerif.zip'; Family = 'BpmfZihiSerif' },
    [ordered]@{ Archive = 'BpmfSpecial.zip'; Family = 'BpmfSpecial' }
  )
}

function Write-LicenseBundle([string]$Path, [string]$HeaderTitle, [string]$RepositoryUrl, [string[]]$Sections) {
  $parts = @(
    $HeaderTitle,
    '',
    "GitHub: $RepositoryUrl",
    'This installer redistributes content from the GitHub repository above.',
    'Continue the installation only if you accept the license terms below.',
    ''
  )
  $parts += $Sections
  Write-Utf8NoBomFile -Path $Path -Content ($parts -join [Environment]::NewLine)
}

function Get-RemoteTextLines([string]$Url) {
  $response = Invoke-WebRequest -UseBasicParsing -Uri $Url
  return ($response.Content -split "`r?`n")
}

function Get-PimeLicenseUrl([string]$FileName) {
  return "https://raw.githubusercontent.com/EasyIME/PIME/{0}/{1}" -f $PimeSourceTag, $FileName
}

function Prepare-BpmfvsFonts([string]$StageFontsDir, [string]$StageLicenseDir) {
  $downloadBase = 'https://github.com/ButTaiwan/bpmfvs/releases/latest/download'
  $latestCacheDir = Join-Path $FontCacheDir 'latest'
  $extractRoot = Join-Path $latestCacheDir 'extracted'
  $headers = @{
    'User-Agent' = 'McBopomofo-PIME-Build'
    'Accept'     = 'application/octet-stream'
  }

  Reset-Dir $StageFontsDir
  New-Item -ItemType Directory -Force -Path $StageLicenseDir | Out-Null
  New-Item -ItemType Directory -Force -Path $latestCacheDir | Out-Null
  New-Item -ItemType Directory -Force -Path $extractRoot | Out-Null

  $fontLicenseSections = @(
    'Fonts from ButTaiwan/bpmfvs',
    'Included packages:',
    '- BpmfZihiKaiStd',
    '- BpmfZihiSans',
    '- BpmfZihiSerif',
    '- BpmfSpecial',
    '',
    'The text files below are copied from the downloaded release archives.',
    ''
  )

  foreach ($spec in Get-BpmfvsPackageSpecs) {
    $zipPath = Join-Path $latestCacheDir $spec.Archive
    $extractDir = Join-Path $extractRoot $spec.Family
    $url = "$downloadBase/$($spec.Archive)"

    Write-Host "Downloading $($spec.Archive): $url" -ForegroundColor Cyan
    Invoke-WebRequest -Headers $headers -Uri $url -OutFile $zipPath
    Expand-ZipArchive -ZipPath $zipPath -DestinationPath $extractDir

    $ttfItems = Get-ChildItem -LiteralPath $extractDir -Filter '*.ttf' -File
    if ($ttfItems.Count -eq 0) {
      throw "No TTF font files found in archive: $zipPath"
    }
    foreach ($ttf in $ttfItems) {
      Copy-Item -LiteralPath $ttf.FullName -Destination (Join-Path $StageFontsDir $ttf.Name) -Force
    }

    $fontLicenseSections += "===== $($spec.Family) ====="
    $fontLicenseSections += "Downloaded from: $url"
    $fontLicenseSections += 'Files included:'
    foreach ($ttf in $ttfItems | Sort-Object Name) {
      $fontLicenseSections += "- $($ttf.Name)"
    }
    foreach ($textItem in (Get-ChildItem -LiteralPath $extractDir -File | Where-Object { $_.Extension -eq '.txt' } | Sort-Object Name)) {
      $fontLicenseSections += ''
      $fontLicenseSections += "----- $($textItem.Name) -----"
      $fontLicenseSections += ''
      $fontLicenseSections += (Get-Content -LiteralPath $textItem.FullName)
    }
    $fontLicenseSections += ''
  }

  Write-LicenseBundle `
    -Path (Join-Path $StageLicenseDir 'Fonts-LICENSE.txt') `
    -HeaderTitle 'Optional Font Pack License and Notice' `
    -RepositoryUrl 'https://github.com/ButTaiwan/bpmfvs/' `
    -Sections $fontLicenseSections
}

function Stage-ThirdPartyLicenses([string]$StageLicenseDir) {
  $mcbLicense = Get-Content -LiteralPath (Join-Path $McBopomofoWebDir 'LICENSE.txt')
  $mcbSections = @(
    'McBopomofo for Windows bundles the McBopomofoWeb project as the core backend payload.',
    '',
    '----- LICENSE.txt -----',
    ''
  ) + $mcbLicense

  Write-LicenseBundle `
    -Path (Join-Path $StageLicenseDir 'McBopomofoWeb-LICENSE.txt') `
    -HeaderTitle 'McBopomofoWeb License' `
    -RepositoryUrl 'https://github.com/openvanilla/McBopomofoWeb' `
    -Sections $mcbSections

  $pimeSections = @(
    'McBopomofo for Windows bundles runtime components from the PIME project.',
    '',
    '----- LICENSE.txt -----',
    ''
  ) + (Get-RemoteTextLines (Get-PimeLicenseUrl 'LICENSE.txt'))

  $pimeSections += @(
    '',
    '----- LGPL-2.0.txt -----',
    ''
  )
  $pimeSections += Get-RemoteTextLines (Get-PimeLicenseUrl 'LGPL-2.0.txt')
  $pimeSections += @(
    '',
    '----- PSF.txt -----',
    ''
  )
  $pimeSections += Get-RemoteTextLines (Get-PimeLicenseUrl 'PSF.txt')

  Write-LicenseBundle `
    -Path (Join-Path $StageLicenseDir 'PIME-LICENSE.txt') `
    -HeaderTitle 'PIME License' `
    -RepositoryUrl 'https://github.com/EasyIME/PIME' `
    -Sections $pimeSections
}

function Archive-DistArtifacts([string]$TargetDir) {
  if (-not (Test-Path -LiteralPath $TargetDir -PathType Container)) {
    return
  }

  $items = Get-ChildItem -LiteralPath $TargetDir -File | Where-Object {
    $_.Name -like 'McBopomofo-PIME-Setup-*.exe' -or
    $_.Name -like 'artifacts-manifest*.txt'
  }
  if ($items.Count -eq 0) {
    return
  }

  $archiveDir = Join-Path $TargetDir ('archive\{0}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
  New-Item -ItemType Directory -Force -Path $archiveDir | Out-Null
  foreach ($item in $items) {
    Move-Item -LiteralPath $item.FullName -Destination (Join-Path $archiveDir $item.Name) -Force
  }
}

function Prepare-PimeRuntime([string]$Workspace, [string]$TargetVersion) {
  $sevenZip = Resolve-Tool '7z.exe' @(
    "$env:ProgramFiles\7-Zip\7z.exe",
    "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
  )
  if (-not $sevenZip) {
    throw 'PIME runtime directory not found, and 7z is not available for auto-extract.'
  }

  $downloadDir = Join-Path $Workspace 'pime_release'
  New-Item -ItemType Directory -Force -Path $downloadDir | Out-Null

  $setupName = "PIME-$TargetVersion-setup.exe"
  $setupPath = Join-Path $downloadDir $setupName
  $extractDir = Join-Path $downloadDir 'extracted'
  $url = "https://github.com/EasyIME/PIME/releases/download/v$TargetVersion/$setupName"

  if (-not (Test-Path -LiteralPath $setupPath -PathType Leaf)) {
    Write-Host "Downloading prebuilt PIME: $url" -ForegroundColor Cyan
    Invoke-WebRequest -Uri $url -OutFile $setupPath
  } else {
    Write-Host "Using cached PIME installer: $setupPath" -ForegroundColor Yellow
  }

  Reset-Dir $extractDir
  $extractArgs = @('x', '-y', "-o$extractDir", $setupPath)
  $null = & $sevenZip @extractArgs
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to extract PIME setup (7z exit code: $LASTEXITCODE)"
  }

  return (Resolve-Path -LiteralPath $extractDir).Path
}

function Write-ArtifactsManifest([string]$TargetDir, [string]$BuildVersion) {
  $manifestPath = Join-Path $TargetDir 'artifacts-manifest.txt'
  $items = Get-ChildItem -LiteralPath $TargetDir -Filter '*.exe' | Sort-Object Name

  $lines = @()
  $lines += '# McBopomofo artifacts manifest'
  $lines += "generated_at_utc=$((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))"
  $lines += "version=$BuildVersion"
  $lines += ''
  $lines += '# format: type<TAB>file<TAB>bytes<TAB>sha256'

  foreach ($item in $items) {
    $type = if ($item.Name -match 'Setup-Full-') {
      'full'
    } elseif ($item.Name -match 'Setup-Lite-') {
      'lite'
    } else {
      'unknown'
    }

    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $item.FullName).Hash.ToLower()
    $lines += "$type`t$($item.Name)`t$($item.Length)`t$hash"
  }

  Set-Content -LiteralPath $manifestPath -Value $lines -Encoding UTF8
  return $manifestPath
}

function Invoke-MakensisBuild([string]$PackageKind, [string[]]$Arguments) {
  & $Makensis @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "makensis failed for $PackageKind package (exit $LASTEXITCODE)"
  }
}

function Test-PimeRuntimeComplete([string]$DirPath) {
  if (-not (Test-Path -LiteralPath $DirPath -PathType Container)) {
    return $false
  }
  foreach ($f in @(
    'PIMELauncher.exe',
    'backends.json',
    'x86\PIMETextService.dll',
    'x64\PIMETextService.dll',
    'node\node.exe',
    'python\python3\pythonw.exe'
  )) {
    if (-not (Test-Path -LiteralPath (Join-Path $DirPath $f) -PathType Leaf)) {
      return $false
    }
  }
  return $true
}

Write-Host '=== Validate tools ===' -ForegroundColor Cyan
Assert-File $NsisScript

if ($FullOnly -and $LiteOnly) {
  throw 'Use either -FullOnly or -LiteOnly, not both.'
}

if ($FullOnly) {
  throw 'Full installer is reserved for the future bundle that includes other PIME input methods. It is not implemented yet. Use the default Lite build for now.'
}

$BuildFull = $false
$BuildLite = $true

$GitExe = Resolve-RequiredTool 'git' @('git.exe', 'git') @(
  "$env:ProgramFiles\Git\cmd\git.exe",
  "$env:ProgramFiles\Git\bin\git.exe",
  "${env:ProgramFiles(x86)}\Git\cmd\git.exe"
)
$NodeExe = Resolve-RequiredTool 'node' @('node.exe', 'node') @(
  "$env:ProgramFiles\nodejs\node.exe",
  "${env:ProgramFiles(x86)}\nodejs\node.exe"
)
$NpmCmd = Resolve-RequiredTool 'npm' @('npm.cmd', 'npm') @(
  "$env:ProgramFiles\nodejs\npm.cmd",
  "${env:ProgramFiles(x86)}\nodejs\npm.cmd"
)
$Makensis = Resolve-RequiredTool 'makensis' @('makensis.exe', 'makensis') @(
  "${env:ProgramFiles(x86)}\NSIS\makensis.exe",
  "$env:ProgramFiles\NSIS\makensis.exe"
)

Write-Host '=== Prepare source ===' -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $WorkspaceDir | Out-Null

if (-not (Test-Path -LiteralPath $McBopomofoWebDir)) {
  if ($SkipClone) {
    throw "McBopomofoWebDir not found and -SkipClone is set: $McBopomofoWebDir"
  }
  Invoke-External $GitExe @('clone', 'https://github.com/openvanilla/McBopomofoWeb.git', $McBopomofoWebDir)
  if ($ExpectedMcBopomofoWebCommit) {
    Push-Location $McBopomofoWebDir
    try {
      Invoke-External $GitExe @('checkout', $ExpectedMcBopomofoWebCommit)
    } finally {
      Pop-Location
    }
  }
} else {
  if (-not (Test-Path -LiteralPath (Join-Path $McBopomofoWebDir '.git'))) {
    throw "McBopomofoWebDir is not a git checkout: $McBopomofoWebDir"
  }
  Push-Location $McBopomofoWebDir
  try {
    $currentCommit = Invoke-ExternalCapture $GitExe @('rev-parse', 'HEAD')
    if ($ExpectedMcBopomofoWebCommit -and $currentCommit -ne $ExpectedMcBopomofoWebCommit) {
      throw "McBopomofoWebDir HEAD $currentCommit does not match expected exact-build commit $ExpectedMcBopomofoWebCommit."
    }
  } finally {
    Pop-Location
  }
}

Apply-McBopomofoWebOverlay -OverlayDir $McBopomofoWebOverlayDir -TargetDir $McBopomofoWebDir

Write-Host '=== Build McBopomofoWeb (pime) ===' -ForegroundColor Cyan
Push-Location $McBopomofoWebDir
try {
  $lockFilePath = Join-Path $McBopomofoWebDir 'package-lock.json'
  if (Test-Path -LiteralPath $lockFilePath -PathType Leaf) {
    Write-Host 'Attempting npm ci...' -ForegroundColor DarkCyan
    $npmCiExitCode = Invoke-ExternalWithExitCode $NpmCmd @('ci')
    if ($npmCiExitCode -ne 0) {
      Write-Warning "npm ci failed (exit $npmCiExitCode). Falling back to npm install to refresh package-lock.json."
      Invoke-External $NpmCmd @('install')
    }
  } else {
    Invoke-External $NpmCmd @('install')
  }
  Invoke-External $NpmCmd @('run', 'build:pime')
} finally {
  Pop-Location
}

$McOutputDir = Join-Path $McBopomofoWebDir 'output\pime'
Assert-Dir $McOutputDir
Assert-File (Join-Path $McOutputDir 'ime.json')
Assert-File (Join-Path $McOutputDir 'server.js')

Write-Host '=== Stage payload ===' -ForegroundColor Cyan
if (-not $PimeSourceDir) {
  if (Test-PimeRuntimeComplete -DirPath $WorkspacePimeExtractedDir) {
    $PimeSourceDir = $WorkspacePimeExtractedDir
  } else {
    $PimeSourceDir = $InstalledPimeDir
  }
}

if (-not (Test-PimeRuntimeComplete -DirPath $PimeSourceDir)) {
  Write-Warning "PIME runtime missing/incomplete at: $PimeSourceDir"
  Write-Host "Auto-fetching prebuilt PIME v$PimeVersion..." -ForegroundColor Cyan
  $PimeSourceDir = Prepare-PimeRuntime -Workspace $WorkspaceDir -TargetVersion $PimeVersion
}

Assert-Dir $PimeSourceDir
Assert-File (Join-Path $PimeSourceDir 'PIMELauncher.exe')
Assert-File (Join-Path $PimeSourceDir 'backends.json')
Assert-File (Join-Path $PimeSourceDir 'x86\PIMETextService.dll')
Assert-File (Join-Path $PimeSourceDir 'x64\PIMETextService.dll')
Assert-File (Join-Path $PimeSourceDir 'node\node.exe')
Assert-File (Join-Path $PimeSourceDir 'python\python3\pythonw.exe')

Reset-Dir $StageDir
Reset-Dir $CoreStageDir
Reset-Dir $HelperStageDir
New-Item -ItemType Directory -Force -Path $CoreLicenseDir | Out-Null
New-Item -ItemType Directory -Force -Path $CoreFontDir | Out-Null

Copy-Item -LiteralPath (Join-Path $PimeSourceDir 'PIMELauncher.exe') -Destination (Join-Path $CoreStageDir 'PIMELauncher.exe') -Force
Copy-Item -LiteralPath (Join-Path $PimeSourceDir 'backends.json') -Destination (Join-Path $CoreStageDir 'backends.json') -Force
Copy-Item -LiteralPath (Join-Path $PimeSourceDir 'x86') -Destination (Join-Path $CoreStageDir 'x86') -Recurse -Force
Copy-IfExists (Join-Path $PimeSourceDir 'x64') (Join-Path $CoreStageDir 'x64')
Copy-Item -LiteralPath (Join-Path $PimeSourceDir 'node') -Destination (Join-Path $CoreStageDir 'node') -Recurse -Force
Copy-IfExists (Join-Path $PimeSourceDir 'python') (Join-Path $CoreStageDir 'python')

# Keep only McBopomofo in node/input_methods
$NodeInputMethodsDir = Join-Path $CoreStageDir 'node\input_methods'
if (Test-Path -LiteralPath $NodeInputMethodsDir) {
  Remove-Item -LiteralPath $NodeInputMethodsDir -Recurse -Force
}
New-Item -ItemType Directory -Path $NodeInputMethodsDir | Out-Null
Copy-Item -LiteralPath $McOutputDir -Destination (Join-Path $NodeInputMethodsDir 'McBopomofo') -Recurse -Force

# Restrict launcher to node backend only (avoid loading other IMEs)
Write-ExactNodeBackendsJson -Path (Join-Path $CoreStageDir 'backends.json')

# Exact Full payload includes a default user config copied on first install.
$DefaultConfigStaged = $true
$configCandidate = $DefaultConfigPath
if (-not $configCandidate) {
  $projectConfig = Join-Path $ProjectRoot 'config.json'
  if (Test-Path -LiteralPath $projectConfig -PathType Leaf) {
    $configCandidate = $projectConfig
  } else {
    $mcbConfig = Join-Path $McOutputDir 'config.json'
    if (Test-Path -LiteralPath $mcbConfig -PathType Leaf) {
      $configCandidate = $mcbConfig
    }
  }
}

if (-not $configCandidate) {
  throw 'Exact build requires a default config.json. Provide -DefaultConfigPath or keep project config.json.'
}
Assert-File $configCandidate
$defaultsDir = Join-Path $CoreStageDir 'defaults\mcbopomofo'
New-Item -ItemType Directory -Force -Path $defaultsDir | Out-Null
Copy-Item -LiteralPath $configCandidate -Destination (Join-Path $defaultsDir 'config.json') -Force

$fontInstallHelperSource = Join-Path $ProjectRoot 'installer\helpers\install-fonts.ps1'
$fontUninstallHelperSource = Join-Path $ProjectRoot 'installer\helpers\uninstall-fonts.ps1'
$configFlagHelperSource = Join-Path $ProjectRoot 'installer\helpers\set-config-flag.ps1'
Assert-File $fontInstallHelperSource
Assert-File $fontUninstallHelperSource
Assert-File $configFlagHelperSource
Copy-Item -LiteralPath $fontInstallHelperSource -Destination (Join-Path $HelperStageDir 'install-fonts.ps1') -Force
Copy-Item -LiteralPath $fontUninstallHelperSource -Destination (Join-Path $HelperStageDir 'uninstall-fonts.ps1') -Force
Copy-Item -LiteralPath $configFlagHelperSource -Destination (Join-Path $HelperStageDir 'set-config-flag.ps1') -Force

Stage-ThirdPartyLicenses -StageLicenseDir $CoreLicenseDir
Prepare-BpmfvsFonts -StageFontsDir $CoreFontDir -StageLicenseDir $CoreLicenseDir

# Build output folder
New-Item -ItemType Directory -Force -Path $DistDir | Out-Null
Archive-DistArtifacts -TargetDir $DistDir

if ($BuildFull) {
  Write-Host '=== Build Full installer ===' -ForegroundColor Cyan

  $VCRedistX64Path = Resolve-VCRedistBinary -Arch 'x64' -ExplicitPath $VCRedistX64Path
  $VCRedistX86Path = Resolve-VCRedistBinary -Arch 'x86' -ExplicitPath $VCRedistX86Path
  Assert-File $VCRedistX64Path
  Assert-File $VCRedistX86Path
  Write-Host "Using VC redist x64: $VCRedistX64Path" -ForegroundColor Yellow
  Write-Host "Using VC redist x86: $VCRedistX86Path" -ForegroundColor Yellow

  Reset-Dir $VCRedistStageDir
  Copy-Item -LiteralPath $VCRedistX64Path -Destination (Join-Path $VCRedistStageDir 'vc_redist.x64.exe') -Force
  Copy-Item -LiteralPath $VCRedistX86Path -Destination (Join-Path $VCRedistStageDir 'vc_redist.x86.exe') -Force

  $fullArgs = @(
    "-DVERSION=$Version",
    "-DOUTDIR=$DistDir",
    "-DINSTALLER_NAME=McBopomofo-PIME-Setup-Full-$Version.exe",
    "-DSTAGING_DIR=$StageDir",
    '-DINCLUDE_VCREDIST=1',
    '-DVCREDIST_X86_PRESENT=1'
  )

  if ($DefaultConfigStaged) {
    $fullArgs += '-DDEFAULT_CONFIG_PRESENT=1'
  }
  $fullArgs += $NsisScript
  Invoke-MakensisBuild -PackageKind 'Full' -Arguments $fullArgs
}

if ($BuildLite) {
  Write-Host '=== Build Lite installer ===' -ForegroundColor Cyan

  if (Test-Path -LiteralPath $VCRedistStageDir) {
    Remove-Item -LiteralPath $VCRedistStageDir -Recurse -Force
  }

  $liteArgs = @(
    "-DVERSION=$Version",
    "-DOUTDIR=$DistDir",
    "-DINSTALLER_NAME=McBopomofo-PIME-Setup-Lite-$Version.exe",
    "-DSTAGING_DIR=$StageDir",
    '-DINCLUDE_VCREDIST=0'
  )

  if ($DefaultConfigStaged) {
    $liteArgs += '-DDEFAULT_CONFIG_PRESENT=1'
  }
  $liteArgs += $NsisScript
  Invoke-MakensisBuild -PackageKind 'Lite' -Arguments $liteArgs
}

Write-Host ''
Write-Host '=== Build complete ===' -ForegroundColor Green
$exeItems = Get-ChildItem -LiteralPath $DistDir -Filter '*.exe' | Sort-Object Name
$exeItems | ForEach-Object {
  Write-Host " - $($_.FullName)"
}
$manifestPath = Write-ArtifactsManifest -TargetDir $DistDir -BuildVersion $Version
Write-Host " - $manifestPath"
