$urls = @(
  'http://localhost:8765/',
  'http://localhost:8765/index.html',
  'http://localhost:8765/style.css',
  'http://localhost:8765/assets/img/hero-gym.png',
  'http://localhost:8765/assets/img/interior.png',
  'http://localhost:8765/assets/img/equipment.png',
  'http://localhost:8765/assets/img/studio-02.png',
  'http://localhost:8765/assets/img/trainer-profile.png'
)

foreach ($u in $urls) {
  try {
    $r = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 5
    Write-Output "$($r.StatusCode) $($r.Headers['Content-Type']) $($r.RawContentLength) $u"
  } catch {
    Write-Output "FAIL $u $($_.Exception.Message)"
  }
}
