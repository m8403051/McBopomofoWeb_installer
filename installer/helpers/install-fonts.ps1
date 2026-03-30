[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$SourceDir
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) {
  throw "Font source directory not found: $SourceDir"
}

$fontFiles = Get-ChildItem -LiteralPath $SourceDir -Filter '*.ttf' -File | Sort-Object Name
if ($fontFiles.Count -eq 0) {
  throw "No .ttf files found in: $SourceDir"
}

$fontsDir = Join-Path $env:WINDIR 'Fonts'
$fontsRegKey = 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class Win32FontNative {
  [DllImport("gdi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
  public static extern int AddFontResourceEx(string lpszFilename, uint fl, IntPtr pdv);

  [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
  public static extern IntPtr SendMessageTimeout(
    IntPtr hWnd,
    uint Msg,
    UIntPtr wParam,
    string lParam,
    uint fuFlags,
    uint uTimeout,
    out UIntPtr lpdwResult
  );
}
'@

foreach ($font in $fontFiles) {
  $targetPath = Join-Path $fontsDir $font.Name
  if (-not (Test-Path -LiteralPath $targetPath -PathType Leaf)) {
    Copy-Item -LiteralPath $font.FullName -Destination $targetPath -Force
  }

  $valueName = '{0} (TrueType)' -f [System.IO.Path]::GetFileNameWithoutExtension($font.Name)
  New-ItemProperty -Path $fontsRegKey -Name $valueName -Value $font.Name -PropertyType String -Force | Out-Null
  [void][Win32FontNative]::AddFontResourceEx($targetPath, 0, [IntPtr]::Zero)
}

$result = [UIntPtr]::Zero
[void][Win32FontNative]::SendMessageTimeout([IntPtr]0xffff, 0x001D, [UIntPtr]::Zero, $null, 0x0002, 5000, [ref]$result)
