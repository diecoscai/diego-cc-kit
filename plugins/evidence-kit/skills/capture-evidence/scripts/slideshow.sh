#!/usr/bin/env bash
# Stitch existing screenshots into an mp4 evidence clip (each shown ~3s, labeled).
# Use when you only have stills (e.g. staging PrintWindow grabs that can't be recordVideo'd).
# Usage: slideshow.sh <screenshots_dir> <out.mp4> "<label>"
set -euo pipefail
SS="${1:?screenshots dir}"; OUT="${2:?out mp4}"; LABEL="${3:-evidence}"
command -v ffmpeg >/dev/null || { echo "ffmpeg not found — install it (apt/brew install ffmpeg)"; exit 3; }
# Resolve a bold font portably: try the Debian path, else ask fontconfig, else give up clearly.
FONT="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
[ -f "$FONT" ] || FONT="$(fc-match -f '%{file}' 'sans:bold' 2>/dev/null || true)"
[ -n "$FONT" ] && [ -f "$FONT" ] || { echo "no usable font (install fonts-dejavu or fontconfig)"; exit 3; }
mkdir -p "$(dirname "$OUT")"

shopt -s nullglob nocaseglob
shots=( "$SS"/*.png "$SS"/*.jpg "$SS"/*.jpeg )
shopt -u nullglob nocaseglob
(( ${#shots[@]} )) || { echo "NO_SCREENSHOTS in $SS"; exit 2; }

# sanitize label for drawtext
label="$(printf '%s' "$LABEL" | cut -c1-60 | tr -d "':%\\" | tr '\n' ' ')"

list="$(mktemp)"
for f in "${shots[@]}"; do printf "file '%s'\nduration 3\n" "$f" >> "$list"; done
printf "file '%s'\n" "${shots[${#shots[@]}-1]}" >> "$list"   # repeat last frame

# 1280x720 frame = a 40px dark label band on top + the image fit into the 1280x680 below it:
# fit-in-1280x680 -> pad to 1280x680 (black) -> pad to full 1280x720 offset y=40 (label bg) -> draw label in the band.
ffmpeg -y -loglevel error -f concat -safe 0 -i "$list" \
  -vf "scale=1280:680:force_original_aspect_ratio=decrease,pad=1280:680:(ow-iw)/2:(oh-ih)/2:color=black,pad=1280:720:0:40:color=0x111827,drawtext=fontfile=${FONT}:text='${label}':x=20:y=12:fontsize=20:fontcolor=white,format=yuv420p" \
  -r 30 -c:v libx264 -crf 23 -movflags +faststart "$OUT"
rm -f "$list"
echo "OK $OUT"
