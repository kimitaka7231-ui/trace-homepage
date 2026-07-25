# Combine hero candidate screenshots (PC / tablet / SP)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

function Combine-HeroCandidate([string]$title, [string[]]$paths, [int[]]$targetWidths, [string[]]$labelArr, [string]$outPath) {
    $bitmaps = @()
    for ($i = 0; $i -lt $paths.Count; $i++) {
        $raw = [System.Drawing.Bitmap]::FromFile($paths[$i])
        $tw = $targetWidths[$i]
        $th = [int][Math]::Round($raw.Height * ($tw / [double]$raw.Width))
        $dst = New-Object System.Drawing.Bitmap $tw, $th
        $g = [System.Drawing.Graphics]::FromImage($dst)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.DrawImage($raw, 0, 0, $tw, $th)
        $g.Dispose(); $raw.Dispose()
        $bitmaps += [PSCustomObject]@{ Bitmap = $dst; Label = $labelArr[$i]; H = $th; W = $tw }
    }

    $pad = 24
    $titleH = 56
    $labelH = 28
    $maxW = ($bitmaps | ForEach-Object { $_.W } | Measure-Object -Maximum).Maximum
    $w = [int]($maxW + $pad * 2)
    $bodyH = 0
    foreach ($b in $bitmaps) { $bodyH += $labelH + $b.H + $pad }
    $h = [int]($titleH + $bodyH + $pad)

    $canvas = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($canvas)
    $g.Clear([System.Drawing.Color]::FromArgb(10, 10, 10))
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

    $fontTitle = New-Object System.Drawing.Font("Segoe UI", 15, [System.Drawing.FontStyle]::Bold)
    $fontLabel = New-Object System.Drawing.Font("Segoe UI", 10)
    $white = [System.Drawing.Brushes]::White
    $gray = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(170, 170, 170))

    $y = $pad
    $g.DrawString($title, $fontTitle, $white, $pad, $y)
    $y += $titleH

    foreach ($item in $bitmaps) {
        $g.DrawString($item.Label, $fontLabel, $gray, $pad, $y)
        $y += $labelH
        $g.DrawImage($item.Bitmap, $pad, $y)
        $y += $item.H + $pad
    }

    $dir = Split-Path $outPath -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $canvas.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)

    $g.Dispose(); $canvas.Dispose(); $fontTitle.Dispose(); $fontLabel.Dispose(); $gray.Dispose()
    foreach ($item in $bitmaps) { $item.Bitmap.Dispose() }
    Write-Host "Saved $outPath ($w x $h)"
}

$tmp = Join-Path $env:LOCALAPPDATA "Temp\cursor\screenshots\preview"
$dst = Join-Path (Split-Path $PSScriptRoot -Parent) "preview"
$labels = @("PC (1280px)", "Tablet (834px)", "Smartphone (390px)")
$widths = @(1280, 834, 390)

$items = @(
    @{ Title = "A. Counseling - hero candidate (image swap only)"; Key = "A"; Out = "hero-candidate-A-counseling.png" },
    @{ Title = "B. Bench press - hero candidate (image swap only)"; Key = "B"; Out = "hero-candidate-B-bench.png" },
    @{ Title = "C. Squat - hero candidate (image swap only)"; Key = "C"; Out = "hero-candidate-C-squat.png" },
    @{ Title = "D. Lat pulldown - hero candidate (image swap only)"; Key = "D"; Out = "hero-candidate-D-lat.png" }
)

foreach ($c in $items) {
    $paths = @(
        (Join-Path $tmp "_tmp-$($c.Key)-pc.png"),
        (Join-Path $tmp "_tmp-$($c.Key)-tablet.png"),
        (Join-Path $tmp "_tmp-$($c.Key)-sp.png")
    )
    Combine-HeroCandidate $c.Title $paths $widths $labels (Join-Path $dst $c.Out)
}

Write-Host "Done"
