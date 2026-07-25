# Ceiling-only inpaint: preserves all non-ceiling pixels from source.
param(
    [Parameter(Mandatory = $true)][string]$InputPath,
    [Parameter(Mandatory = $true)][string]$OutputPath
)

Add-Type -AssemblyName System.Drawing

function Get-Rgb([System.Drawing.Bitmap]$bmp, [int]$x, [int]$y) {
    $c = $bmp.GetPixel($x, $y)
    return @($c.R, $c.G, $c.B)
}

function Is-CeilingPurple([int]$r, [int]$g, [int]$b) {
    if ($r -lt 95 -or $g -lt 85 -or $b -lt 95) { return $false }
    if ($r -gt 245 -and $g -gt 245 -and $b -gt 245) { return $false }

    $max = [Math]::Max($r, [Math]::Max($g, $b))
    $min = [Math]::Min($r, [Math]::Min($g, $b))
    $sat = if ($max -eq 0) { 0 } else { ($max - $min) / $max }

    # Mauve / lavender ceiling (exclude neutral chrome and white wall)
    if ($sat -lt 0.04 -or $sat -gt 0.42) { return $false }
    if ($b -lt $g - 8) { return $false }
    if ($r -lt $g - 6) { return $false }

    $avg = ($r + $g + $b) / 3.0
    if ($avg -lt 110 -or $avg -gt 235) { return $false }

    return ($r -ge $g - 18) -and ($b -ge $g - 12)
}

function Draw-CharcoalCross([System.Drawing.Graphics]$g, [int]$w, [int]$h, [System.Drawing.Rectangle]$bounds) {
    $base = [System.Drawing.Color]::FromArgb(255, 38, 40, 44)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $brush = New-Object System.Drawing.SolidBrush($base)
    $g.FillRectangle($brush, $bounds)
    $brush.Dispose()

    $rand = New-Object System.Random 42
    for ($i = 0; $i -lt 18000; $i++) {
        $x = $bounds.Left + $rand.Next($bounds.Width)
        $y = $bounds.Top + $rand.Next($bounds.Height)
        $n = $rand.Next(-8, 9)
        $c = [System.Drawing.Color]::FromArgb(
            255,
            [Math]::Max(0, [Math]::Min(255, 38 + $n)),
            [Math]::Max(0, [Math]::Min(255, 40 + $n)),
            [Math]::Max(0, [Math]::Min(255, 44 + $n))
        )
        $pb = New-Object System.Drawing.SolidBrush($c)
        $g.FillRectangle($pb, $x, $y, 1, 1)
        $pb.Dispose()
    }

    # Subtle cross weave
    $penA = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(18, 255, 255, 255))
    for ($y = $bounds.Top; $y -lt $bounds.Bottom; $y += 6) {
        $g.DrawLine($penA, $bounds.Left, $y, $bounds.Right, $y)
    }
    for ($x = $bounds.Left; $x -lt $bounds.Right; $x += 6) {
        $g.DrawLine($penA, $x, $bounds.Top, $x, $bounds.Bottom)
    }
    $penA.Dispose()
}

function Draw-RailsAndSpots([System.Drawing.Graphics]$g, [int]$w, [int]$h, [System.Drawing.Rectangle]$bounds) {
    $railY1 = $bounds.Top + [int]($bounds.Height * 0.28)
    $railY2 = $bounds.Top + [int]($bounds.Height * 0.58)
    $railPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 18, 18, 20), 5)
    $g.DrawLine($railPen, $bounds.Left + 8, $railY1, $bounds.Right - 8, $railY1)
    $g.DrawLine($railPen, $bounds.Left + 8, $railY2, $bounds.Right - 8, $railY2)
    $railPen.Dispose()

    $spotsX = @(0.12, 0.24, 0.36, 0.48, 0.60, 0.72, 0.84, 0.92)
    $idx = 0
    foreach ($rx in $spotsX) {
        $x = $bounds.Left + [int]($bounds.Width * $rx)
        $y = if ($idx % 2 -eq 0) { $railY1 - 2 } else { $railY2 - 2 }
        $idx++

        $housing = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 22, 22, 24))
        $g.FillEllipse($housing, $x - 7, $y - 4, 14, 10)
        $housing.Dispose()

        $warm = [System.Drawing.Color]::FromArgb(210, 255, 206, 168)
        $core = New-Object System.Drawing.SolidBrush($warm)
        $g.FillEllipse($core, $x - 4, $y - 1, 8, 6)
        $core.Dispose()

        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $path.AddEllipse($x - 42, $y - 18, 84, 70)
        $pBrush = New-Object System.Drawing.Drawing2D.PathGradientBrush($path)
        $pBrush.CenterColor = [System.Drawing.Color]::FromArgb(48, 255, 228, 190)
        $pBrush.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 255, 228, 190))
        $g.FillEllipse($pBrush, $x - 42, $y - 18, 84, 70)
        $pBrush.Dispose()
        $path.Dispose()
    }
}

$src = [System.Drawing.Bitmap]::FromFile((Resolve-Path $InputPath))
$w = $src.Width
$h = $src.Height

$mask = New-Object 'bool[,]' $h, $w
$minY = $h
$maxY = 0

for ($y = 0; $y -lt $h; $y++) {
    for ($x = 0; $x -lt $w; $x++) {
        $rgb = Get-Rgb $src $x $y
        if (Is-CeilingPurple $rgb[0] $rgb[1] $rgb[2]) {
            $mask[$y, $x] = $true
            if ($y -lt $minY) { $minY = $y }
            if ($y -gt $maxY) { $maxY = $y }
        }
    }
}

# Expand mask slightly into purple edge antialiasing
for ($pass = 0; $pass -lt 2; $pass++) {
    $copy = $mask.Clone()
    for ($y = 1; $y -lt ($h - 1); $y++) {
        for ($x = 1; $x -lt ($w - 1); $x++) {
            if ($copy[$y, $x]) { continue }
            $n = 0
            foreach ($dy in -1..1) {
                foreach ($dx in -1..1) {
                    if ($copy[$y + $dy, $x + $dx]) { $n++ }
                }
            }
            if ($n -ge 5) {
                $rgb = Get-Rgb $src $x $y
                if (($rgb[0] + $rgb[1] + $rgb[2]) / 3.0 -gt 100) {
                    $mask[$y, $x] = $true
                }
            }
        }
    }
}

$out = New-Object System.Drawing.Bitmap $w, $h, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
$g = [System.Drawing.Graphics]::FromImage($out)
$g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
$g.DrawImage($src, 0, 0, $w, $h)

$bounds = [System.Drawing.Rectangle]::FromLTRB(0, [Math]::Max(0, $minY - 2), $w, [Math]::Min($h, $maxY + 2))

$ceilingLayer = New-Object System.Drawing.Bitmap $w, $h
$gc = [System.Drawing.Graphics]::FromImage($ceilingLayer)
$gc.Clear([System.Drawing.Color]::Transparent)
Draw-CharcoalCross $gc $w $h $bounds
Draw-RailsAndSpots $gc $w $h $bounds
$gc.Dispose()

for ($y = 0; $y -lt $h; $y++) {
    for ($x = 0; $x -lt $w; $x++) {
        if (-not $mask[$y, $x]) { continue }
        $c = $ceilingLayer.GetPixel($x, $y)
        if ($c.A -gt 0) {
            $out.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($c.R, $c.G, $c.B))
        }
    }
}

# Warm shadow adjustment near ceiling edge only (original pixels preserved, tone shifted)
for ($y = 0; $y -lt $h; $y++) {
    for ($x = 0; $x -lt $w; $x++) {
        if ($mask[$y, $x]) { continue }
        if ($y -lt $maxY - 8) { continue }
        $dist = $y - ($maxY - 8)
        if ($dist -gt 90) { continue }
        $t = 1.0 - ($dist / 90.0)
        $t = $t * $t * 0.12

        $rgb = Get-Rgb $out $x $y
        $r = [int]($rgb[0] * (1.0 - 0.06 * $t) + 255 * (0.02 * $t))
        $g = [int]($rgb[1] * (1.0 - 0.08 * $t))
        $b = [int]($rgb[2] * (1.0 - 0.12 * $t))
        $out.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(
            [Math]::Max(0, [Math]::Min(255, $r)),
            [Math]::Max(0, [Math]::Min(255, $g)),
            [Math]::Max(0, [Math]::Min(255, $b))
        ))
    }
}

$dir = Split-Path -Parent $OutputPath
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
$out.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)

$g.Dispose()
$ceilingLayer.Dispose()
$out.Dispose()
$src.Dispose()

Write-Host "Saved: $OutputPath"
