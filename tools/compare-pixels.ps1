Add-Type -AssemblyName System.Drawing
$src = $args[0]
$out = $args[1]
$s = [System.Drawing.Bitmap]::FromFile($src)
$o = [System.Drawing.Bitmap]::FromFile($out)
$diff = 0
$w = $s.Width; $h = $s.Height
for ($y = 0; $y -lt $h; $y++) {
    for ($x = 0; $x -lt $w; $x++) {
        if ($s.GetPixel($x, $y).ToArgb() -ne $o.GetPixel($x, $y).ToArgb()) { $diff++ }
    }
}
Write-Host "changed=$diff total=$($w * $h)"
$s.Dispose(); $o.Dispose()
