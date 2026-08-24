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
    aux_prop="$ASSET_DIR/real_cookie.png"
    prop_scale=165; aux_scale=80
    # 0-3: ven la galleta. 3-7: Mimi se acerca. 7-12: la roba y Dudu la persigue.
    # 12-13.2: salen de escena. Desde 13.2 vuelve la posición inicial para crear el bucle.
    mimi_x="if(lt(t,3),45,if(lt(t,7),45+18.75*(t-3),if(lt(t,12),120-100*(t-7),if(lt(t,13.2),-380,45))))"
    mimi_y="790-12*abs(sin(PI*t*$beat))*between(t,3,7)-42*abs(sin(PI*(t-7)/0.8))*between(t,7,7.8)"
    dudu_x="if(lt(t,7),405,if(lt(t,12),405-100*(t-7),if(lt(t,13.2),-95,405)))"
    dudu_y="775-70*abs(sin(PI*(t-7)/0.9))*between(t,7,7.9)-16*abs(sin(PI*t*$beat))*between(t,8,12)"
    prop_x="if(lt(t,7),300,if(lt(t,12),300-100*(t-7),if(lt(t,13.2),-200,300)))"
    prop_y="1025-18*abs(sin(PI*t*$beat))*between(t,7,12)"
    aux_x="-300"; aux_y="1100"
    ;;
  vacuum_chase)
    prop="$ASSET_DIR/real_vacuum.png"
    aux_prop="$ASSET_DIR/real_cookie.png"
    prop_scale=225; aux_scale=105
    # 0-3: la galleta está en el suelo. 3-7: entra el aspirador y ambos observan.
    # 7-9: susto único. 9-12: aspirador, galleta y personajes corren hacia la derecha.
    # 12-13.2: quedan fuera. Desde 13.2 se restaura la primera escena para el bucle.
    mimi_x="if(lt(t,3),45,if(lt(t,7),45+9*(t-3),if(lt(t,9),81,if(lt(t,12),81+170*(t-9),if(lt(t,13.2),760,45)))))"
    mimi_y="790-8*abs(sin(PI*t*$beat))*between(t,3,7)-72*abs(sin(PI*(t-7)/0.9))*between(t,7,7.9)-14*abs(sin(PI*t*$beat))*between(t,9,12)"
    dudu_x="if(lt(t,3),410,if(lt(t,7),410-8*(t-3),if(lt(t,9),378,if(lt(t,12),378+150*(t-9),if(lt(t,13.2),760,410)))))"
    dudu_y="775-58*abs(sin(PI*(t-7.15)/0.9))*between(t,7.15,8.05)-16*abs(sin(PI*t*$beat))*between(t,9,12)"
    prop_x="if(lt(t,3),-230,if(lt(t,7),-230+120*(t-3),if(lt(t,9),250+7*sin(8*PI*t),if(lt(t,12),250+150*(t-9),if(lt(t,13.2),760,-230)))))"
    prop_y="1015"
    aux_x="if(lt(t,7),465,if(lt(t,9),465+10*sin(8*PI*t),if(lt(t,12),465+150*(t-9),if(lt(t,13.2),760,465))))"
    aux_y="1050-10*abs(sin(8*PI*t))*between(t,7,9)"
    ;;
  bag_surprise)
    prop="$ASSET_DIR/real_bag.png"
    aux_prop="$ASSET_DIR/real_cookie.png"
    prop_scale=210; aux_scale=90
    # Se acercan con cautela; la bolsa tiembla; aparece una galleta y ambos retroceden.
    mimi_x="if(lt(t,3),45,if(lt(t,7),45+8.75*(t-3),if(lt(t,9),80,if(lt(t,10.2),80-45*(t-9),if(lt(t,13.2),26,45)))))"
    mimi_y="795-10*abs(sin(PI*t*$beat))*between(t,3,7)-78*abs(sin(PI*(t-9)/1.2))*between(t,9,10.2)"
    dudu_x="if(lt(t,3),410,if(lt(t,7),410-3.75*(t-3),if(lt(t,9),395,if(lt(t,10.2),395+45*(t-9),if(lt(t,13.2),449,410)))))"
    dudu_y="780-10*abs(sin(PI*t*$beat))*between(t,3,7)-78*abs(sin(PI*(t-9)/1.2))*between(t,9,10.2)"
    prop_x="255+12*sin(12*PI*t)*between(t,6.3,9)"; prop_y="930"
    aux_x="315"; aux_y="if(lt(t,9),1300,if(lt(t,10.5),1300-240*(t-9),if(lt(t,13.2),940,1300)))"
    ;;
  dance_loop)
    prop="$ASSET_DIR/real_cookie.png"
    aux_prop="$ASSET_DIR/real_cookie.png"
    prop_scale=95; aux_scale=70
    # Este preset sí es un baile: entrada, pasos sincronizados, cruce y pose final en bucle.
    mimi_x="if(lt(t,2),-260+160*t,if(lt(t,12.5),70+48*sin(2*PI*t*$beat),if(lt(t,14.6),70,70)))"
    mimi_y="790-30*abs(sin(2*PI*t*$beat))*between(t,2,12.5)"
    dudu_x="if(lt(t,2),720-155*t,if(lt(t,12.5),370-48*sin(2*PI*t*$beat),if(lt(t,14.6),370,370)))"
    dudu_y="775-30*abs(sin(2*PI*t*$beat))*between(t,2,12.5)"
    prop_x="310+8*sin(2*PI*t*$beat)*between(t,2,12.5)"; prop_y="1080"
    aux_x="-300"; aux_y="1100"
    ;;
esac

font="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
output="$OUTPUT_DIR/$job_id.mp4"

ffmpeg -hide_banner -loglevel warning -y \
  -loop 1 -framerate 30 -i "$background" \
  -loop 1 -framerate 30 -i "$ASSET_DIR/mimi.png" \
  -loop 1 -framerate 30 -i "$ASSET_DIR/dudu.png" \
  -loop 1 -framerate 30 -i "$prop" \
  -loop 1 -framerate 30 -i "$aux_prop" \
  -stream_loop -1 -i "$ASSET_DIR/mimi_dudu_original.wav" \
  -filter_complex "
    [0:v]scale=760:1350:force_original_aspect_ratio=increase,crop=760:1350,
      zoompan=z='min(zoom+0.00035,1.06)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=450:s=720x1280:fps=30[bg];
    [1:v]scale=285:-1:flags=lanczos[mimi];
    [2:v]scale=285:-1:flags=lanczos[dudu];
    [3:v]scale=$prop_scale:-1:flags=lanczos[prop];
    [4:v]scale=$aux_scale:-1:flags=lanczos[aux];
    [bg][prop]overlay=x='$prop_x':y='$prop_y':format=auto[s1];
    [s1][mimi]overlay=x='$mimi_x':y='$mimi_y':format=auto[s2];
    [s2][dudu]overlay=x='$dudu_x':y='$dudu_y':format=auto[s3];
    [s3][aux]overlay=x='$aux_x':y='$aux_y':format=auto[s4];
    [s4]drawtext=fontfile='$font':textfile='$WORK_DIR/hook.txt':fontcolor=white:fontsize=46:
      borderw=4:bordercolor=black:box=1:boxcolor=black@0.50:boxborderw=18:
      x=(w-text_w)/2:y=95:enable='between(t,0,3.2)',
      drawtext=fontfile='$font':textfile='$WORK_DIR/twist.txt':fontcolor=white:fontsize=44:
      borderw=4:bordercolor=black:box=1:boxcolor=#de5c37@0.78:boxborderw=18:
      x=(w-text_w)/2:y=95:enable='between(t,8.5,12.2)',
      drawtext=fontfile='$font':textfile='$WORK_DIR/end.txt':fontcolor=white:fontsize=44:
      borderw=4:bordercolor=black:box=1:boxcolor=#1d7fa7@0.78:boxborderw=18:
      x=(w-text_w)/2:y=95:enable='between(t,12.2,15)'[v]
  " \
  -map '[v]' -map 5:a:0 -t 15 \
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
