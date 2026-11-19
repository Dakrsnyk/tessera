#!/bin/bash
# Rendu d'un film de la campagne 2026-11 : paquet propre au film, deux rendus au plus en même temps (verrous
# out/campaign/slot-1|2), image sans son puis le son (public/campaign/<film>/mix.wav) ajouté par ffmpeg, planche de contrôle.
#   bash scripts/ad2/campaign_render.sh <film> <CompositionId> [version]     (version : v1 par défaut)
# Sortie : pub/campagne-2026-11/<film>/ardane-<film>-<version>-1080x1920.mp4 et planche-<version>.jpg
set -u
FILM=$1; COMP=$2; VER=${3:-v1}
FD=~/ardane-tools/film
REPO=/c/Users/Etudiant/Documents/GitHub/tessera
OUTD=$REPO/pub/campagne-2026-11/$FILM
W=$FD/out/campaign/$FILM
mkdir -p "$OUTD" "$W/tmp" "$FD/out/campaign"
cd "$FD"
rm -rf "$W/bundle"
npx remotion bundle "src/campaign/$FILM/index.ts" --out-dir="$W/bundle" > "$W/bundle.log" 2>&1 || { echo "bundle failed: $W/bundle.log"; exit 1; }
SLOT=""
while [ -z "$SLOT" ]; do
  for s in 1 2; do
    if mkdir "$FD/out/campaign/slot-$s" 2>/dev/null; then SLOT=$s; break; fi
  done
  [ -z "$SLOT" ] && sleep 20
done
trap 'rmdir "$FD/out/campaign/slot-$SLOT" 2>/dev/null' EXIT
echo "$FILM slot $SLOT $(date +%T)"
TMP="$W/tmp" TEMP="$W/tmp" npx remotion render "$W/bundle" "$COMP" "$W/video.mp4" --muted --crf=16 --concurrency=4 > "$W/render.log" 2>&1
rc=$?
rmdir "$FD/out/campaign/slot-$SLOT" 2>/dev/null; trap - EXIT
[ $rc -eq 0 ] && [ -s "$W/video.mp4" ] || { echo "render failed ($rc): $W/render.log"; tail -c 600 "$W/render.log"; exit 1; }
OUT="$OUTD/ardane-$FILM-$VER-1080x1920.mp4"
if [ -s "public/campaign/$FILM/mix.wav" ]; then
  ffmpeg -v error -y -i "$W/video.mp4" -i "public/campaign/$FILM/mix.wav" -map 0:v -map 1:a -c:v copy -c:a aac -b:a 192k -shortest -movflags +faststart "$OUT"
else
  cp "$W/video.mp4" "$OUT"; echo "warning: no mix.wav, silent video"
fi
ffmpeg -v error -y -i "$OUT" -vf "fps=1,scale=180:-1,tile=8x5" -frames:v 1 "$OUTD/planche-$VER.jpg"
echo "done $OUT $(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT") s"
