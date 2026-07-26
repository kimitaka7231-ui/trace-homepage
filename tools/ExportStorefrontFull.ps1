$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$src = Get-ChildItem 'C:\Users\kimit\.cursor\projects\c-Users-kimit-OneDrive-TRACE\assets' -Filter '*793792f0*' | Select-Object -First 1
if (-not $src) { throw 'storefront source not found' }

$outDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'assets\img'
$png = Join-Path $outDir 'storefront-full.png'
$webp = Join-Path $outDir 'storefront-full.webp'
$cwebp = Join-Path $PSScriptRoot 'libwebp\libwebp-1.4.0-windows-x64\bin\cwebp.exe'

$img = [System.Drawing.Image]::FromFile($src.FullName)
$bmp = New-Object System.Drawing.Bitmap 1024, 768
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
$g.DrawImage($img, 0, 0, 1024, 768)
$g.Dispose()
$img.Dispose()
$bmp.Save($png, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

& $cwebp -quiet -q 88 -m 6 -mt $png -o $webp
Write-Host "storefront-full.webp <- $($src.Name)"
Write-Host "  -> 1024x768 $([math]::Round((Get-Item $webp).Length/1KB,1))KB"
