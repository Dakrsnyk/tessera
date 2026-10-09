"""Assembles the App Store screenshots from a CI report ([marketing] in a commit message).

    python3 scripts/marketing_compose.py <report>/marketing <output folder>

Reads scripts/marketing_scenes.txt. A scene drawn entirely by the app is copied as is. A scene with
a phone was rendered twice, its screen area white then black: the difference between the two says,
for each pixel, how much of the screen shows through, and the real capture of the screen goes there
(shadows and widgets drawn over the phone stay on top). The two halves of a panorama are joined
before matting, since a phone or a widget can straddle them, then cut apart again.
Also writes contact-sheet.jpg: every screenshot, numbered, in order. Needs Pillow and numpy.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def scenes():
    items = []
    for line in open(os.path.join(ROOT, "scripts", "marketing_scenes.txt"), encoding="utf8"):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        items.append((parts[0], parts[1] if len(parts) > 1 else None))
    return items


def load(path):
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)


def matte(white, black, screen):
    """The black render, plus the real screen wherever the white and black renders differ."""
    through = np.clip((white - black).mean(axis=2) / 255.0, 0.0, 1.0)
    ys, xs = np.nonzero(through > 0.5)
    if len(xs) == 0:
        return black
    x0, x1, y0 = int(xs.min()), int(xs.max()), int(ys.min())
    # The capture at the width of the screen area, a little larger so its edge never shows.
    margin = 2
    width = x1 - x0 + 1 + margin * 2
    height = round(screen.height * width / screen.width)
    scaled = np.asarray(screen.convert("RGB").resize((width, height), Image.LANCZOS), dtype=np.float32)
    layer = np.zeros_like(black)
    left, top = x0 - margin, y0 - margin
    src_x, src_y = max(0, -left), max(0, -top)
    dst_x, dst_y = max(0, left), max(0, top)
    w = min(width - src_x, layer.shape[1] - dst_x)
    h = min(height - src_y, layer.shape[0] - dst_y)
    layer[dst_y:dst_y + h, dst_x:dst_x + w] = scaled[src_y:src_y + h, src_x:src_x + w]
    return black + through[..., None] * layer


def save(array, path):
    Image.fromarray(np.clip(array + 0.5, 0, 255).astype(np.uint8), "RGB").save(path, optimize=True)


def compose(source, output):
    os.makedirs(output, exist_ok=True)
    items = scenes()
    done = {}
    written = []
    for index, (scene, screen) in enumerate(items, 1):
        target = os.path.join(output, f"{index:02d}-{scene}.png")
        if scene in done:
            save(done[scene], target)
            written.append(target)
            continue
        if screen is None:
            Image.open(os.path.join(source, f"{scene}.png")).convert("RGB").save(target, optimize=True)
            written.append(target)
            continue
        capture = Image.open(os.path.join(source, f"screen-{screen}.png"))
        if scene.startswith("pano-"):
            base = scene[:-2]
            halves = [f"{base}-1", f"{base}-2"]
            white = np.hstack([load(os.path.join(source, f"{h}-white.png")) for h in halves])
            black = np.hstack([load(os.path.join(source, f"{h}-black.png")) for h in halves])
            joined = matte(white, black, capture)
            half = joined.shape[1] // 2
            done[halves[0]], done[halves[1]] = joined[:, :half], joined[:, half:]
            save(done[scene], target)
        else:
            white = load(os.path.join(source, f"{scene}-white.png"))
            black = load(os.path.join(source, f"{scene}-black.png"))
            save(matte(white, black, capture), target)
        written.append(target)
    contact_sheet(written, os.path.join(output, "contact-sheet.jpg"))
    return written


def contact_sheet(paths, target, per_row=6, thumb_width=300):
    thumbs = [Image.open(p).convert("RGB") for p in paths]
    thumb_height = round(thumbs[0].height * thumb_width / thumbs[0].width)
    gap, label = 18, 44
    rows = (len(thumbs) + per_row - 1) // per_row
    sheet = Image.new("RGB", (gap + per_row * (thumb_width + gap), gap + rows * (thumb_height + label + gap)), (38, 34, 35))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.load_default(size=26)
    except TypeError:
        font = ImageFont.load_default()
    for index, (path, thumb) in enumerate(zip(paths, thumbs)):
        x = gap + (index % per_row) * (thumb_width + gap)
        y = gap + (index // per_row) * (thumb_height + label + gap)
        sheet.paste(thumb.resize((thumb_width, thumb_height), Image.LANCZOS), (x, y))
        draw.text((x, y + thumb_height + 8), os.path.basename(path)[:-4], fill=(240, 236, 230), font=font)
    sheet.save(target, quality=88)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    for path in compose(sys.argv[1], sys.argv[2]):
        print(path)
