# TRACE 宣材写真 — 焦点クロップ・トーン統一・WebP最適化（2026-07-26）
param([switch]$SectionOnly)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$script:TraceRoot = Split-Path $PSScriptRoot -Parent
$srcDir = 'C:\Users\kimit\.cursor\projects\c-Users-kimit-OneDrive-TRACE\assets'
$outDir = Join-Path $script:TraceRoot 'assets\img'
$cwebp = Join-Path $PSScriptRoot 'libwebp\libwebp-1.4.0-windows-x64\bin\cwebp.exe'
if (-not (Test-Path $cwebp)) { throw "cwebp not found: $cwebp" }

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function Find-Source([string]$token) {
    $f = Get-ChildItem $srcDir -Filter '*.png' | Where-Object { $_.Name -like "*$token*" } | Select-Object -First 1
    if (-not $f) { throw "Source not found: $token" }
    return $f.FullName
}

Add-Type @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;

public static class PhotoPrep
{
    public static void FocusCropResize(string input, string output, int tw, int th, double focusX, double focusY, double zoom = 1.0)
    {
        using (var src = new Bitmap(input))
        {
            if (zoom < 0.5) zoom = 0.5;
            if (zoom > 2.0) zoom = 2.0;
            double dstRatio = (double)tw / th;
            double srcRatio = (double)src.Width / src.Height;
            int cw, ch;
            if (srcRatio > dstRatio)
            {
                ch = src.Height;
                cw = (int)Math.Round(ch * dstRatio);
            }
            else
            {
                cw = src.Width;
                ch = (int)Math.Round(cw / dstRatio);
            }

            cw = (int)Math.Round(cw / zoom);
            ch = (int)Math.Round(ch / zoom);
            cw = Math.Max(64, Math.Min(cw, src.Width));
            ch = Math.Max(64, Math.Min(ch, src.Height));
            int cx = (int)Math.Round(focusX * src.Width - cw / 2.0);
            int cy = (int)Math.Round(focusY * src.Height - ch / 2.0);
            if (cx < 0) cx = 0;
            if (cy < 0) cy = 0;
            if (cx + cw > src.Width) cx = src.Width - cw;
            if (cy + ch > src.Height) cy = src.Height - ch;

            var crop = new Rectangle(cx, cy, cw, ch);
            using (var tmp = new Bitmap(cw, ch, PixelFormat.Format24bppRgb))
            using (var g0 = Graphics.FromImage(tmp))
            {
                g0.InterpolationMode = InterpolationMode.HighQualityBicubic;
                g0.PixelOffsetMode = PixelOffsetMode.HighQuality;
                g0.CompositingQuality = CompositingQuality.HighQuality;
                g0.DrawImage(src, new Rectangle(0, 0, cw, ch), crop, GraphicsUnit.Pixel);

                using (var dst = new Bitmap(tw, th, PixelFormat.Format24bppRgb))
                using (var g1 = Graphics.FromImage(dst))
                {
                    g1.InterpolationMode = InterpolationMode.HighQualityBicubic;
                    g1.CompositingQuality = CompositingQuality.HighQuality;
                    g1.SmoothingMode = SmoothingMode.HighQuality;
                    g1.DrawImage(tmp, 0, 0, tw, th);
                    dst.Save(output, ImageFormat.Png);
                }
            }
        }
    }

    public static void NormalizeTone(string file)
    {
        Bitmap src = null;
        Bitmap dst = null;
        try
        {
            src = new Bitmap(file);
            int w = src.Width, h = src.Height;
            dst = new Bitmap(w, h, PixelFormat.Format24bppRgb);
            for (int y = 0; y < h; y++)
            {
                for (int x = 0; x < w; x++)
                {
                    Color c = src.GetPixel(x, y);
                    double b = c.B / 255.0 * 1.012;
                    double g = c.G / 255.0;
                    double r = c.R / 255.0 * 0.985;
                    r = Clamp((r - 0.5) * 1.05 + 0.5 + 0.02);
                    g = Clamp((g - 0.5) * 1.05 + 0.5 + 0.02);
                    b = Clamp((b - 0.5) * 1.05 + 0.5 + 0.02);
                    dst.SetPixel(x, y, Color.FromArgb(
                        (byte)Math.Min(255, Math.Max(0, (int)Math.Round(r * 255))),
                        (byte)Math.Min(255, Math.Max(0, (int)Math.Round(g * 255))),
                        (byte)Math.Min(255, Math.Max(0, (int)Math.Round(b * 255)))));
                }
            }
            src.Dispose();
            src = null;
            dst.Save(file, ImageFormat.Png);
        }
        finally
        {
            if (src != null) src.Dispose();
            if (dst != null) dst.Dispose();
        }
    }

    static double Clamp(double v)
    {
        if (v < 0) return 0;
        if (v > 1) return 1;
        return v;
    }
}
"@ -ReferencedAssemblies System.Drawing

function Convert-ToWebP([string]$pngPath, [string]$webpPath, [int]$targetKB = 280) {
    $targetBytes = $targetKB * 1024
    & $cwebp -quiet -size $targetBytes -pass 10 -m 6 -mt $pngPath -o $webpPath
    if ($LASTEXITCODE -ne 0) {
        & $cwebp -quiet -q 90 -m 6 -mt $pngPath -o $webpPath
        if ($LASTEXITCODE -ne 0) { throw "cwebp failed for $pngPath" }
    }
    $kb = (Get-Item $webpPath).Length / 1KB
    return [PSCustomObject]@{ KB = [math]::Round($kb, 1) }
}

function Export-Photo($job) {
    $src = Find-Source $job.Token
    $png = Join-Path $outDir ($job.Out -replace '\.webp$', '.png')
    $webp = Join-Path $outDir $job.Out
    $zoom = if ($job.Zoom) { $job.Zoom } else { 1.0 }
    Write-Host "$($job.Out) <- $(Split-Path $src -Leaf)"
    [PhotoPrep]::FocusCropResize($src, $png, $job.W, $job.H, $job.FocusX, $job.FocusY, $zoom)
    [PhotoPrep]::NormalizeTone($png)
    $info = Convert-ToWebP $png $webp
    Write-Host "  -> $($job.W)x$($job.H) $($info.KB)KB"
}

$allJobs = @(
    @{ Token = '________-9e1f7398'; Out = 'hero-gym.webp'; W = 1024; H = 768; FocusX = 0.50; FocusY = 0.44; Zoom = 1.0 }
    @{ Token = '________-76834'; Out = 'interior.webp'; W = 1024; H = 768; FocusX = 0.50; FocusY = 0.42; Zoom = 1.10 }
    @{ Token = '___-b8bcd262'; Out = 'equipment.webp'; W = 768; H = 960; FocusX = 0.50; FocusY = 0.48; Zoom = 1.0 }
    @{ Token = '____-c0fa8665'; Out = 'studio-02.webp'; W = 768; H = 960; FocusX = 0.50; FocusY = 0.50; Zoom = 1.0 }
    @{ Token = '_______-c05cd149'; Out = 'program-01.webp'; W = 1024; H = 768; FocusX = 0.46; FocusY = 0.36; Zoom = 1.12 }
    @{ Token = '______-dc7e7c65'; Out = 'program-02.webp'; W = 1024; H = 768; FocusX = 0.48; FocusY = 0.38; Zoom = 1.10 }
    @{ Token = '_______-ec3dff90'; Out = 'program-03.webp'; W = 1024; H = 768; FocusX = 0.50; FocusY = 0.40; Zoom = 1.10 }
    @{ Token = '__________2_-72eca'; Out = 'program-04.webp'; W = 1024; H = 768; FocusX = 0.50; FocusY = 0.38; Zoom = 1.08 }
    @{ Token = 'images_15-6c7479f6'; Out = 'trainer-profile.webp'; W = 768; H = 960; FocusX = 0.68; FocusY = 0.38; Zoom = 1.60 }
    @{ Token = '___-793792f0'; Out = 'storefront.webp'; W = 800; H = 1000; FocusX = 0.50; FocusY = 0.52; Zoom = 1.0 }
)

$sectionOnlyJobs = @(
    @{ Token = '___-b8bcd262'; Out = 'equipment.webp'; W = 768; H = 960; FocusX = 0.50; FocusY = 0.48; Zoom = 1.0 }
    @{ Token = '____-c0fa8665'; Out = 'studio-02.webp'; W = 768; H = 960; FocusX = 0.50; FocusY = 0.50; Zoom = 1.0 }
    @{ Token = 'images_15-6c7479f6'; Out = 'trainer-profile.webp'; W = 768; H = 960; FocusX = 0.68; FocusY = 0.38; Zoom = 1.60 }
    @{ Token = '___-793792f0'; Out = 'storefront.webp'; W = 800; H = 1000; FocusX = 0.50; FocusY = 0.52; Zoom = 1.0 }
)

if ($SectionOnly) {
    foreach ($job in $sectionOnlyJobs) { Export-Photo $job }
} else {
    foreach ($job in $allJobs) { Export-Photo $job }
}

Write-Host 'Done'
