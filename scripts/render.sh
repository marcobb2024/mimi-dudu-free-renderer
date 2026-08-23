#!/usr/bin/env bash
set -euo pipefail

PAYLOAD_PATH="${1:-/tmp/payload.json}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSET_DIR="$ROOT_DIR/assets"
OUTPUT_DIR="$ROOT_DIR/output"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

command -v ffmpeg >/dev/null || { echo "Falta ffmpeg" >&2; exit 1; }
command -v ffprobe >/dev/null || { echo "Falta ffprobe" >&2; exit 1; }
command -v jq >/dev/null || { echo "Falta jq" >&2; exit 1; }

raw_job_id="$(jq -r '.job_id // ""' "$PAYLOAD_PATH")"
job_id="$(printf '%s' "$raw_job_id" | tr -cd 'A-Za-z0-9_-')"
[[ -n "$job_id" ]] || { echo "job_id inválido" >&2; exit 1; }

preset="$(jq -r '.preset // "cookie_heist"' "$PAYLOAD_PATH")"
case "$preset" in
  cookie_heist|vacuum_chase|bag_surprise|dance_loop) ;;
  *) preset="cookie_heist" ;;
esac

bpm="$(jq -r '.motion_bpm // 108' "$PAYLOAD_PATH")"
if ! [[ "$bpm" =~ ^[0-9]+$ ]] || (( bpm < 80 || bpm > 180 )); then
  bpm=108
fi
beat="${bpm}/60"

mkdir -p "$OUTPUT_DIR"
background="$WORK_DIR/background"
background_url="$(jq -r '.background_url // empty' "$PAYLOAD_PATH")"
if [[ -n "$background_url" ]]; then
  curl --fail --location --max-time 30 --retry 2 --output "$background" "$background_url" || true
fi
if ! ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$background" >/dev/null 2>&1; then
  cp "$ASSET_DIR/fallback_background.png" "$background"
fi

jq -r '.hook_text // "¿QUÉ PODRÍA SALIR MAL?"' "$PAYLOAD_PATH" | tr '\n\r' '  ' | cut -c1-70 > "$WORK_DIR/hook.txt"
jq -r '.twist_text // "ESPERA..."' "$PAYLOAD_PATH" | tr '\n\r' '  ' | cut -c1-70 > "$WORK_DIR/twist.txt"
jq -r '.end_text // "OTRA VEZ"' "$PAYLOAD_PATH" | tr '\n\r' '  ' | cut -c1-70 > "$WORK_DIR/end.txt"

case "$preset" in
  cookie_heist)
    prop="$ASSET_DIR/real_cookie.png"
    mimi_x="60+18*sin(2*PI*t*$beat)"; mimi_y="790-22*abs(sin(2*PI*t*$beat))"
    dudu_x="390-120*min(t/10,1)+14*sin(2*PI*t*$beat)"; dudu_y="760-24*abs(sin(2*PI*t*$beat))"
    prop_x="285+8*sin(4*PI*t*$beat)"; prop_y="1035-12*abs(sin(4*PI*t*$beat))"
    ;;
  vacuum_chase)
    prop="$ASSET_DIR/real_vacuum.png"
    mimi_x="50+32*sin(2*PI*t*$beat)"; mimi_y="730-95*abs(sin(PI*t*$beat))"
    dudu_x="390+36*sin(2*PI*t*$beat+1.2)"; dudu_y="740-100*abs(sin(PI*t*$beat+1.2))"
    prop_x="240+210*sin(2*PI*t/3.0)"; prop_y="1010"
    ;;
  bag_surprise)
    prop="$ASSET_DIR/real_bag.png"
    mimi_x="55+min(t*18,150)"; mimi_y="800-28*abs(sin(2*PI*t*$beat))"
    dudu_x="405-min(t*18,150)"; dudu_y="780-30*abs(sin(2*PI*t*$beat+1.0))"
    prop_x="245+18*sin(6*PI*t*$beat)*between(t,7,11)"; prop_y="955"
    ;;
  dance_loop)
    prop="$ASSET_DIR/real_cookie.png"
    mimi_x="70+55*sin(2*PI*t*$beat)"; mimi_y="780-34*abs(sin(2*PI*t*$beat))"
    dudu_x="390-55*sin(2*PI*t*$beat)"; dudu_y="760-34*abs(sin(2*PI*t*$beat))"
    prop_x="300"; prop_y="1070+12*sin(2*PI*t*$beat)"
    ;;
esac

font="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
output="$OUTPUT_DIR/$job_id.mp4"

ffmpeg -hide_banner -loglevel warning -y \
  -loop 1 -framerate 30 -i "$background" \
  -loop 1 -framerate 30 -i "$ASSET_DIR/mimi.png" \
  -loop 1 -framerate 30 -i "$ASSET_DIR/dudu.png" \
  -loop 1 -framerate 30 -i "$prop" \
  -stream_loop -1 -i "$ASSET_DIR/mimi_dudu_original.wav" \
  -filter_complex "
    [0:v]scale=760:1350:force_original_aspect_ratio=increase,crop=760:1350,
      zoompan=z='min(zoom+0.00035,1.06)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=450:s=720x1280:fps=30[bg];
    [1:v]scale=285:-1:flags=lanczos[mimi];
    [2:v]scale=285:-1:flags=lanczos[dudu];
    [3:v]scale=230:-1:flags=lanczos[prop];
    [bg][prop]overlay=x='$prop_x':y='$prop_y':format=auto[s1];
    [s1][mimi]overlay=x='$mimi_x':y='$mimi_y':format=auto[s2];
    [s2][dudu]overlay=x='$dudu_x':y='$dudu_y':format=auto[s3];
    [s3]drawtext=fontfile='$font':textfile='$WORK_DIR/hook.txt':fontcolor=white:fontsize=46:
      borderw=4:bordercolor=black:box=1:boxcolor=black@0.50:boxborderw=18:
      x=(w-text_w)/2:y=95:enable='between(t,0,3.2)',
      drawtext=fontfile='$font':textfile='$WORK_DIR/twist.txt':fontcolor=white:fontsize=44:
      borderw=4:bordercolor=black:box=1:boxcolor=#de5c37@0.78:boxborderw=18:
      x=(w-text_w)/2:y=95:enable='between(t,8.5,12.2)',
      drawtext=fontfile='$font':textfile='$WORK_DIR/end.txt':fontcolor=white:fontsize=44:
      borderw=4:bordercolor=black:box=1:boxcolor=#1d7fa7@0.78:boxborderw=18:
      x=(w-text_w)/2:y=95:enable='between(t,12.2,15)'[v]
  " \
  -map '[v]' -map 4:a:0 -t 15 \
  -c:v libx264 -preset medium -crf 24 -maxrate 1400k -bufsize 2800k \
  -pix_fmt yuv420p -r 30 -c:a aac -b:a 128k -ar 48000 -ac 2 \
  -movflags +faststart "$output"

duration="$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$output")"
width="$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=nw=1:nk=1 "$output")"
height="$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=nw=1:nk=1 "$output")"
[[ "$width" == "720" && "$height" == "1280" ]] || { echo "Resolución inesperada: ${width}x${height}" >&2; exit 1; }
awk -v d="$duration" 'BEGIN { exit !(d >= 14.9 && d <= 15.1) }' || { echo "Duración inesperada: $duration" >&2; exit 1; }

printf '{"job_id":"%s","file":"output/%s.mp4","duration":%s,"width":%s,"height":%s}\n' \
  "$job_id" "$job_id" "$duration" "$width" "$height" > "$OUTPUT_DIR/$job_id.json"

echo "Render correcto: $output"
