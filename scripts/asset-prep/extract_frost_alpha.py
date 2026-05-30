"""Extract frost/drops from a 'on glass' photo into a TRANSPARENT PNG.

The field (smooth dark center, blown-out bright corners) has low LOCAL contrast;
the frost crystals have high local contrast. So we key alpha off local detail
(luminance minus its local average), keeping only the frost and making the rest
transparent. The scene then shows through the empty glass directly.

    detail = luma - blur(luma)            # positive where locally brighter (frost)
    alpha  = clip(detail * gain, 0, 255)  # frost opaque, field transparent
    RGB    = original colour (so frost keeps its icy look)
"""
import sys
import numpy as np
from PIL import Image, ImageFilter

src   = sys.argv[1]
dst   = sys.argv[2]
gain  = float(sys.argv[3]) if len(sys.argv) > 3 else 3.0
maxpx = 2400

im = Image.open(src).convert("RGB")
# downscale for web (overlay is decorative; 4K is overkill)
if max(im.size) > maxpx:
    s = maxpx / max(im.size)
    im = im.resize((round(im.size[0]*s), round(im.size[1]*s)), Image.LANCZOS)
w, h = im.size

arr  = np.asarray(im, dtype=np.float32)
luma = 0.2126*arr[...,0] + 0.7152*arr[...,1] + 0.0722*arr[...,2]

radius = max(w, h) / 24.0
lblur  = np.asarray(Image.fromarray(luma.astype(np.uint8)).filter(
            ImageFilter.GaussianBlur(radius=radius)), dtype=np.float32)

detail = luma - lblur                       # local high-pass
alpha  = np.clip(detail * gain, 0, 255)

rgba = np.dstack([arr, alpha]).astype(np.uint8)
out  = Image.fromarray(rgba, "RGBA")
out.save(dst)
op = (alpha > 20).mean() * 100
print(f"{src} -> {dst}  {w}x{h}  blur_radius={radius:.0f} gain={gain}")
print(f"  ~{op:.0f}% of pixels are visibly opaque (frost); the rest is transparent glass")
