#!/usr/bin/env bash
# 產生測試用譜面（隨機，固定種子）。正式譜面請手動製作後覆蓋 data/charts/。
# 依規格書「遊戲元素與關卡設計」：
#   Phase 1 約 2 分   Boss 200  Tap
#   Phase 2 約 3 分   Boss 400  Tap、Hold、雙押/三押
#   Phase 3 約 3.5 分 Boss 700  Tap、Hold、對拍（左 2 右 2 交替）、四押
cd "$(dirname "$0")/.."
mkdir -p data/charts
# 參數：phase 間隔秒 步數 Hold機率 多押機率 多押最大數 對拍機率
gen() {
awk -v p=$1 -v s=$2 -v n=$3 -v hc=$4 -v cc=$5 -v mc=$6 -v jc=$7 '
function note(t, lane, len) { out[++k] = sprintf("\t\t{\"t\": %.3f, \"lane\": %d, \"len\": %.3f}", t, lane, len) }
BEGIN {
  srand(p);
  t = 3.0; jrun = 0; side = 0;
  for (i = 0; i < n; i++) {
    if (jrun > 0) {                       # 對拍：左 2（D F）與右 2（J K）交替
      note(t, side*2, 0); note(t, side*2+1, 0);
      side = 1 - side; jrun--; t += s; continue;
    }
    if (rand() < jc) { jrun = 4 + 2*int(rand()*3); side = int(rand()*2); i--; continue; }
    lane = int(rand()*4);
    if (rand() < hc) { len = s*(1+int(rand()*3)); note(t, lane, len); t += s + len; continue; }
    if (rand() < cc) {                    # 多押：2 ~ mc 個不同軌
      size = 2 + int(rand()*(mc-1));
      for (a = 0; a < 4; a++) L[a] = a;
      for (a = 3; a > 0; a--) { b = int(rand()*(a+1)); tmp = L[a]; L[a] = L[b]; L[b] = tmp; }
      for (a = 0; a < size; a++) note(t, L[a], 0);
    } else note(t, lane, 0);
    t += s;
  }
  printf "{\n\t\"phase\": %d,\n\t\"bpm\": 120,\n\t\"audio\": \"res://assets/audio/phase%d.ogg\",\n\t\"notes\": [\n", p, p;
  for (j = 1; j <= k; j++) printf "%s%s\n", out[j], (j < k ? "," : "");
  print "\t]\n}";
}' > data/charts/phase$1.json
}
gen 1 0.42 275 0.00 0.00 1 0.00
gen 2 0.36 420 0.10 0.14 3 0.00
gen 3 0.27 680 0.08 0.12 4 0.03
