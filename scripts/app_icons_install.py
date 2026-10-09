"""Puts the icons rendered by scripts/app_icons.js into the asset catalog.

    python3 scripts/app_icons_install.py <folder rendered by app_icons.js>

Each icon becomes an icon set (light, dark, tinted at 1024 px) and a small picture
`IconPreview-<name>` shown in « Icône de l'app ». The main icon is AppIcon; every other icon set
is built as an alternate icon (ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS).
"""
import json
import os
import shutil
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "App", "Assets.xcassets")
INFO = {"author": "xcode", "version": 1}


def icon_set(name, source):
    folder = os.path.join(ASSETS, f"{name}.appiconset")
    os.makedirs(folder, exist_ok=True)
    images = []
    for variant, suffix, appearance in (("light", "", None), ("dark", "-Dark", "dark"), ("tinted", "-Tinted", "tinted")):
        filename = f"{name}{suffix}-1024.png"
        Image.open(os.path.join(source, f"{name}-{variant}.png")).convert("RGB").save(os.path.join(folder, filename), optimize=True)
        image = {"filename": filename, "idiom": "universal", "platform": "ios", "size": "1024x1024"}
        if appearance:
            image = {"appearances": [{"appearance": "luminosity", "value": appearance}], **image}
        images.append(image)
    json.dump({"images": images, "info": INFO}, open(os.path.join(folder, "Contents.json"), "w"), indent=2)


def preview(name, source):
    folder = os.path.join(ASSETS, "IconPreviews", f"IconPreview-{name}.imageset")
    os.makedirs(folder, exist_ok=True)
    Image.open(os.path.join(source, f"{name}-light.png")).convert("RGB").resize((180, 180), Image.LANCZOS).save(os.path.join(folder, "preview.png"), optimize=True)
    json.dump({"images": [{"filename": "preview.png", "idiom": "universal", "scale": "3x"}], "info": INFO},
              open(os.path.join(folder, "Contents.json"), "w"), indent=2)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    source = sys.argv[1]
    names = sorted({f.rsplit("-", 1)[0] for f in os.listdir(source) if f.endswith("-light.png")})
    os.makedirs(os.path.join(ASSETS, "IconPreviews"), exist_ok=True)
    json.dump({"info": INFO}, open(os.path.join(ASSETS, "IconPreviews", "Contents.json"), "w"), indent=2)
    for name in names:
        icon_set(name, source)
        preview(name, source)
        print(name)
