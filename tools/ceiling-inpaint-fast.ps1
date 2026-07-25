# Ceiling-only inpaint (LockBits). Non-ceiling pixels copied from source unchanged.
param(
    [Parameter(Mandatory = $true)][string]$InputPath,
    [Parameter(Mandatory = $true)][string]$OutputPath
)

Add-Type -AssemblyName System.Drawing

function Clamp([int]$v, [int]$lo, [int]$hi) {
    if ($v -lt $lo) { return $lo }
    if ($v -gt $hi) { return $hi }
    return $v
}

function Test-CeilingPurple([byte]$r, [byte]$g, [byte]$b) {
    if ($r -lt 95 -or $g -lt 85 -or $b -lt 95) { return $false }
    if ($r -gt 245 -and $g -gt 245 -and $b -gt 245) { return $false }

    $max = [Math]::Max($r, [Math]::Max($g, $b))
    $min = [Math]::Min($r, [Math]::Min($g, $b))
    $sat = if ($max -eq 0) { 0.0 } else { ($max - $min) / $max }
    if ($sat -lt 0.04 -or $sat -gt 0.42) { return $false }
    if ($b -lt $g - 8) { return $false }
    if ($r -lt $g - 6) { return $false }

    $avg = ($r + $g + $b) / 3.0
    if ($avg -lt 110 -or $avg -gt 235) { return $false }
    return ($r -ge $g - 18) -and ($b -ge $g - 12)
}

function Draw-CeilingLayer([int]$w, [int]$h, [int]$minY, [int]$maxY) {
    $layer = New-Object System.Drawing.Bitmap $w, $h, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
    $g = [System.Drawing.Graphics]::FromImage($layer)
    $bounds = [System.Drawing.Rectangle]::FromLTRB(0, [Math]::Max(0, $minY - 2), $w, [Math]::Min($h, $maxY + 2))

    $base = [System.Drawing.Color]::FromArgb(255, 38, 40, 44)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush($base)), $bounds)

    $rand = New-Object System.Random 42
    for ($i = 0; $i -lt 12000; $i++) {
        $x = $bounds.Left + $rand.Next($bounds.Width)
        $y = $bounds.Top + $rand.Next($bounds.Height)
        $n = $rand.Next(-8, 9)
        $c = [System.Drawing.Color]::FromArgb(255, (Clamp (38 + $n) 0 255), (Clamp (40 + $n) 0 255), (Clamp (44 + $n) 0 255))
        $g.FillRectangle((New-Object System.Drawing.SolidBrush($c)), $x, $y, 1, 1)
    }

    $penA = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(18, 255, 255, 255))
    for ($yy = $bounds.Top; $yy -lt $bounds.Bottom; $yy += 6) { $g.DrawLine($penA, $bounds.Left, $yy, $bounds.Right, $yy) }
    for ($xx = $bounds.Left; $xx -lt $bounds.Right; $xx += 6) { $g.DrawLine($penA, $xx, $bounds.Top, $xx, $bounds.Bottom) }

    $railY1 = $bounds.Top + [int]($bounds.Height * 0.28)
    $railY2 = $bounds.Top + [int]($bounds.Height * 0.58)
    $railPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 18, 18, 20), 5)
    $g.DrawLine($railPen, $bounds.Left + 8, $railY1, $bounds.Right - 8, $railY1)
    $g.DrawLine($railPen, $bounds.Left + 8, $railY2, $bounds.Right - 8, $railY2)

    $spotsX = @(0.12, 0.24, 0.36, 0.48, 0.60, 0.72, 0.84, 0.92)
    $idx = 0
    foreach ($rx in $spotsX) {
        $x = $bounds.Left + [int]($bounds.Width * $rx)
        $y = if ($idx % 2 -eq 0) { $railY1 - 2 } else { $railY2 - 2 }
        $idx++
        $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 22, 22, 24))), $x - 7, $y - 4, 14, 10)
        $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(210, 255, 206, 168))), $x - 4, $y - 1, 8, 6)
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $path.AddEllipse($x - 42, $y - 18, 84, 70)
        $pBrush = New-Object System.Drawing.Drawing2D.PathGradientBrush($path)
        $pBrush.CenterColor = [System.Drawing.Color]::FromArgb(48, 255, 228, 190)
        $pBrush.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 255, 228, 190))
        $g.FillEllipse($pBrush, $x - 42, $y - 18, 84, 70)
        $pBrush.Dispose(); $path.Dispose()
    }

    $g.Dispose(); $penA.Dispose(); $railPen.Dispose()
    return $layer
}

$srcPath = (Resolve-Path $InputPath).Path
$src = [System.Drawing.Bitmap]::FromFile($srcPath)
$w = $src.Width; $h = $src.Height

$rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
$srcData = $src.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$stride = $srcData.Stride
$bytes = New-Object byte[] ($stride * $h)
[System.Runtime.InteropServices.Marshal]::Copy($srcData.Scan0, $bytes, 0, $bytes.Length)
$src.UnlockBits($srcData)

$mask = New-Object byte[] ($w * $h)
$minY = $h; $maxY = 0
for ($y = 0; $y -lt $h; $y++) {
    $row = $y * $stride
    for ($x = 0; $x -lt $w; $x++) {
        $i = $row + $x * 3
        $b = $bytes[$i]; $g = $bytes[$i + 1]; $r = $bytes[$i + 2]
        if (Test-CeilingPurple $r $g $b) {
            $mask[$y * $w + $x] = 1
            if ($y -lt $minY) { $minY = $y }
            if ($y -gt $maxY) { $maxY = $y }
        }
    }
}

for ($pass = 0; $pass -lt 2; $pass++) {
    $copy = $mask.Clone()
    for ($y = 1; $y -lt ($h - 1); $y++) {
        for ($x = 1; $x -lt ($w - 1); $x++) {
            $idx = $y * $w + $x
            if ($copy[$idx]) { continue }
            $n = 0
            foreach ($dy in -1..1) { foreach ($dx in -1..1) { if ($copy[($y + $dy) * $w + ($x + $dx)]) { $n++ } } }
            if ($n -ge 5) {
                $row = $y * $stride; $pi = $row + $x * 3
                $avg = ($bytes[$pi + 2] + $bytes[$pi + 1] + $bytes[$pi]) / 3.0
                if ($avg -gt 100) { $mask[$idx] = 1 }
            }
        }
    }
}

$layer = Draw-CeilingLayer $w $h $minY $maxY
$layerData = $layer.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$lStride = $layerData.Stride
$lBytes = New-Object byte[] ($lStride * $h)
[System.Runtime.InteropServices.Marshal]::Copy($layerData.Scan0, $lBytes, 0, $lBytes.Length)
$layer.UnlockBits($layerData)

for ($y = 0; $y -lt $h; $y++) {
    $row = $y * $stride; $lrow = $y * $lStride
    for ($x = 0; $x -lt $w; $x++) {
        $idx = $y * $w + $x
        if ($mask[$idx]) {
            $i = $row + $x * 3; $li = $lrow + $x * 3
            $bytes[$i] = $lBytes[$li]; $bytes[$i + 1] = $lBytes[$li + 1]; $bytes[$i + 2] = $lBytes[$li + 2]
        }
    }
}

for ($y = 0; $y -lt $h; $y++) {
    if ($y -lt $maxY - 8) { continue }
    $dist = $y - ($maxY - 8)
    if ($dist -gt 90) { continue }
    $t = [Math]::Pow(1.0 - ($dist / 90.0), 2) * 0.12
    $row = $y * $stride
    for ($x = 0; $x -lt $w; $x++) {
        $idx = $y * $w + $x
        if ($mask[$idx]) { continue }
        $i = $row + $x * 3
        $r = $bytes[$i + 2]; $g = $bytes[$i + 1]; $b = $bytes[$i]
        $bytes[$i + 2] = [byte](Clamp ([int]($r * (1.0 - 0.06 * $t) + 255 * (0.02 * $t))) 0 255)
        $bytes[$i + 1] = [byte](Clamp ([int]($g * (1.0 - 0.08 * $t))) 0 255)
        $bytes[$i]     = [byte](Clamp ([int]($b * (1.0 - 0.12 * $t))) 0 255)
    }
}

$out = New-Object System.Drawing.Bitmap $w, $h, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
$outData = $out.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
[System.Runtime.InteropServices.Marshal]::Copy($bytes, 0, $outData.Scan0, $bytes.Length)
$out.UnlockBits($outData)

$dir = Split-Path -Parent $OutputPath
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
$out.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)

$layer.Dispose(); $out.Dispose(); $src.Dispose()
Write-Host "Saved: $OutputPath (ceiling rows $minY-$maxY)"
