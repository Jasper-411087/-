#!/usr/bin/env bash
# 由 MIDI 一次產生「音檔 + 譜面」，兩者使用同一組 start/end/speed/offset，保證對拍。
# 需要：python3、fluidsynth、ffmpeg、GM 音色庫（FluidR3_GM.sf2，MIT 授權）
#   Ubuntu：sudo apt install fluidsynth fluid-soundfont-gm ffmpeg
#   Windows：可用 MuseScore 開啟 MIDI 匯出 .ogg，再用相同參數執行 midi_to_chart.py
# 用法：bash tools/build_music.sh [1|2|3]   （不帶參數 = 三關全部）
set -euo pipefail
cd "$(dirname "$0")/.."
SF2="${SF2:-/usr/share/sounds/sf2/FluidR3_GM.sf2}"
OFFSET=2.0   # 音檔開頭空白秒數（倒數後音樂開始，2 秒後第一個音）
FADE=3       # 結尾淡出秒數
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# phase  MIDI  start  end  speed
build() {
	local p=$1 mid=$2 start=$3 end=$4 speed=$5
	echo "== Phase $p: $mid ($start~$end 秒, 速度 x$speed)"
	fluidsynth -ni -q -g 0.8 -r 44100 -F "$TMP/full.wav" "$SF2" "$mid" >/dev/null
	local dur len
	dur=$(python3 -c "print(($end-$start)/$speed)")
	len=$(python3 -c "print($dur+$OFFSET)")
	ffmpeg -loglevel error -y -ss "$start" -t "$(python3 -c "print($end-$start)")" -i "$TMP/full.wav" \
		-af "atempo=$speed,adelay=$(python3 -c "print(int($OFFSET*1000))"):all=1,afade=t=out:st=$(python3 -c "print($len-$FADE)"):d=$FADE,loudnorm=I=-16:TP=-1.5" \
		-ar 44100 -c:a libvorbis -q:a 5 "assets/audio/phase$p.ogg"
	python3 tools/midi_to_chart.py "$mid" --phase "$p" --start "$start" --end "$end" --speed "$speed" --offset "$OFFSET"
}

want=${1:-all}
[[ $want == all || $want == 1 ]] && build 1 assets/music_src/bach_toccata_BWV565.mid      0 120 1.0
[[ $want == all || $want == 2 ]] && build 2 assets/music_src/vivaldi_summer_mvt3.mid      0 156 1.0
[[ $want == all || $want == 3 ]] && build 3 assets/music_src/beethoven_moonlight_mvt3.mid 0 252 1.2
echo "完成。"
