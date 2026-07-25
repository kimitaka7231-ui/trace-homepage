$base = 'http://localhost:8765'
$paths = @(
  '/','/style.css','/script.js',
  '/assets/img/hero-gym.webp','/assets/img/interior.webp','/assets/img/equipment.webp',
  '/assets/img/studio-02.webp','/assets/img/trainer-profile.webp','/assets/img/storefront.webp',
  '/assets/img/result-01.png','/assets/img/result-02.png','/assets/img/price-plan.png',
  '/assets/img/logo.svg','/assets/icons/icon-line.svg','/assets/img/hero-gym.png'
)
foreach ($p in $paths) {
  try {
    $r = Invoke-WebRequest -Uri ($base + $p) -UseBasicParsing -TimeoutSec 5
    Write-Output "$($r.StatusCode) $p ($($r.RawContentLength) bytes)"
  } catch {
    Write-Output "FAIL $p"
  }
}
