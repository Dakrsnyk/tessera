"""Keeps the Remotion project of the campaign in the repository without its node_modules.

The project runs in ~/ardane-tools/film (outside the repo: node_modules holds thousands of files).
Its sources live in scripts/ad2/film/.

    python -X utf8 scripts/ad2/film_sync.py export   # ~/ardane-tools/film → scripts/ad2/film (before a commit)
    python -X utf8 scripts/ad2/film_sync.py import   # scripts/ad2/film → ~/ardane-tools/film, then `npm ci` there

Generated media (public/vo, public/sfx, public/kit, out/) are not copied: they come from vo.py, synth.py
and the [adkit] export.
"""
import filecmp
import os
import shutil
import sys

REPO = os.path.join(os.path.dirname(os.path.abspath(__file__)), "film")
WORK = os.path.join(os.path.expanduser("~"), "ardane-tools", "film")
FILES = ["package.json", "package-lock.json", "tsconfig.json", "remotion.config.ts", "eslint.config.mjs"]
DIRS = ["src", "public/fonts"]


def copy(src_root, dst_root):
    changed = 0
    for name in FILES:
        src, dst = os.path.join(src_root, name), os.path.join(dst_root, name)
        if os.path.exists(src) and not (os.path.exists(dst) and filecmp.cmp(src, dst, shallow=False)):
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(src, dst)
            changed += 1
    for d in DIRS:
        src_dir, dst_dir = os.path.join(src_root, d), os.path.join(dst_root, d)
        if not os.path.isdir(src_dir):
            continue
        # Files deleted on the source side are deleted on the other side too.
        if os.path.isdir(dst_dir):
            for root, _, names in os.walk(dst_dir):
                for n in names:
                    path = os.path.join(root, n)
                    if not os.path.exists(os.path.join(src_dir, os.path.relpath(path, dst_dir))):
                        os.remove(path)
                        changed += 1
        for root, _, names in os.walk(src_dir):
            for n in names:
                src = os.path.join(root, n)
                dst = os.path.join(dst_dir, os.path.relpath(src, src_dir))
                if not (os.path.exists(dst) and filecmp.cmp(src, dst, shallow=False)):
                    os.makedirs(os.path.dirname(dst), exist_ok=True)
                    shutil.copy2(src, dst)
                    changed += 1
    return changed


if __name__ == "__main__":
    direction = sys.argv[1] if len(sys.argv) > 1 else ""
    if direction == "export":
        print(f"export: {copy(WORK, REPO)} file(s) updated in {REPO}")
    elif direction == "import":
        print(f"import: {copy(REPO, WORK)} file(s) updated in {WORK} (then run `npm ci` there)")
    else:
        sys.exit(__doc__)
