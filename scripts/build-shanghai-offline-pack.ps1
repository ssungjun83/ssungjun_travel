param(
    [string]$SourcePath = "shanghai/index.html",
    [string]$OutputPath = "shanghai/shanghai_offline_pack.html"
)

$ErrorActionPreference = "Stop"

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sourceFullPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $SourcePath))
$outputFullPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutputPath))
$sourceDir = Split-Path -Parent $sourceFullPath
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Read-Utf8Text {
    param([string]$Path)
    return [System.IO.File]::ReadAllText($Path, $utf8NoBom)
}

function Get-AssetText {
    param([string]$RelativePath)
    $assetPath = [System.IO.Path]::GetFullPath((Join-Path $sourceDir $RelativePath))
    return Read-Utf8Text -Path $assetPath
}

function Get-AssetDataUrl {
    param(
        [string]$RelativePath,
        [string]$MimeType
    )

    $assetPath = [System.IO.Path]::GetFullPath((Join-Path $sourceDir $RelativePath))
    $bytes = [System.IO.File]::ReadAllBytes($assetPath)
    $base64 = [System.Convert]::ToBase64String($bytes)
    return "data:$MimeType;base64,$base64"
}

function Escape-InlineScript {
    param([string]$Text)
    return [System.Text.RegularExpressions.Regex]::Replace($Text, "</script>", "<\/script>", "IgnoreCase")
}

function Replace-Checked {
    param(
        [string]$Content,
        [string]$OldValue,
        [string]$NewValue
    )

    if (-not $Content.Contains($OldValue)) {
        throw "Expected text not found: $OldValue"
    }

    return $Content.Replace($OldValue, $NewValue)
}

$html = Read-Utf8Text -Path $sourceFullPath
$tailwindJs = Get-AssetText -RelativePath "./assets/vendor/tailwind/tailwind-playcdn.js"
$chartJs = Get-AssetText -RelativePath "./assets/vendor/chart/chart.umd.js"
$leafletCss = Get-AssetText -RelativePath "./assets/vendor/leaflet/leaflet.css"
$leafletJs = Get-AssetText -RelativePath "./assets/vendor/leaflet/leaflet.js"
$xlsxJs = Get-AssetText -RelativePath "./assets/vendor/xlsx/xlsx.full.min.js"
$mapImageUrl = Get-AssetDataUrl -RelativePath "./assets/images/shanghai-osm-static.png" -MimeType "image/png"
$markerShadowUrl = Get-AssetDataUrl -RelativePath "./assets/vendor/leaflet/marker-shadow.png" -MimeType "image/png"

$html = Replace-Checked -Content $html -OldValue '<html lang="ko">' -NewValue '<html lang="ko" data-offline-pack="true">'
$html = Replace-Checked -Content $html -OldValue '<script src="./assets/vendor/tailwind/tailwind-playcdn.js"></script>' -NewValue ("<script>{0}</script>" -f (Escape-InlineScript -Text $tailwindJs))
$html = Replace-Checked -Content $html -OldValue '<script src="./assets/vendor/chart/chart.umd.js"></script>' -NewValue ("<script>{0}</script>" -f (Escape-InlineScript -Text $chartJs))
$html = Replace-Checked -Content $html -OldValue '<link rel="stylesheet" href="./assets/vendor/leaflet/leaflet.css">' -NewValue ("<style>{0}</style>" -f $leafletCss)
$html = Replace-Checked -Content $html -OldValue '<script src="./assets/vendor/leaflet/leaflet.js"></script>' -NewValue ("<script>{0}</script>" -f (Escape-InlineScript -Text $leafletJs))
$html = Replace-Checked -Content $html -OldValue '<script src="./assets/vendor/xlsx/xlsx.full.min.js"></script>' -NewValue ("<script>{0}</script>" -f (Escape-InlineScript -Text $xlsxJs))
$html = $html.Replace('./assets/images/shanghai-osm-static.png', $mapImageUrl)
$html = $html.Replace('./assets/vendor/leaflet/marker-shadow.png', $markerShadowUrl)

$outputDir = Split-Path -Parent $outputFullPath
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

[System.IO.File]::WriteAllText($outputFullPath, $html, $utf8NoBom)

$fileInfo = Get-Item $outputFullPath
Write-Host ("Built offline pack: {0} ({1} bytes)" -f $fileInfo.FullName, $fileInfo.Length)
