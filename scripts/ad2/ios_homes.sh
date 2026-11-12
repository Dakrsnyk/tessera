#!/bin/bash
# Recomposes the app's Home captures (home-hero-*, home-crepuscule: wallpaper + the same widgets + REAL Apple icons on the
# measured iOS grid, lib/iosHome.ts) into ~/ardane-tools/film/public/ioshome/<lang>/<name>.png. kit.ts serves them under the
# old names. Run after a change of lib/iosHome.ts or of the kit (sources synchronised into ~/ardane-tools/film/src first).
set -e
cd ~/ardane-tools/film
NAMES=$(node -e "const s=require('fs').readFileSync('src/lib/iosHome.ts','utf8');const b=s.slice(s.indexOf('IOS_CAPTURES: Record'));console.log([...b.matchAll(/^  \"([a-z0-9-]+)\":/gm)].map(m=>m[1]).join(' '))")
for lang in en fr; do
  rm -rf out/ioshome-$lang && mkdir -p out/ioshome-$lang public/ioshome/$lang
  npx remotion render src/ioshome/index.ts IosHomeCapture out/ioshome-$lang --sequence --image-format=png --concurrency=1 --props="{\"lang\":\"$lang\"}" > out/ioshome-$lang.log 2>&1
  i=0
  for n in $NAMES; do
    f=$(ls out/ioshome-$lang/*.png | sort | sed -n "$((i+1))p")
    cp "$f" public/ioshome/$lang/$n.png
    i=$((i+1))
  done
  echo "$lang: $i captures"
done
