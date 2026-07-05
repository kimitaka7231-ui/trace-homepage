using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;

class TracePhotoRetouch
{
    const double Contrast = 1.10;
    const double ShadowLift = 0.018;
    const double BlackPoint = 0.015;
    const double HighlightCompress = 0.55;
    const double WarmReduce = 0.985;
    const double CoolBoost = 1.012;
    const double BgDarken = 0.14;
    const double SubjectLift = 0.065;
    const double BrightBgSuppress = 0.22;
    const double BlurSigma = 2.2;
    const double SharpenAmount = 0.32;
    const double SharpenSigma = 1.1;
    const double SkinSoftBlend = 0.10;

    static void Main(string[] args)
    {
        if (args.Length < 2)
        {
            Console.Error.WriteLine("Usage: TracePhotoRetouch.exe <input> <output>");
            Environment.Exit(1);
        }

        using (var src = new Bitmap(args[0]))
        {
            var result = Retouch(src);
            Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(args[1])));
            result.Save(args[1], ImageFormat.Png);
        }
    }

    static Bitmap Retouch(Bitmap src)
    {
        int w = src.Width, h = src.Height;
        var rgb = ToFloatArray(src);
        var mask = BuildSubjectMask(w, h);

        ApplyNeutralGrade(ref rgb, w, h);
        ApplyToneCurve(ref rgb, w, h);
        SuppressBrightBackground(ref rgb, w, h, mask);
        ApplySubjectBackgroundBalance(ref rgb, w, h, mask);
        rgb = BlendWithBlurredBackground(rgb, w, h, mask, BlurSigma);
        SoftenSkin(ref rgb, w, h, mask);
        rgb = UnsharpMask(rgb, w, h, SharpenSigma, SharpenAmount);
        CleanupFloorSpecks(ref rgb, w, h);
        return FromFloatArray(rgb, w, h);
    }

    static float[,,] ToFloatArray(Bitmap bmp)
    {
        int w = bmp.Width, h = bmp.Height;
        var data = new float[h, w, 3];
        var rect = new Rectangle(0, 0, w, h);
        var bd = bmp.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format24bppRgb);
        int stride = bd.Stride;
        unsafe
        {
            byte* ptr = (byte*)bd.Scan0;
            for (int y = 0; y < h; y++)
            {
                byte* row = ptr + y * stride;
                for (int x = 0; x < w; x++)
                {
                    int i = x * 3;
                    data[y, x, 2] = row[i] / 255f;
                    data[y, x, 1] = row[i + 1] / 255f;
                    data[y, x, 0] = row[i + 2] / 255f;
                }
            }
        }
        bmp.UnlockBits(bd);
        return data;
    }

    static Bitmap FromFloatArray(float[,,] rgb, int w, int h)
    {
        var bmp = new Bitmap(w, h, PixelFormat.Format24bppRgb);
        var rect = new Rectangle(0, 0, w, h);
        var bd = bmp.LockBits(rect, ImageLockMode.WriteOnly, PixelFormat.Format24bppRgb);
        int stride = bd.Stride;
        unsafe
        {
            byte* ptr = (byte*)bd.Scan0;
            for (int y = 0; y < h; y++)
            {
                byte* row = ptr + y * stride;
                for (int x = 0; x < w; x++)
                {
                    int i = x * 3;
                    row[i] = ClampByte(rgb[y, x, 2] * 255f);
                    row[i + 1] = ClampByte(rgb[y, x, 1] * 255f);
                    row[i + 2] = ClampByte(rgb[y, x, 0] * 255f);
                }
            }
        }
        bmp.UnlockBits(bd);
        return bmp;
    }

    static int ClampByte(float v)
    {
        if (v < 0f) return 0;
        if (v > 255f) return 255;
        return (int)Math.Round(v);
    }

    static float Clamp01(float v)
    {
        if (v < 0f) return 0f;
        if (v > 1f) return 1f;
        return v;
    }

    static float Luma(float r, float g, float b)
    {
        return 0.2126f * r + 0.7152f * g + 0.0722f * b;
    }

    static void ApplyNeutralGrade(ref float[,,] rgb, int w, int h)
    {
        for (int y = 0; y < h; y++)
        for (int x = 0; x < w; x++)
        {
            rgb[y, x, 0] *= (float)WarmReduce;
            rgb[y, x, 2] *= (float)CoolBoost;
            float l = Luma(rgb[y, x, 0], rgb[y, x, 1], rgb[y, x, 2]);
            float sat = 1f - (float)(BrightBgSuppress * 0.15);
            rgb[y, x, 0] = l + (rgb[y, x, 0] - l) * sat;
            rgb[y, x, 1] = l + (rgb[y, x, 1] - l) * sat;
            rgb[y, x, 2] = l + (rgb[y, x, 2] - l) * sat;
        }
    }

    static void ApplyToneCurve(ref float[,,] rgb, int w, int h)
    {
        for (int y = 0; y < h; y++)
        for (int x = 0; x < w; x++)
        for (int c = 0; c < 3; c++)
        {
            float v = rgb[y, x, c];
            if (v < 0.35f) v = v * 0.94f + (float)ShadowLift;
            v = (v - (float)BlackPoint) / (1f - (float)BlackPoint);
            v = (v - 0.5f) * (float)Contrast + 0.5f;
            if (v > 0.90f) v = 0.90f + (v - 0.90f) * (float)HighlightCompress;
            rgb[y, x, c] = Clamp01(v);
        }
    }

    static float[,] BuildSubjectMask(int w, int h)
    {
        float cx = w * 0.44f;
        float cy = h * 0.47f;
        float rx = w * 0.40f;
        float ry = h * 0.44f;
        var mask = new float[h, w];
        for (int y = 0; y < h; y++)
        for (int x = 0; x < w; x++)
        {
            float dx = (x - cx) / rx;
            float dy = (y - cy) / ry;
            float d = (float)Math.Sqrt(dx * dx + dy * dy);
            float m = 1f - SmoothStep(0.55f, 1.15f, d);
            mask[y, x] = m * m;
        }
        return GaussianBlurMask(mask, w, h, 18);
    }

    static float SmoothStep(float e0, float e1, float x)
    {
        float t = Clamp01((x - e0) / (e1 - e0));
        return t * t * (3f - 2f * t);
    }

    static float[,] GaussianBlurMask(float[,] src, int w, int h, int radius)
    {
        var tmp = new float[h, w];
        var dst = new float[h, w];
        float[] kernel = MakeGaussianKernel(radius);
        int r = kernel.Length / 2;

        for (int y = 0; y < h; y++)
        for (int x = 0; x < w; x++)
        {
            float sum = 0, wsum = 0;
            for (int k = -r; k <= r; k++)
            {
                int sx = Math.Max(0, Math.Min(w - 1, x + k));
                float wt = kernel[k + r];
                sum += src[y, sx] * wt;
                wsum += wt;
            }
            tmp[y, x] = sum / wsum;
        }

        for (int y = 0; y < h; y++)
        for (int x = 0; x < w; x++)
        {
            float sum = 0, wsum = 0;
            for (int k = -r; k <= r; k++)
            {
                int sy = Math.Max(0, Math.Min(h - 1, y + k));
                float wt = kernel[k + r];
                sum += tmp[sy, x] * wt;
                wsum += wt;
            }
            dst[y, x] = sum / wsum;
        }
        return dst;
    }

    static float[] MakeGaussianKernel(int radius)
    {
        int size = radius * 2 + 1;
        var k = new float[size];
        float sigma = radius / 2.5f;
        float sum = 0;
        for (int i = 0; i < size; i++)
        {
            int x = i - radius;
            k[i] = (float)Math.Exp(-(x * x) / (2 * sigma * sigma));
            sum += k[i];
        }
        for (int i = 0; i < size; i++) k[i] /= sum;
        return k;
    }

    static void SuppressBrightBackground(ref float[,,] rgb, int w, int h, float[,] mask)
    {
        for (int y = 0; y < h; y++)
        for (int x = 0; x < w; x++)
        {
            float bg = 1f - mask[y, x];
            if (bg < 0.15f) continue;
            float l = Luma(rgb[y, x, 0], rgb[y, x, 1], rgb[y, x, 2]);
            bool rightWall = x > w * 0.58f;
            bool upperBright = l > 0.72f && y < h * 0.85f;
            if (l > 0.68f || (rightWall && l > 0.55f))
            {
                float amt = (float)(BrightBgSuppress * bg * (rightWall ? 1.25 : 1.0));
                if (upperBright) amt *= 1.15f;
                rgb[y, x, 0] *= 1f - amt;
                rgb[y, x, 1] *= 1f - amt;
                rgb[y, x, 2] *= 1f - amt;
                float nl = Luma(rgb[y, x, 0], rgb[y, x, 1], rgb[y, x, 2]);
                rgb[y, x, 0] = nl + (rgb[y, x, 0] - nl) * 0.82f;
                rgb[y, x, 1] = nl + (rgb[y, x, 1] - nl) * 0.82f;
                rgb[y, x, 2] = nl + (rgb[y, x, 2] - nl) * 0.82f;
            }
        }
    }

    static void ApplySubjectBackgroundBalance(ref float[,,] rgb, int w, int h, float[,] mask)
    {
        for (int y = 0; y < h; y++)
        for (int x = 0; x < w; x++)
        {
            float m = mask[y, x];
            float bg = 1f - m;
            float l = Luma(rgb[y, x, 0], rgb[y, x, 1], rgb[y, x, 2]);

            float bgFactor = 1f - (float)BgDarken * bg;
            rgb[y, x, 0] *= bgFactor;
            rgb[y, x, 1] *= bgFactor;
            rgb[y, x, 2] *= bgFactor;

            float lift = (float)SubjectLift * m * (1f - Math.Abs(l - 0.45f) * 1.6f);
            if (lift > 0)
            {
                rgb[y, x, 0] = Clamp01(rgb[y, x, 0] + lift);
                rgb[y, x, 1] = Clamp01(rgb[y, x, 1] + lift * 0.95f);
                rgb[y, x, 2] = Clamp01(rgb[y, x, 2] + lift * 0.88f);
            }

            // TRACE logo area: left chest on trainer
            if (x > w * 0.18f && x < w * 0.42f && y > h * 0.28f && y < h * 0.52f && l < 0.45f)
            {
                float logoLift = 0.04f * (0.45f - l);
                rgb[y, x, 0] = Clamp01(rgb[y, x, 0] + logoLift);
                rgb[y, x, 1] = Clamp01(rgb[y, x, 1] + logoLift);
                rgb[y, x, 2] = Clamp01(rgb[y, x, 2] + logoLift);
            }
        }
    }

    static float[,,] BlendWithBlurredBackground(float[,,] rgb, int w, int h, float[,] mask, double sigma)
    {
        var blurred = GaussianBlurRgb(rgb, w, h, sigma);
        var outRgb = new float[h, w, 3];
        for (int y = 0; y < h; y++)
        for (int x = 0; x < w; x++)
        {
            float m = mask[y, x];
            for (int c = 0; c < 3; c++)
                outRgb[y, x, c] = rgb[y, x, c] * m + blurred[y, x, c] * (1f - m);
        }
        return outRgb;
    }

    static float[,,] GaussianBlurRgb(float[,,] src, int w, int h, double sigma)
    {
        int radius = Math.Max(1, (int)Math.Ceiling(sigma * 3));
        var kernel = MakeGaussianKernel(radius);
        int r = kernel.Length / 2;
        var tmp = new float[h, w, 3];
        var dst = new float[h, w, 3];

        for (int y = 0; y < h; y++)
        for (int x = 0; x < w; x++)
        for (int c = 0; c < 3; c++)
        {
            float sum = 0, wsum = 0;
            for (int k = -r; k <= r; k++)
            {
                int sx = Math.Max(0, Math.Min(w - 1, x + k));
                float wt = kernel[k + r];
                sum += src[y, sx, c] * wt;
                wsum += wt;
            }
            tmp[y, x, c] = sum / wsum;
        }

        for (int y = 0; y < h; y++)
        for (int x = 0; x < w; x++)
        for (int c = 0; c < 3; c++)
        {
            float sum = 0, wsum = 0;
            for (int k = -r; k <= r; k++)
            {
                int sy = Math.Max(0, Math.Min(h - 1, y + k));
                float wt = kernel[k + r];
                sum += tmp[sy, x, c] * wt;
                wsum += wt;
            }
            dst[y, x, c] = sum / wsum;
        }
        return dst;
    }

    static bool IsSkin(float r, float g, float b)
    {
        if (r <= g || g <= b) return false;
        if (r - g < 0.04f) return false;
        float l = Luma(r, g, b);
        return l > 0.18f && l < 0.82f;
    }

    static void SoftenSkin(ref float[,,] rgb, int w, int h, float[,] mask)
    {
        var soft = GaussianBlurRgb(rgb, w, h, 1.4);
        for (int y = 0; y < h; y++)
        for (int x = 0; x < w; x++)
        {
            if (mask[y, x] < 0.35f) continue;
            if (!IsSkin(rgb[y, x, 0], rgb[y, x, 1], rgb[y, x, 2])) continue;
            float blend = (float)SkinSoftBlend * mask[y, x];
            for (int c = 0; c < 3; c++)
                rgb[y, x, c] = rgb[y, x, c] * (1f - blend) + soft[y, x, c] * blend;
        }
    }

    static float[,,] UnsharpMask(float[,,] rgb, int w, int h, double sigma, double amount)
    {
        var blur = GaussianBlurRgb(rgb, w, h, sigma);
        var outRgb = new float[h, w, 3];
        for (int y = 0; y < h; y++)
        for (int x = 0; x < w; x++)
        for (int c = 0; c < 3; c++)
        {
            float detail = rgb[y, x, c] - blur[y, x, c];
            outRgb[y, x, c] = Clamp01(rgb[y, x, c] + detail * (float)amount);
        }
        return outRgb;
    }

    static void CleanupFloorSpecks(ref float[,,] rgb, int w, int h)
    {
        int yStart = (int)(h * 0.72f);
        var median = MedianBlurLocal(rgb, w, h, yStart, 1);
        for (int y = yStart; y < h; y++)
        for (int x = 0; x < w; x++)
        {
            float l = Luma(rgb[y, x, 0], rgb[y, x, 1], rgb[y, x, 2]);
            if (l > 0.08f && l < 0.42f)
            {
                float blend = 0.35f;
                for (int c = 0; c < 3; c++)
                    rgb[y, x, c] = rgb[y, x, c] * (1f - blend) + median[y, x, c] * blend;
            }
        }
    }

    static float[,,] MedianBlurLocal(float[,,] src, int w, int h, int yStart, int rad)
    {
        var dst = (float[,,])src.Clone();
        var buf = new float[(rad * 2 + 1) * (rad * 2 + 1)];
        for (int y = yStart; y < h; y++)
        for (int x = 0; x < w; x++)
        {
            int n = 0;
            for (int dy = -rad; dy <= rad; dy++)
            for (int dx = -rad; dx <= rad; dx++)
            {
                int sx = Math.Max(0, Math.Min(w - 1, x + dx));
                int sy = Math.Max(yStart, Math.Min(h - 1, y + dy));
                buf[n++] = Luma(src[sy, sx, 0], src[sy, sx, 1], src[sy, sx, 2]);
            }
            Array.Sort(buf, 0, n);
            float med = buf[n / 2];
            float cur = Luma(src[y, x, 0], src[y, x, 1], src[y, x, 2]);
            if (Math.Abs(cur - med) > 0.06f)
            {
                float delta = med - cur;
                for (int c = 0; c < 3; c++)
                    dst[y, x, c] = Clamp01(src[y, x, c] + delta * 0.6f);
            }
        }
        return dst;
    }
}
