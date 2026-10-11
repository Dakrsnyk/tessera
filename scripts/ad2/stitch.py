"""Stitches the scroll slices of a page (<name>-s00 … -s10, from [adkit] screens) into one tall picture,
for a perfectly smooth 60 fps virtual scroll: the offset between two slices is measured on their middle
band (the sticky header and the tab bar stay put on screen and are left out).

    python -X utf8 stitch.py <kit dir> <name> <out.png>     → <out.png> and <out>.json (slice offsets)
"""
import json
import os
import sys

import numpy as np
from PIL import Image

TOP, BOTTOM = 420, 2300  # the band of real content in every slice (between the header and the tab bar)


def gray(path):
    return np.asarray(Image.open(path).convert("L"), dtype=np.float64)


def offset(a, b, max_shift=1400):
    """dy such that b[y] == a[y + dy] on the content band (b scrolled further by dy)."""
    band = b[TOP + 200:TOP + 700]
    best, best_dy = None, 0
    for dy in range(0, max_shift):
        if TOP + 200 + dy + 500 > BOTTOM:
            break
        err = np.mean(np.abs(a[TOP + 200 + dy:TOP + 700 + dy] - band))
        if best is None or err < best:
            best, best_dy = err, dy
    return best_dy, best


def main():
    root, name, out = sys.argv[1:4]
    files = [os.path.join(root, f"{name}-s{i:02d}.png") for i in range(11)]
    files = [f for f in files if os.path.exists(f)]
    grays = [gray(f) for f in files]
    offsets = [0]
    for a, b in zip(grays, grays[1:]):
        dy, err = offset(a, b)
        offsets.append(offsets[-1] + dy)
        print(f"+{dy} (err {err:.2f})")
    height = offsets[-1] + 2622
    tall = Image.new("RGB", (1206, height))
    tall.paste(Image.open(files[0]).convert("RGB"), (0, 0))
    for f, off in zip(files[1:], offsets[1:]):
        band = Image.open(f).convert("RGB").crop((0, TOP, 1206, BOTTOM))
        tall.paste(band, (0, off + TOP))
    # The last slice's own bottom (below the band) closes the page.
    last = Image.open(files[-1]).convert("RGB").crop((0, BOTTOM, 1206, 2622))
    tall.paste(last, (0, offsets[-1] + BOTTOM))
    tall.save(out)
    json.dump({"offsets": offsets, "height": height, "band": [TOP, BOTTOM]}, open(os.path.splitext(out)[0] + ".json", "w"), indent=1)
    print(name, "→", out, tall.size, "offsets", offsets)


if __name__ == "__main__":
    main()
