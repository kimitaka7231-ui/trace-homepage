param(
    [Parameter(Mandatory = $true)][string]$InputPath,
    [Parameter(Mandatory = $true)][string]$OutputPath
)

Add-Type @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class CeilingInpaintStrict
{
    static bool IsStrictCeilingPurple(byte r, byte g, byte b)
    {
        int max = Math.Max(r, Math.Max(g, b));
        int min = Math.Min(r, Math.Min(g, b));
        double sat = max == 0 ? 0 : (max - min) / (double)max;
        double avg = (r + g + b) / 3.0;

        if (avg < 108 || avg > 252) return false;
        if (avg > 238)
            return sat >= 0.012 && b >= g - 10 && r >= g - 14;
        if (sat < 0.022 || sat > 0.42) return false;
        if (b < g - 12 || r < g - 16) return false;
        if ((r + b) * 0.5 < g + 4) return false;
        return r >= g - 22 && b >= g - 14;
    }

    static bool IsProtectedSubject(byte r, byte g, byte b)
    {
        int max = Math.Max(r, Math.Max(g, b));
        int min = Math.Min(r, Math.Min(g, b));
        double sat = max == 0 ? 0 : (max - min) / (double)max;
        double avg = (r + g + b) / 3.0;
        int delta = max - min;

        if (avg < 108) return true;
        if (sat < 0.045 && avg > 168) return true;
        if (sat < 0.10 && avg > 118 && delta < 28) return true;
        return false;
    }

    static bool IsEquipmentNeighbor(byte r, byte g, byte b)
    {
        int max = Math.Max(r, Math.Max(g, b));
        int min = Math.Min(r, Math.Min(g, b));
        double sat = max == 0 ? 0 : (max - min) / (double)max;
        double avg = (r + g + b) / 3.0;
        if (avg < 118) return true;
        if (avg < 170 && sat < 0.14) return true;
        return false;
    }

    static int Clamp(int v, int lo, int hi)
    {
        if (v < lo) return lo;
        if (v > hi) return hi;
        return v;
    }

    public static void Run(string inputPath, string outputPath)
    {
        using (var src = new Bitmap(inputPath))
        {
            int w = src.Width, h = src.Height;
            var rect = new Rectangle(0, 0, w, h);
            var srcData = src.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format24bppRgb);
            int stride = srcData.Stride;
            byte[] bytes = new byte[stride * h];
            Marshal.Copy(srcData.Scan0, bytes, 0, bytes.Length);
            src.UnlockBits(srcData);

            byte[] srcBytes = (byte[])bytes.Clone();
            bool[] mask = new bool[w * h];
            int minY = h, maxY = 0;
            for (int y = 0; y < h; y++)
            {
                int row = y * stride;
                for (int x = 0; x < w; x++)
                {
                    int i = row + x * 3;
                    byte b = srcBytes[i], g = srcBytes[i + 1], r = srcBytes[i + 2];
                    if (!IsStrictCeilingPurple(r, g, b)) continue;
                    if (IsProtectedSubject(r, g, b)) continue;
                    mask[y * w + x] = true;
                    if (y < minY) minY = y;
                    if (y > maxY) maxY = y;
                }
            }

            for (int pass = 0; pass < 2; pass++)
            {
                bool[] copy = (bool[])mask.Clone();
                for (int y = 1; y < h - 1; y++)
                {
                    for (int x = 1; x < w - 1; x++)
                    {
                        int idx = y * w + x;
                        if (!copy[idx]) continue;
                        bool touchEquipment = false;
                        for (int dy = -1; dy <= 1; dy++)
                        {
                            for (int dx = -1; dx <= 1; dx++)
                            {
                                if (dy == 0 && dx == 0) continue;
                                int ni = (y + dy) * stride + (x + dx) * 3;
                                byte nb = srcBytes[ni], ng = srcBytes[ni + 1], nr = srcBytes[ni + 2];
                                if (IsEquipmentNeighbor(nr, ng, nb)) { touchEquipment = true; break; }
                            }
                            if (touchEquipment) break;
                        }
                        if (touchEquipment) mask[idx] = false;
                    }
                }
            }

            minY = h; maxY = 0;
            for (int y = 0; y < h; y++)
            {
                for (int x = 0; x < w; x++)
                {
                    if (!mask[y * w + x]) continue;
                    if (y < minY) minY = y;
                    if (y > maxY) maxY = y;
                }
            }

            using (var layer = DrawCeiling(w, h, minY, maxY))
            {
                var layerData = layer.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format24bppRgb);
                int lStride = layerData.Stride;
                byte[] lBytes = new byte[lStride * h];
                Marshal.Copy(layerData.Scan0, lBytes, 0, lBytes.Length);
                layer.UnlockBits(layerData);

                for (int y = 0; y < h; y++)
                {
                    int row = y * stride, lrow = y * lStride;
                    for (int x = 0; x < w; x++)
                    {
                        if (!mask[y * w + x]) continue;
                        int i = row + x * 3, li = lrow + x * 3;
                        bytes[i] = lBytes[li];
                        bytes[i + 1] = lBytes[li + 1];
                        bytes[i + 2] = lBytes[li + 2];
                    }
                }
            }

            using (var outBmp = new Bitmap(w, h, PixelFormat.Format24bppRgb))
            {
                var outData = outBmp.LockBits(rect, ImageLockMode.WriteOnly, PixelFormat.Format24bppRgb);
                Marshal.Copy(bytes, 0, outData.Scan0, bytes.Length);
                outBmp.UnlockBits(outData);
                outBmp.Save(outputPath, ImageFormat.Png);
            }
        }
    }

    static Bitmap DrawCeiling(int w, int h, int minY, int maxY)
    {
        var layer = new Bitmap(w, h, PixelFormat.Format24bppRgb);
        using (var g = Graphics.FromImage(layer))
        {
            g.SmoothingMode = SmoothingMode.HighQuality;
            var bounds = Rectangle.FromLTRB(0, Math.Max(0, minY - 2), w, Math.Min(h, maxY + 2));
            g.Clear(Color.FromArgb(255, 38, 40, 44));

            using (var brush = new SolidBrush(Color.FromArgb(255, 38, 40, 44)))
                g.FillRectangle(brush, bounds);

            var rand = new Random(42);
            for (int i = 0; i < 2500; i++)
            {
                int x = bounds.Left + rand.Next(Math.Max(1, bounds.Width));
                int y = bounds.Top + rand.Next(Math.Max(1, bounds.Height));
                int n = rand.Next(-5, 6);
                using (var pb = new SolidBrush(Color.FromArgb(255, Clamp(36 + n, 0, 255), Clamp(38 + n, 0, 255), Clamp(42 + n, 0, 255))))
                    g.FillRectangle(pb, x, y, 1, 1);
            }

            int railY1 = bounds.Top + (int)(bounds.Height * 0.28);
            int railY2 = bounds.Top + (int)(bounds.Height * 0.58);
            using (var railPen = new Pen(Color.FromArgb(255, 18, 18, 20), 5))
            {
                g.DrawLine(railPen, bounds.Left + 8, railY1, bounds.Right - 8, railY1);
                g.DrawLine(railPen, bounds.Left + 8, railY2, bounds.Right - 8, railY2);
            }

            double[] spotsX = { 0.12, 0.24, 0.36, 0.48, 0.60, 0.72, 0.84, 0.92 };
            for (int idx = 0; idx < spotsX.Length; idx++)
            {
                int x = bounds.Left + (int)(bounds.Width * spotsX[idx]);
                int y = (idx % 2 == 0) ? railY1 - 2 : railY2 - 2;
                using (var housing = new SolidBrush(Color.FromArgb(255, 22, 22, 24)))
                    g.FillEllipse(housing, x - 7, y - 4, 14, 10);
                using (var core = new SolidBrush(Color.FromArgb(210, 255, 206, 168)))
                    g.FillEllipse(core, x - 4, y - 1, 8, 6);
                using (var path = new GraphicsPath())
                {
                    path.AddEllipse(x - 42, y - 18, 84, 70);
                    using (var pBrush = new PathGradientBrush(path))
                    {
                        pBrush.CenterColor = Color.FromArgb(48, 255, 228, 190);
                        pBrush.SurroundColors = new[] { Color.FromArgb(0, 255, 228, 190) };
                        g.FillEllipse(pBrush, x - 42, y - 18, 84, 70);
                    }
                }
            }
        }
        return layer;
    }
}
"@ -ReferencedAssemblies System.Drawing

$in = (Resolve-Path $InputPath).Path
$out = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
$dir = Split-Path -Parent $out
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
[CeilingInpaintStrict]::Run($in, $out)
Write-Host "Saved: $out"
