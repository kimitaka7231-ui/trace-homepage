using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;

class NormalizePhotoTone
{
    const double Warm = 0.985;
    const double Cool = 1.012;
    const double Contrast = 1.05;
    const double Brightness = 0.02;

    static void Main(string[] args)
    {
        if (args.Length < 1)
        {
            Console.Error.WriteLine("Usage: NormalizePhotoTone.exe <file>");
            Environment.Exit(1);
        }

        Process(args[0]);
    }

    static void Process(string file)
    {
        using (var src = new Bitmap(file))
        {
            var rect = new Rectangle(0, 0, src.Width, src.Height);
            var data = src.LockBits(rect, ImageLockMode.ReadWrite, PixelFormat.Format24bppRgb);
            int stride = data.Stride;
            unsafe
            {
                byte* ptr = (byte*)data.Scan0;
                for (int y = 0; y < src.Height; y++)
                {
                    byte* row = ptr + y * stride;
                    for (int x = 0; x < src.Width; x++)
                    {
                        int i = x * 3;
                        double b = row[i] / 255.0 * Cool;
                        double g = row[i + 1] / 255.0;
                        double r = row[i + 2] / 255.0 * Warm;
                        row[i] = ToByte(ApplyContrast(b));
                        row[i + 1] = ToByte(ApplyContrast(g));
                        row[i + 2] = ToByte(ApplyContrast(r));
                    }
                }
            }
            src.UnlockBits(data);
            src.Save(file, ImageFormat.Png);
        }
        Console.WriteLine("OK " + Path.GetFileName(file));
    }

    static double ApplyContrast(double v)
    {
        v = (v - 0.5) * Contrast + 0.5 + Brightness;
        if (v < 0) return 0;
        if (v > 1) return 1;
        return v;
    }

    static byte ToByte(double v)
    {
        return (byte)Math.Round(v * 255.0);
    }
}
