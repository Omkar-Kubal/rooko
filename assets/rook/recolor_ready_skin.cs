using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Linq;
using System.Runtime.InteropServices;

// Recolors the existing Ready artwork without redrawing its features.
public static class ReadyRookSkinColor
{
    private sealed class Component
    {
        public int Id;
        public int Count;
        public int MinX = int.MaxValue;
        public int MinY = int.MaxValue;
        public int MaxX;
        public int MaxY;
    }

    private sealed class ImageData : IDisposable
    {
        public readonly Bitmap Bitmap;
        public readonly byte[] Pixels;
        public readonly int Width;
        public readonly int Height;
        public readonly int Stride;

        public ImageData(string path)
        {
            Bitmap = new Bitmap(path);
            Width = Bitmap.Width;
            Height = Bitmap.Height;
            if (Bitmap.PixelFormat != PixelFormat.Format32bppArgb)
                throw new InvalidOperationException("Ready Rook must be a 32-bit RGBA PNG.");
            var rectangle = new Rectangle(0, 0, Width, Height);
            var bits = Bitmap.LockBits(rectangle, ImageLockMode.ReadOnly, Bitmap.PixelFormat);
            Stride = bits.Stride;
            if (Stride <= 0) throw new InvalidOperationException("Unexpected top-down PNG stride.");
            Pixels = new byte[Stride * Height];
            Marshal.Copy(bits.Scan0, Pixels, 0, Pixels.Length);
            Bitmap.UnlockBits(bits);
        }

        public void Dispose() { Bitmap.Dispose(); }
    }

    private static bool IsSkinCandidate(ImageData image, int pixelIndex)
    {
        int offset = (pixelIndex / image.Width) * image.Stride + (pixelIndex % image.Width) * 4;
        int b = image.Pixels[offset];
        int g = image.Pixels[offset + 1];
        int r = image.Pixels[offset + 2];
        int a = image.Pixels[offset + 3];
        int lightness = (r + g + b) / 3;
        int spread = Math.Max(r, Math.Max(g, b)) - Math.Min(r, Math.Min(g, b));
        return a >= 16 && lightness >= 90 && lightness < 247 && spread <= 22;
    }

    private static Tuple<int[], List<Component>> FindComponents(ImageData image)
    {
        int length = image.Width * image.Height;
        int[] labels = new int[length];
        int[] queue = new int[length];
        var components = new List<Component>();
        for (int start = 0; start < length; start++)
        {
            if (labels[start] != 0 || !IsSkinCandidate(image, start)) continue;
            var component = new Component { Id = components.Count + 1 };
            components.Add(component);
            int head = 0;
            int tail = 0;
            queue[tail++] = start;
            labels[start] = component.Id;
            while (head < tail)
            {
                int current = queue[head++];
                int x = current % image.Width;
                int y = current / image.Width;
                component.Count++;
                component.MinX = Math.Min(component.MinX, x);
                component.MaxX = Math.Max(component.MaxX, x);
                component.MinY = Math.Min(component.MinY, y);
                component.MaxY = Math.Max(component.MaxY, y);
                int[] neighbors = { x > 0 ? current - 1 : -1,
                    x < image.Width - 1 ? current + 1 : -1,
                    y > 0 ? current - image.Width : -1,
                    y < image.Height - 1 ? current + image.Width : -1 };
                foreach (int next in neighbors)
                {
                    if (next < 0 || labels[next] != 0 || !IsSkinCandidate(image, next)) continue;
                    labels[next] = component.Id;
                    queue[tail++] = next;
                }
            }
        }
        return Tuple.Create(labels, components);
    }

    public static string Describe(string inputPath)
    {
        using (var image = new ImageData(inputPath))
        {
            var result = FindComponents(image);
            int seed = result.Item1[340 * image.Width + 626];
            var top = result.Item2.OrderByDescending(c => c.Count).Take(8)
                .Select(c => string.Format("{0}: {1} px ({2},{3})-({4},{5})",
                    c.Id, c.Count, c.MinX, c.MinY, c.MaxX, c.MaxY));
            return "Skin seed component: " + seed + Environment.NewLine + string.Join(Environment.NewLine, top);
        }
    }

    public static int Recolor(string inputPath, string outputPath)
    {
        using (var image = new ImageData(inputPath))
        {
            var result = FindComponents(image);
            int selected = result.Item1[340 * image.Width + 626];
            if (selected == 0) throw new InvalidOperationException("Skin seed is outside the brain.");
            int count = result.Item2[selected - 1].Count;
            if (count < 200000 || count > 950000)
                throw new InvalidOperationException("Unexpected skin region size: " + count);

            byte[] output = (byte[])image.Pixels.Clone();
            for (int i = 0; i < result.Item1.Length; i++)
            {
                if (result.Item1[i] != selected) continue;
                int offset = (i / image.Width) * image.Stride + (i % image.Width) * 4;
                int r = image.Pixels[offset + 2];
                int g = image.Pixels[offset + 1];
                int b = image.Pixels[offset];
                double lightness = (r + g + b) / 3.0;
                double shade = lightness - 215.0;
                output[offset + 2] = Clamp(245.0 + shade * 0.65);
                output[offset + 1] = Clamp(161.0 + shade * 0.72);
                output[offset] = Clamp(157.0 + shade * 0.75);
            }

            using (var colored = new Bitmap(image.Width, image.Height, PixelFormat.Format32bppArgb))
            {
                var rectangle = new Rectangle(0, 0, image.Width, image.Height);
                var bits = colored.LockBits(rectangle, ImageLockMode.WriteOnly, colored.PixelFormat);
                Marshal.Copy(output, 0, bits.Scan0, output.Length);
                colored.UnlockBits(bits);
                colored.Save(outputPath, ImageFormat.Png);
            }
            return count;
        }
    }

    private static byte Clamp(double value)
    {
        return (byte)Math.Max(0, Math.Min(255, Math.Round(value)));
    }
}
