# 写真ファイルの中身と HTML 参照を照合
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$html = [IO.File]::ReadAllText((Join-Path $root 'index.html'), [Text.Encoding]::UTF8)

$expected = [ordered]@{
  'trainer-profile.webp' = 'images_15-6c7479f6'
  'storefront.webp'      = '793792f0'
  'equipment.webp'       = 'b8bcd262'
  'studio-02.webp'       = '33cf4818'
}

Write-Host '=== HTML src ==='
foreach ($name in $expected.Keys) {
  if ($html -match [regex]::Escape($name)) { Write-Host "OK  index.html -> $name" }
  else { throw "index.html missing $name" }
}

Write-Host '=== File presence ==='
foreach ($name in $expected.Keys) {
  foreach ($ext in 'webp','png') {
    $path = Join-Path $root "assets/img/$($name -replace '\.webp$','').$ext"
    if (-not (Test-Path $path)) { throw "Missing $path" }
    $kb = [math]::Round((Get-Item $path).Length / 1KB, 1)
    Write-Host "OK  $ext $kb KB"
  }
}

Write-Host '=== PrepareTracePhotos mapping ==='
$script = Get-Content (Join-Path $PSScriptRoot 'PrepareTracePhotos.ps1') -Raw
foreach ($pair in $expected.GetEnumerator()) {
  if ($script -notmatch [regex]::Escape($pair.Value)) { throw "PrepareTracePhotos.ps1 missing token $($pair.Value) for $($pair.Key)" }
  Write-Host "OK  $($pair.Key) <- $($pair.Value)"
}

Write-Host 'PHOTO VERIFY OK'
