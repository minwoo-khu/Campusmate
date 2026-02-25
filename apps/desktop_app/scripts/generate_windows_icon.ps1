param(
  [string]$SourcePng = "packages/campusmate_core/assets/images/campusmate_logo.png",
  [string]$OutputIco = "windows\runner\resources\app_icon.ico"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Resolve-Path (Join-Path $scriptDir "..")
$repoRoot = Resolve-Path (Join-Path $projectRoot "..\..")

function Resolve-FromRoot([string]$path) {
  if ([System.IO.Path]::IsPathRooted($path)) {
    return (Resolve-Path $path).Path
  }
  return (Resolve-Path (Join-Path $repoRoot $path)).Path
}

$srcPath = Resolve-FromRoot $SourcePng
$outPath = if ([System.IO.Path]::IsPathRooted($OutputIco)) {
  $OutputIco
} else {
  Join-Path $projectRoot $OutputIco
}

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Runtime

$code = @"
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

public static class CampusMateIconBuilder {
    private class IconFrame {
        public int Size;
        public byte[] Data;
    }

    public static void Build(string sourcePng, string outputIco) {
        int[] sizes = new[] {16, 20, 24, 32, 40, 48, 64, 128, 256};
        Bitmap source = new Bitmap(sourcePng);
        List<IconFrame> frames = new List<IconFrame>();
        try {
            foreach (int size in sizes) {
                Bitmap bmp = new Bitmap(size, size, PixelFormat.Format32bppArgb);
                try {
                    using (Graphics g = Graphics.FromImage(bmp)) {
                        g.CompositingQuality = CompositingQuality.HighQuality;
                        g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                        g.SmoothingMode = SmoothingMode.HighQuality;
                        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                        g.Clear(Color.Transparent);
                        g.DrawImage(source, 0, 0, size, size);
                    }
                    frames.Add(new IconFrame { Size = size, Data = BuildBmpIconImageData(bmp) });
                } finally {
                    bmp.Dispose();
                }
            }
        } finally {
            source.Dispose();
        }

        string dir = Path.GetDirectoryName(outputIco);
        if (!String.IsNullOrEmpty(dir)) {
            Directory.CreateDirectory(dir);
        }

        using (FileStream fs = new FileStream(outputIco, FileMode.Create, FileAccess.Write, FileShare.None))
        using (BinaryWriter bw = new BinaryWriter(fs)) {
            bw.Write((ushort)0);
            bw.Write((ushort)1);
            bw.Write((ushort)frames.Count);

            int offset = 6 + frames.Count * 16;
            foreach (IconFrame frame in frames) {
                bw.Write((byte)(frame.Size == 256 ? 0 : frame.Size));
                bw.Write((byte)(frame.Size == 256 ? 0 : frame.Size));
                bw.Write((byte)0);
                bw.Write((byte)0);
                bw.Write((ushort)1);
                bw.Write((ushort)32);
                bw.Write(frame.Data.Length);
                bw.Write(offset);
                offset += frame.Data.Length;
            }

            foreach (IconFrame frame in frames) {
                bw.Write(frame.Data);
            }
        }
    }

    private static byte[] BuildBmpIconImageData(Bitmap bmp) {
        int size = bmp.Width;
        int andStride = ((size + 31) / 32) * 4;

        using (MemoryStream ms = new MemoryStream())
        using (BinaryWriter bw = new BinaryWriter(ms)) {
            bw.Write(40);
            bw.Write(size);
            bw.Write(size * 2);
            bw.Write((ushort)1);
            bw.Write((ushort)32);
            bw.Write(0);
            bw.Write(size * size * 4);
            bw.Write(0);
            bw.Write(0);
            bw.Write(0);
            bw.Write(0);

            Rectangle rect = new Rectangle(0, 0, size, size);
            BitmapData data = bmp.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            try {
                int stride = Math.Abs(data.Stride);
                byte[] raw = new byte[stride * size];
                Marshal.Copy(data.Scan0, raw, 0, raw.Length);

                for (int y = size - 1; y >= 0; y--) {
                    int src = y * stride;
                    bw.Write(raw, src, size * 4);
                }
            } finally {
                bmp.UnlockBits(data);
            }

            bw.Write(new byte[andStride * size]);
            return ms.ToArray();
        }
    }
}
"@

Add-Type -TypeDefinition $code -Language CSharp -ReferencedAssemblies @(
  "System.Drawing.dll",
  "System.Runtime.dll"
) | Out-Null

[CampusMateIconBuilder]::Build($srcPath, $outPath)
Write-Host "Icon generated: $outPath"
