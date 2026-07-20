#!/usr/bin/env bash
# Generate AppIcon.icns from a simple programmatic PNG set.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RES="$ROOT_DIR/Resources"
ICONSET="$RES/AppIcon.iconset"
mkdir -p "$ICONSET" "$RES"

python3 - "$RES" <<'PY'
from pathlib import Path
import struct, zlib, sys

res = Path(sys.argv[1])
iconset = res / "AppIcon.iconset"
iconset.mkdir(parents=True, exist_ok=True)

def png(size: int) -> bytes:
    """Minimal dark rounded-square icon with a white network-ish mark."""
    pixels = bytearray(size * size * 4)
    cx = cy = size / 2
    r = size * 0.22
    stroke = max(1, int(size * 0.06))

    def set_px(x, y, a, rgb=(28, 28, 30)):
        if 0 <= x < size and 0 <= y < size:
            i = (y * size + x) * 4
            oa = pixels[i + 3] / 255.0
            na = a / 255.0
            out_a = na + oa * (1 - na)
            if out_a <= 0:
                return
            for c in range(3):
                oc = pixels[i + c] / 255.0
                nc = rgb[c] / 255.0
                pixels[i + c] = int(round(((nc * na) + oc * oa * (1 - na)) / out_a * 255))
            pixels[i + 3] = int(round(out_a * 255))

    def in_rounded_rect(x, y):
        px = abs(x + 0.5 - cx)
        py = abs(y + 0.5 - cy)
        half = size / 2 - 0.5
        ax = max(px - (half - r), 0)
        ay = max(py - (half - r), 0)
        return (ax * ax + ay * ay) <= (r * r) or (px <= half - r and py <= half) or (py <= half - r and px <= half)

    for y in range(size):
        for x in range(size):
            if in_rounded_rect(x, y):
                set_px(x, y, 255, (28, 28, 30))

    outer = size * 0.28
    inner = size * 0.18
    for y in range(size):
        for x in range(size):
            dx = x + 0.5 - cx
            dy = y + 0.5 - cy
            d = (dx * dx + dy * dy) ** 0.5
            if inner <= d <= outer:
                set_px(x, y, 255, (245, 245, 247))
            if abs(dy) < size * 0.05 and cx + outer - 1 <= x + 0.5 <= cx + outer + size * 0.12:
                set_px(x, y, 255, (245, 245, 247))
            ndx = x + 0.5 - (cx + outer * 0.72)
            ndy = y + 0.5 - cy
            if (ndx * ndx + ndy * ndy) ** 0.5 <= size * 0.07:
                set_px(x, y, 255, (245, 245, 247))

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    raw = b"".join(b"\x00" + pixels[y * size * 4:(y + 1) * size * 4] for y in range(size))
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )

sizes = {
    "icon_16x16.png": 16,
    "diana.k@example.org": 32,
    "icon_32x32.png": 32,
    "ivan.p@example.net": 64,
    "icon_128x128.png": 128,
    "wendy.h@example.net": 256,
    "icon_256x256.png": 256,
    "wendy.h@example.net": 512,
    "icon_512x512.png": 512,
    "walt.e@example.net": 1024,
}

for name, s in sizes.items():
    (iconset / name).write_bytes(png(s))
print(f"Wrote {len(sizes)} PNGs to {iconset}")
PY

if command -v iconutil >/dev/null; then
  iconutil -c icns "$ICONSET" -o "$RES/AppIcon.icns"
  echo "Wrote $RES/AppIcon.icns"
else
  echo "warning: iconutil not found; PNG iconset only" >&2
fi
