$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$srcDir = 'C:\Users\kimit\.cursor\projects\c-Users-kimit-OneDrive-TRACE\assets'
$outDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'assets\img'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$map = @(
    @{ Match = '1cf16c68-09bb-4381-a4b3-cdfc8db4a1d2'; Out = 'hero-gym.png' },
    @{ Match = '9a327042-9897-4342-931f-f340b089b57b'; Out = 'interior.png' },
    @{ Match = '55dcc5cc-965e-480f-9f82-51b93ae60c8f'; Out = 'equipment.png' },
    @{ Match = 'ed464bc9-da01-4295-9c57-dcf3209c9fb7'; Out = 'studio-02.png' },
    @{ Match = '3010403c-1ce1-4469-b3ea-a35d1083616f'; Out = 'trainer-profile.png' }
)

foreach ($item in $map) {
    $file = Get-ChildItem $srcDir -Filter "*.png" | Where-Object { $_.Name -match [regex]::Escape($item.Match) } | Select-Object -First 1
    if (-not $file) { throw "Missing source for $($item.Out)" }
    $dest = Join-Path $outDir $item.Out
    Copy-Item -LiteralPath $file.FullName -Destination $dest -Force
    $img = [System.Drawing.Image]::FromFile($dest)
    Write-Output "$($item.Out) $($img.Width)x$($img.Height) <- $($file.Name)"
    $img.Dispose()
}
