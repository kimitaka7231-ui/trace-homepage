$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

$core = @('index.html', 'style.css', 'script.js', 'package.json', 'start-server.ps1')
foreach ($f in $core) {
    $p = Join-Path $root $f
    if (-not (Test-Path $p)) { throw "Missing: $f" }
    $item = Get-Item $p
    Write-Output "OK $f $($item.Length)"
}

$imgs = @(
    'hero-gym.png', 'interior.png', 'equipment.png', 'studio-02.png',
    'trainer-profile.png', 'price-plan.png', 'storefront.png',
    'result-01.png', 'result-02.png'
)
foreach ($img in $imgs) {
    $p = Join-Path $root "assets\img\$img"
    if (-not (Test-Path $p)) { Write-Output "WARN missing $img" }
    else { Write-Output "OK $img $((Get-Item $p).Length)" }
}

$zip = Join-Path $root 'TRACE-homepage-backup.zip'
if (Test-Path $zip) { Remove-Item $zip -Force }

Compress-Archive -Path @(
    (Join-Path $root 'index.html'),
    (Join-Path $root 'style.css'),
    (Join-Path $root 'script.js'),
    (Join-Path $root 'package.json'),
    (Join-Path $root 'start-server.ps1'),
    (Join-Path $root 'assets')
) -DestinationPath $zip -Force

$z = Get-Item $zip
Write-Output "ZIP $($z.Length)"

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($zip)
$required = @('index.html', 'style.css', 'script.js')
foreach ($name in $required) {
    $found = $false
    foreach ($entry in $archive.Entries) {
        if ($entry.FullName -eq $name) { $found = $true; break }
    }
    if (-not $found) { throw "ZIP missing $name" }
}
$archive.Dispose()
Write-Output 'ALL_SAVED'
