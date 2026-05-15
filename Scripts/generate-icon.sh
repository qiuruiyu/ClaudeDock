#!/bin/bash
# Generate Sources/ClaudeDock/Resources/AppIcon.icns from assets/icon-1024.png.
#
# Steps:
#   1) Apply an Apple-style squircle (superellipse, n=5) mask with alpha.
#   2) Emit all iconset sizes (16..1024 + @2x).
#   3) Pack into AppIcon.icns via iconutil.
set -euo pipefail

cd "$(dirname "$0")/.."

SRC="assets/icon-1024.png"
WORK=".build/icon-work"
ICONSET="$WORK/AppIcon.iconset"
OUT="Sources/ClaudeDock/Resources/AppIcon.icns"

[ -f "$SRC" ] || { echo "missing source $SRC"; exit 1; }

rm -rf "$WORK"
mkdir -p "$ICONSET"

echo "==> apply Apple squircle mask"
python3 - "$SRC" "$WORK/icon-1024-masked.png" <<'PY'
import sys
import numpy as np
from PIL import Image

src_path, out_path = sys.argv[1], sys.argv[2]

img = Image.open(src_path).convert("RGBA")
w, h = img.size
assert w == h, f"icon must be square, got {w}x{h}"

# Apple-style squircle = quintic superellipse: |x|^n + |y|^n <= 1, with n=5.
# Renders to a much higher resolution then downsamples — gives a smooth
# anti-aliased boundary without per-pixel coverage math.
oversample = 4
N = w * oversample
n = 5.0
axis = np.linspace(-1.0, 1.0, N, dtype=np.float32)
xx, yy = np.meshgrid(axis, axis)
inside = (np.abs(xx) ** n + np.abs(yy) ** n) <= 1.0
mask_big = Image.fromarray((inside.astype(np.uint8) * 255), mode="L")
mask = mask_big.resize((w, h), Image.LANCZOS)

# Multiply mask into the existing alpha so any pre-existing transparency
# is preserved. The source PNG here is opaque RGB, so this just installs
# the squircle as the alpha channel.
r, g, b, a = img.split()
combined = Image.eval(a, lambda v: v)  # copy
combined = Image.fromarray(
    (np.minimum(np.array(combined, dtype=np.uint16),
                np.array(mask, dtype=np.uint16))).astype(np.uint8),
    mode="L",
)
out = Image.merge("RGBA", (r, g, b, combined))
out.save(out_path, format="PNG")
print(f"wrote {out_path}  size={out.size}  mode={out.mode}")
PY

MASKED="$WORK/icon-1024-masked.png"

echo "==> emit iconset sizes"
# .icns wants: 16, 32, 128, 256, 512 plus their @2x (= 32, 64, 256, 512, 1024).
emit() {
    local size="$1" name="$2"
    sips -s format png -z "$size" "$size" "$MASKED" --out "$ICONSET/$name" >/dev/null
}
emit   16 icon_16x16.png
emit   32 icon_16x16@2x.png
emit   32 icon_32x32.png
emit   64 icon_32x32@2x.png
emit  128 icon_128x128.png
emit  256 icon_128x128@2x.png
emit  256 icon_256x256.png
emit  512 icon_256x256@2x.png
emit  512 icon_512x512.png
emit 1024 icon_512x512@2x.png

echo "==> pack $OUT"
iconutil -c icns "$ICONSET" -o "$OUT"

echo "==> done"
ls -la "$OUT"
