$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$cs = Join-Path $PSScriptRoot 'NormalizePhotoTone.cs'
$exe = Join-Path $PSScriptRoot 'NormalizePhotoTone.exe'
$csc = "${env:WINDIR}\Microsoft.NET\Framework64\v4.0.30319\csc.exe"

& $csc /nologo /optimize+ /unsafe /out:$exe $cs

$targets = @(
    'hero-gym.png', 'interior.png', 'equipment.png',
    'studio-02.png', 'trainer-profile.png', 'storefront.png'
)

foreach ($name in $targets) {
    $file = Join-Path $root "assets\img\$name"
    if (Test-Path $file) {
        & $exe $file
    }
}
