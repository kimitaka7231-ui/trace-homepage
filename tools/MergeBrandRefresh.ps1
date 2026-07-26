$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$stylePath = Join-Path $root 'style.css'
$brPath = Join-Path $root 'preview\brand-refresh.css'

$style = [IO.File]::ReadAllText($stylePath)
if ($style -match '(?s)(/\* =+\s*\r?\n   Brand Refresh)[\s\S]*$') {
    $style = $style.Substring(0, $style.IndexOf($Matches[1]))
}

$brRaw = [IO.File]::ReadAllText($brPath)
$brRaw = $brRaw -replace '(?s)/\* --- Preview banner --- \*/.*?(?=/\* --- Typography)', ''
$brRaw = $brRaw -replace '(?s)/\* --- Compare toggle --- \*/.*\z', ''
$brRaw = $brRaw -replace ':root \{[\s\S]*?\}\s*', ''
$brRaw = $brRaw -replace 'body\.brand-refresh ', ''
$brRaw = $brRaw -replace 'body\.brand-refresh\s*\{', 'body.page-top {'
$brRaw = $brRaw -replace '(?m)^\s*padding-top:\s*2rem;\s*\r?\n', ''
$brRaw = $brRaw -replace '(?m)^\s*top:\s*2rem;\s*\r?\n', ''

$rootPatch = @'
  --space-lg: 3rem;
  --space-xl: 5rem;
  --space-2xl: 7rem;
  --space-3xl: 10rem;
  --section-pad: clamp(5rem, 10vw, 8rem);
  --container-padding: clamp(1.375rem, 4.5vw, 2rem);
  --radius-photo: 8px;
  --radius-card: 12px;
  --radius-btn: 16px;
  --shadow-photo:
    0 4px 20px rgba(0, 0, 0, 0.22),
    0 0 0 1px rgba(255, 255, 255, 0.05);
  --shadow-card: 0 4px 24px rgba(0, 0, 0, 0.2);
  --shadow-card-hover: 0 8px 32px rgba(0, 0, 0, 0.26);
  --color-text-muted: rgba(245, 245, 245, 0.55);
  --color-border: rgba(255, 255, 255, 0.08);
  --color-border-strong: rgba(255, 255, 255, 0.16);
'@

$style = $style -replace '--space-lg: 2\.5rem;', '--space-lg: 3rem;'
$style = $style -replace '--space-xl: 4rem;', '--space-xl: 5rem;'
$style = $style -replace '--space-2xl: 6rem;', '--space-2xl: 7rem;'
$style = $style -replace '--space-3xl: 8rem;', '--space-3xl: 10rem;'
$style = $style -replace '--section-pad: clamp\(4rem, 7\.5vw, 6\.75rem\);', '--section-pad: clamp(5rem, 10vw, 8rem);'
$style = $style -replace '--container-padding: 1\.375rem;', '--container-padding: clamp(1.375rem, 4.5vw, 2rem);'
$style = $style -replace '--radius-photo: 14px;', '--radius-photo: 8px;'
$style = $style -replace '--radius-card: 14px;', '--radius-card: 12px;'

$merged = $style.TrimEnd() + "`r`n`r`n/* ========================================`r`n   Brand Refresh v2 — Apple × NIKE`r`n   ======================================== */`r`n`r`n" + $brRaw.Trim()
[IO.File]::WriteAllText($stylePath, $merged)
Write-Output 'Merged brand-refresh into style.css'
