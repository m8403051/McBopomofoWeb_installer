[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$fontFiles = @(
  'BpmfZihiKaiStd-Regular.ttf',
  'BpmfZihiSans-Bold.ttf',
  'BpmfZihiSans-ExtraLight.ttf',
  'BpmfZihiSans-Heavy.ttf',
  'BpmfZihiSans-Light.ttf',
  'BpmfZihiSans-Medium.ttf',
  'BpmfZihiSans-Regular.ttf',
  'BpmfZihiSerif-Bold.ttf',
  'BpmfZihiSerif-ExtraLight.ttf',
  'BpmfZihiSerif-Heavy.ttf',
  'BpmfZihiSerif-Light.ttf',
  'BpmfZihiSerif-Medium.ttf',
  'BpmfZihiSerif-Regular.ttf',
  'BpmfZihiSerif-SemiBold.ttf',
  'BpmfZihiBox-R.ttf',
  'BpmfZihiOnly-R.ttf'
)

$fontsDir = Join-Path $env:WINDIR 'Fonts'
$fontsRegKey = 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class Win32FontNative {
  [DllImport("gdi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
  public static extern bool RemoveFontResourceEx(string name, uint fl, IntPtr pdv);

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

$regProps = Get-ItemProperty -Path $fontsRegKey

foreach ($fontFile in $fontFiles) {
  $targetPath = Join-Path $fontsDir $fontFile
  if (Test-Path -LiteralPath $targetPath -PathType Leaf) {
    while ([Win32FontNative]::RemoveFontResourceEx($targetPath, 0, [IntPtr]::Zero)) {
    }
    Remove-Item -LiteralPath $targetPath -Force -ErrorAction SilentlyContinue
  }

  foreach ($prop in $regProps.PSObject.Properties) {
    if ($prop.MemberType -ne 'NoteProperty') {
      continue
    }
    if ([string]$prop.Value -eq $fontFile) {
      Remove-ItemProperty -Path $fontsRegKey -Name $prop.Name -Force -ErrorAction SilentlyContinue
    }
  }
}

$result = [UIntPtr]::Zero
[void][Win32FontNative]::SendMessageTimeout([IntPtr]0xffff, 0x001D, [UIntPtr]::Zero, $null, 0x0002, 5000, [ref]$result)
