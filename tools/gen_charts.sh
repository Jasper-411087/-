#!/usr/bin/env bash
# 產生測試用譜面（隨機，固定種子）。正式譜面請手動製作後覆蓋 data/charts/。
# 長度與 Boss 血量依規格書：Phase1 約 2 分/200、Phase2 約 3 分/400、Phase3 約 3.5 分/700
cd "$(dirname "$0")/.."
mkdir -p data/charts
gen() { # phase step count holdchance chordchance
awk -v p=$1 -v s=$2 -v n=$3 -v hc=$4 -v cc=$5 'BEGIN{
  srand(p);
  printf "{\n\t\"phase\": %d,\n\t\"bpm\": 120,\n\t\"audio\": \"res://assets/audio/phase%d.ogg\",\n\t\"notes\": [\n", p, p;
  t=3.0; first=1;
  for(i=0;i<n;i++){
    lane=int(rand()*4); len=0;
    if(rand()<hc){ len=s*(1+int(rand()*2)); }
    line=sprintf("\t\t{\"t\": %.2f, \"lane\": %d, \"len\": %.2f}", t, lane, len);
    out[++k]=line;
    if(len==0 && rand()<cc){ l2=(lane+1+int(rand()*3))%4; out[++k]=sprintf("\t\t{\"t\": %.2f, \"lane\": %d, \"len\": 0.00}", t, l2) }
    t+=s+len;
  }
  for(j=1;j<=k;j++) printf "%s%s\n", out[j], (j<k?",":"");
  print "\t]\n}" }' > data/charts/phase$1.json
}
gen 1 0.50 230 0.00 0.00
gen 2 0.35 440 0.12 0.10
gen 3 0.25 800 0.12 0.15
