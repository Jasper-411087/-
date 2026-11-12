#!/usr/bin/env python3
"""MIDI → 譜面 JSON（只用 Python 標準函式庫）。

用法：
  python tools/midi_to_chart.py --info 檔案.mid
      列出 MIDI 的音軌、長度、音符數
  python tools/midi_to_chart.py 檔案.mid --phase 2 [--start 秒] [--end 秒] [--speed 倍率] [--offset 秒]
      產生 data/charts/phaseN.json

時間換算：譜面時間 = (MIDI 時間 - start) / speed + offset
（音檔也必須用相同的 start / speed / offset 處理，見 tools/render_audio.sh）

各關規則（規格書「遊戲元素與關卡設計」）：
  Phase 1：只有 Tap，密度低
  Phase 2：Tap、Hold、雙押/三押
  Phase 3：Tap、Hold、對拍（左 2 右 2 交替）、四押，密度最高
"""
import argparse
import json
import os
import struct
import sys

# 每關參數：min_gap 兩個音符最小間隔（秒）；max_chord 最多幾押；
# chord_every 多押最短間隔（秒，避免太頻繁）；hold_min 音長超過即為 Hold；jack_gap 對拍觸發的最大間隔
PHASES = {
    1: dict(min_gap=0.30, max_chord=1, chord_every=999, hold_min=999, jack_gap=0, boss=200),
    2: dict(min_gap=0.26, max_chord=3, chord_every=1.2, hold_min=0.60, jack_gap=0, boss=400),
    3: dict(min_gap=0.17, max_chord=4, chord_every=0.9, hold_min=0.55, jack_gap=0.22, boss=700),
}
GROUP_EPS = 0.035  # 這個時間內的音視為同時（和弦）


# ---------- MIDI 解析 ----------
def _varlen(data, i):
    v = 0
    while True:
        b = data[i]
        i += 1
        v = (v << 7) | (b & 0x7F)
        if not b & 0x80:
            return v, i


def parse_midi(path):
    """回傳 notes: [(start秒, end秒, pitch, velocity, track)]"""
    data = open(path, "rb").read()
    if data[:4] != b"MThd":
        raise ValueError("不是 MIDI 檔")
    hlen = struct.unpack(">I", data[4:8])[0]
    fmt, ntrk, division = struct.unpack(">HHH", data[8:14])
    if division & 0x8000:
        raise ValueError("不支援 SMPTE 時間格式")
    pos = 8 + hlen
    raw = []      # (tick, track, kind, a, b)
    tempos = []   # (tick, us_per_beat)
    for trk in range(ntrk):
        assert data[pos:pos + 4] == b"MTrk"
        tlen = struct.unpack(">I", data[pos + 4:pos + 8])[0]
        i, end = pos + 8, pos + 8 + tlen
        tick, status = 0, 0
        while i < end:
            d, i = _varlen(data, i)
            tick += d
            b = data[i]
            if b == 0xFF:
                mtype = data[i + 1]
                ln, i = _varlen(data, i + 2)
                if mtype == 0x51:
                    tempos.append((tick, int.from_bytes(data[i:i + 3], "big")))
                i += ln
                continue
            if b in (0xF0, 0xF7):
                ln, i = _varlen(data, i + 1)
                i += ln
                continue
            if b & 0x80:
                status = b
                i += 1
            hi = status & 0xF0
            if hi in (0xC0, 0xD0):
                i += 1
                continue
            a1, a2 = data[i], data[i + 1]
            i += 2
            ch = status & 0x0F
            if hi == 0x90 and a2 > 0:
                raw.append((tick, trk, ch, "on", a1, a2))
            elif hi == 0x80 or (hi == 0x90 and a2 == 0):
                raw.append((tick, trk, ch, "off", a1, 0))
        pos = end

    tempos.sort()
    if not tempos or tempos[0][0] != 0:
        tempos.insert(0, (0, 500000))

    def tick_to_sec(t):
        sec, last_tick, us = 0.0, 0, tempos[0][1]
        for tt, u in tempos:
            if tt > t:
                break
            sec += (tt - last_tick) * us / 1e6 / division
            last_tick, us = tt, u
        return sec + (t - last_tick) * us / 1e6 / division

    raw.sort(key=lambda e: (e[0], e[3] == "on"))
    open_notes, notes = {}, []
    for tick, trk, ch, kind, pitch, vel in raw:
        key = (trk, ch, pitch)
        if kind == "on":
            open_notes.setdefault(key, []).append((tick, vel))
        elif open_notes.get(key):
            st, v = open_notes[key].pop(0)
            notes.append((tick_to_sec(st), tick_to_sec(tick), pitch, v, trk))
    notes.sort()
    return notes, ntrk


# ---------- 選音 ----------
def group_onsets(notes):
    groups = []
    for n in notes:
        if groups and n[0] - groups[-1][0][0] <= GROUP_EPS:
            groups[-1].append(n)
        else:
            groups.append([n])
    return groups


def make_chart(notes, phase, start, end, speed, offset, tracks=None):
    cfg = PHASES[phase]
    sel = [n for n in notes if start <= n[0] < end and (tracks is None or n[4] in tracks)]
    groups = group_onsets(sel)
    out = []
    lane_busy = [-1.0] * 4  # 各軌被 Hold 佔用到的時間
    last_t = -999.0
    last_chord_t = -999.0
    last_lane = -1
    jack_side = 0
    lo, hi = 127, 0
    for g in groups:
        t = (g[0][0] - start) / speed + offset
        if t - last_t < cfg["min_gap"] - 1e-6:
            continue
        pitches = sorted({n[2] for n in g})
        top = max(g, key=lambda n: n[2])
        # 動態音域（慢慢回歸）決定軌道：高音在右、低音在左
        lo = min(lo + 0.5, top[2]); hi = max(hi - 0.5, top[2])
        span = max(hi - lo, 6)
        lane = min(3, int((top[2] - lo) / span * 4))
        if lane == last_lane and t - last_t < cfg["min_gap"] * 1.6:
            lane = (lane + (1 if lane < 2 else -1)) % 4  # 避免太快的同軌連打
        free = [l for l in range(4) if lane_busy[l] < t - 0.05]
        if not free:
            continue
        if lane not in free:
            lane = min(free, key=lambda l: abs(l - lane))

        # 對拍（Phase 3）：連續快速的和弦 → 左 2 / 右 2 交替
        if cfg["jack_gap"] and len(pitches) >= 2 and t - last_t <= cfg["jack_gap"] and all(lane_busy[l] < t - 0.05 for l in range(4)):
            jack_side = 1 - jack_side
            for l in (jack_side * 2, jack_side * 2 + 1):
                out.append({"t": round(t, 3), "lane": l, "len": 0.0})
            last_t, last_lane = t, -1
            continue

        size = 1
        if cfg["max_chord"] > 1 and len(pitches) >= 2 and t - last_chord_t >= cfg["chord_every"]:
            size = min(cfg["max_chord"], len(pitches), len(free))
            if size > 1:
                last_chord_t = t
        dur = (top[1] - top[0]) / speed
        if size == 1 and dur >= cfg["hold_min"]:
            hlen = round(min(dur, 2.0), 3)
            out.append({"t": round(t, 3), "lane": lane, "len": hlen})
            lane_busy[lane] = t + hlen
        else:
            lanes = [lane] + sorted((l for l in free if l != lane), key=lambda l: abs(l - lane))
            for l in lanes[:size]:
                out.append({"t": round(t, 3), "lane": l, "len": 0.0})
        last_t, last_lane = t, lane
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("midi")
    ap.add_argument("--info", action="store_true", help="只列出 MIDI 資訊")
    ap.add_argument("--phase", type=int, choices=[1, 2, 3])
    ap.add_argument("--start", type=float, default=0.0, help="從 MIDI 第幾秒開始")
    ap.add_argument("--end", type=float, default=1e9, help="到 MIDI 第幾秒結束")
    ap.add_argument("--speed", type=float, default=1.0, help="播放速度倍率（<1 變慢）")
    ap.add_argument("--offset", type=float, default=2.0, help="音檔開頭的空白秒數")
    ap.add_argument("--tracks", type=str, default="", help="只用這些音軌，例如 1,2")
    ap.add_argument("--out", type=str, default="")
    a = ap.parse_args()

    notes, ntrk = parse_midi(a.midi)
    if a.info:
        length = max(n[1] for n in notes) if notes else 0
        print(f"{a.midi}: {ntrk} 軌, 長度 {length:.1f} 秒, {len(notes)} 個音")
        for t in range(ntrk):
            tn = [n for n in notes if n[4] == t]
            if tn:
                print(f"  音軌 {t}: {len(tn)} 音, {tn[0][0]:.1f}~{max(n[1] for n in tn):.1f} 秒, 音高 {min(n[2] for n in tn)}~{max(n[2] for n in tn)}")
        return
    if not a.phase:
        ap.error("請指定 --phase")
    tracks = {int(x) for x in a.tracks.split(",")} if a.tracks else None
    chart = make_chart(notes, a.phase, a.start, a.end, a.speed, a.offset, tracks)
    objs = sum(2 if n["len"] > 0 else 1 for n in chart)
    out = a.out or os.path.join(os.path.dirname(__file__), "..", "data", "charts", f"phase{a.phase}.json")
    doc = {
        "phase": a.phase,
        "audio": f"res://assets/audio/phase{a.phase}.ogg",
        "source": {"midi": os.path.basename(a.midi), "start": a.start, "end": a.end, "speed": a.speed, "offset": a.offset},
        "notes": chart,
    }
    with open(out, "w", encoding="utf-8") as f:
        f.write("{\n")
        for k in ("phase", "audio", "source"):
            f.write(f'\t"{k}": {json.dumps(doc[k], ensure_ascii=False)},\n')
        f.write('\t"notes": [\n')
        f.write(",\n".join("\t\t" + json.dumps(n) for n in chart))
        f.write("\n\t]\n}\n")
    end_t = max((n["t"] + n["len"] for n in chart), default=0)
    chords = {}
    for n in chart:
        chords[n["t"]] = chords.get(n["t"], 0) + 1
    sizes = {}
    for c in chords.values():
        sizes[c] = sizes.get(c, 0) + 1
    boss = PHASES[a.phase]["boss"]
    print(f"Phase {a.phase}: {len(chart)} 音符, 物量 {objs}（Boss 血量 {boss}，可容許約 {(objs - boss) // 2} 個 Miss）, "
          f"Hold {sum(1 for n in chart if n['len'] > 0)}, 幾押分布 {dict(sorted(sizes.items()))}, 結束於 {end_t:.1f} 秒 → {out}")
    if objs <= boss:
        print("警告：物量不足以打倒 Boss！請放慢 min_gap 或延長段落", file=sys.stderr)


if __name__ == "__main__":
    main()
