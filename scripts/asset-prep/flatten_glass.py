"""High-pass flatten a 'frost/rain on glass' photo so it blends cleanly as an overlay.

Removes the low-frequency lighting gradient (bright corners / dark center) while keeping
the sharp high-frequency frost/drop detail, re-centered on mid-gray (128) which is the
neutral point for 'overlay' / 'soft-light' CSS blend modes.

    flat = (original - blur(original)) * gain + 128
"""
import sys
import numpy as np
from PIL import Image, ImageFilter

src   = sys.argv[1]
dst   = sys.argv[2]
gain  = float(sys.argv[3]) if len(sys.argv) > 3 else 1.30

im = Image.open(src).convert("RGB")
w, h = im.size
# blur radius large enough to capture only the lighting gradient, not the frost structure
radius = max(w, h) / 16.0

arr  = np.asarray(im, dtype=np.float32)
blur = np.asarray(im.filter(ImageFilter.GaussianBlur(radius=radius)), dtype=np.float32)

flat = (arr - blur) * gain + 128.0
flat = np.clip(flat, 0, 255).astype(np.uint8)

out = Image.fromarray(flat, "RGB")
out.save(dst, quality=92)
print(f"{src}  {w}x{h}  blur_radius={radius:.0f}  gain={gain}")
print(f"  field mean (orig)  R{arr[...,0].mean():.0f} G{arr[...,1].mean():.0f} B{arr[...,2].mean():.0f}")
print(f"  field mean (flat)  R{flat[...,0].mean():.0f} G{flat[...,1].mean():.0f} B{flat[...,2].mean():.0f}  -> should sit near 128")
print(f"  wrote {dst}")
