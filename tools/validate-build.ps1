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

$htmlPath = Join-Path $root 'index.html'
$html = [System.IO.File]::ReadAllText($htmlPath, [System.Text.Encoding]::UTF8)

$checks = @(
  'id="faq"',
  'class="faq-section"',
  'faq__footer',
  'faq__cta',
  'faq-item__icon',
  'href="#faq"',
  'style.css?v=20260708',
  'script.js?v=20260708',
  'id="faq-q9"',
  'id="faq-a9"'
)

foreach ($pattern in $checks) {
  if ($html -notmatch [regex]::Escape($pattern)) {
    throw "index.html validation failed: $pattern"
  }
}

$faqCount = ([regex]::Matches($html, 'class="faq-item reveal"')).Count
if ($faqCount -ne 9) {
  throw "FAQ item count must be 9, found $faqCount"
}

$oldMarkers = @(
  'faq-q10',
  'class="faq-item__q"'
)

foreach ($marker in $oldMarkers) {
  if ($html -match [regex]::Escape($marker)) {
    throw "index.html still contains old FAQ marker: $marker"
  }
}

Write-Output 'BUILD OK'
