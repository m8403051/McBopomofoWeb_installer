param(
  [Parameter(Mandatory = $true)]
  [string]$ConfigPath,

  [Parameter(Mandatory = $true)]
  [string]$Key,

  [Parameter(Mandatory = $true)]
  [string]$Value
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
  throw "Config file not found: $ConfigPath"
}

$content = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.Encoding]::UTF8)
$content = $content -replace "^\uFEFF", ""
$data = ConvertFrom-Json -InputObject $content

if ($null -eq $data) {
  $data = [pscustomobject]@{}
}

$boolValue = [System.Convert]::ToBoolean($Value)

$existing = $data.PSObject.Properties[$Key]
if ($existing) {
  $existing.Value = $boolValue
} else {
  $data | Add-Member -NotePropertyName $Key -NotePropertyValue $boolValue
}

$json = ConvertTo-Json -InputObject $data -Depth 16
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($ConfigPath, $json + [Environment]::NewLine, $utf8NoBom)
