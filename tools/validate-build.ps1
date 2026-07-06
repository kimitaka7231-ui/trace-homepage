$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

$requiredFiles = @(
  'index.html',
  'style.css',
  'script.js',
  'CNAME',
  'assets/img/hero-gym.png',
  'assets/icons/icon-line.svg'
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $root $file
  if (-not (Test-Path $path)) {
    throw "Missing required file: $file"
  }
}

$html = Get-Content -Path (Join-Path $root 'index.html') -Raw -Encoding UTF8
$checks = @(
  'id="faq"',
  'class="faq-section"',
  'faq__footer',
  'faq__cta',
  'faq-item__icon',
  'href="#faq"'
)

foreach ($pattern in $checks) {
  if ($html -notmatch [regex]::Escape($pattern)) {
    throw "index.html validation failed: $pattern"
  }
}

if ($html -match 'class="faq-item__q"') {
  throw 'index.html still contains old FAQ markup'
}

Write-Output 'BUILD OK'
