extends Control
## 4 軌音符區：只負責繪製。邏輯在 game.gd。
## 版面依規格書圖 1-2：4 軌置中（x 420~1500），上方留給歌曲進度條，底部為 D F J K 按鍵框。

const LANE_COUNT := 4
const LANE_W := 270.0
const TOP_Y := 60.0       # 歌曲進度條下緣
const JUDGE_Y := 940.0    # 判定線
const NOTE_H := 32.0
const KEY_LABELS := ["D", "F", "J", "K"]
const LANE_COLORS := [Color("4fd1ff"), Color("7cf0a8"), Color("ffd166"), Color("ff7aa2")]
const GRADE_COLORS := {
	"perfect": Color("ffe066"), "good": Color("7cf0a8"),
	"bad": Color("9aa5b1"), "miss": Color("ff6b6b"),
}

var song_time := 0.0
var notes: Array = []          # 每筆 {"t","lane","len","done","holding"}
var lane_pressed := [false, false, false, false]

var _grade := ""
var _timing := ""  # "FAST" / "LATE" / ""
var _grade_t := 0.0   # 判定文字剩餘顯示時間
var _font := ThemeDB.fallback_font


## Hold 音符：與 Tap 明顯不同 —
## 頭：白框＋中間橫線；身體：較寬的條紋長條；尾：白色粗橫槓（放開點）。
## 按住時身體發亮、尾端接近判定線（剩 0.3 秒內）會閃爍提示放開。
func _draw_hold(n: Dictionary, x: float, y: float, y_tail: float, col: Color) -> void:
	var holding: bool = n["holding"]
	var top := maxf(y_tail, TOP_Y)
	var body := Rect2(x + 40, top, LANE_W - 80, y - top)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 90.0)
	draw_rect(body, Color(col, 0.75 if holding else 0.4))
	# 斜條紋（往下捲動，表示「持續按住」）
	var stripe_gap := 36.0
	var phase := fmod(song_time * 200.0, stripe_gap)
	var sy := body.end.y - phase
	while sy > body.position.y:
		var y0 := maxf(sy - 14.0, body.position.y)
		draw_rect(Rect2(body.position.x, y0, body.size.x, sy - y0), Color(1, 1, 1, 0.25 if holding else 0.12))
		sy -= stripe_gap
	# 身體兩側亮邊
	var edge := Color(1, 1, 1, 0.9 if holding else 0.5)
	draw_line(Vector2(body.position.x, body.position.y), Vector2(body.position.x, body.end.y), edge, 3.0)
	draw_line(Vector2(body.end.x, body.position.y), Vector2(body.end.x, body.end.y), edge, 3.0)
	# 尾端：白色粗橫槓（快放開時閃爍）
	if y_tail >= TOP_Y:
		var remain: float = n["t"] + n["len"] - song_time
		var tail_col := Color.WHITE
		if holding and remain < 0.3:
			tail_col = Color(1, 1, 0.4).lerp(Color.WHITE, pulse)
		draw_rect(Rect2(x + 14, y_tail - 9, LANE_W - 28, 18), tail_col)
		draw_rect(Rect2(x + 14, y_tail - 9, LANE_W - 28, 18), col, false, 3.0)
	# 頭：白框＋中間橫線（Tap 是純色長方形）
	var head := Rect2(x + 10, y - NOTE_H / 2.0, LANE_W - 20, NOTE_H)
	draw_rect(head, col.lerp(Color.WHITE, 0.35 * pulse) if holding else col)
	draw_rect(head, Color.WHITE, false, 4.0)
	draw_line(Vector2(head.position.x + 16, y), Vector2(head.end.x - 16, y), Color(1, 1, 1, 0.9), 3.0)
	if holding:  # 按住中：判定線上的光暈
		draw_rect(Rect2(x + 4, JUDGE_Y - 26, LANE_W - 8, 52), Color(col, 0.25 + 0.2 * pulse))


## timing：按得太早 "FAST"、太晚 "LATE"（Perfect 與 Miss 不顯示）
func show_grade(grade: String, timing: String = "") -> void:
	_grade = grade
	_timing = timing
	_grade_t = 0.5


func _process(delta: float) -> void:
	if _grade_t > 0.0:
		_grade_t = maxf(0.0, _grade_t - delta)
		queue_redraw()


func _draw() -> void:
	var speed: float = Settings.pixels_per_sec()
	var left := (size.x - LANE_W * LANE_COUNT) / 2.0
	var right := left + LANE_W * LANE_COUNT
	draw_rect(Rect2(left, TOP_Y, LANE_W * LANE_COUNT, size.y - TOP_Y), Color(0, 0, 0, 0.55))
	for i in LANE_COUNT:
		var x := left + i * LANE_W
		draw_line(Vector2(x, TOP_Y), Vector2(x, size.y), Color(1, 1, 1, 0.15), 2.0)
		if lane_pressed[i]:
			draw_rect(Rect2(x, TOP_Y, LANE_W, JUDGE_Y - TOP_Y), Color(LANE_COLORS[i], 0.15))
		var keybox := Rect2(x + 6, JUDGE_Y + 12, LANE_W - 12, size.y - JUDGE_Y - 20)
		draw_rect(keybox, Color(LANE_COLORS[i], 0.9 if lane_pressed[i] else 0.3))
		draw_string(_font, Vector2(x, JUDGE_Y + 90), KEY_LABELS[i], HORIZONTAL_ALIGNMENT_CENTER, LANE_W, 48)
	draw_line(Vector2(right, TOP_Y), Vector2(right, size.y), Color(1, 1, 1, 0.15), 2.0)
	draw_line(Vector2(left, JUDGE_Y), Vector2(right, JUDGE_Y), Color.WHITE, 4.0)

	var holding_lanes := {}  # lane -> 剩餘比例（0~1），用來在按鍵框顯示 HOLD
	for n in notes:
		if n["done"]:
			continue
		var y: float = JUDGE_Y - (n["t"] - song_time) * speed
		if n["holding"]:
			y = JUDGE_Y
		var y_tail: float = JUDGE_Y - (n["t"] + n["len"] - song_time) * speed
		if y < TOP_Y - NOTE_H or y_tail > size.y:
			continue
		var x: float = left + n["lane"] * LANE_W
		var col: Color = LANE_COLORS[n["lane"]]
		if n["len"] > 0.0:
			if n["holding"]:
				holding_lanes[n["lane"]] = clampf((n["t"] + n["len"] - song_time) / n["len"], 0.0, 1.0)
			_draw_hold(n, x, y, y_tail, col)
		else:
			draw_rect(Rect2(x + 10, y - NOTE_H / 2.0, LANE_W - 20, NOTE_H), col)

	# 按住中的軌：按鍵框顯示 HOLD 與剩餘長度
	for lane in holding_lanes:
		var x: float = left + lane * LANE_W
		var box := Rect2(x + 6, JUDGE_Y + 12, LANE_W - 12, size.y - JUDGE_Y - 20)
		var remain: float = holding_lanes[lane]
		draw_rect(Rect2(box.position.x, box.end.y - 10, box.size.x * remain, 10), Color.WHITE)
		draw_string(_font, Vector2(x, JUDGE_Y + 40), "HOLD", HORIZONTAL_ALIGNMENT_CENTER, LANE_W, 26, Color(1, 1, 1, 0.9))

	if _grade_t > 0.0:
		var c: Color = GRADE_COLORS.get(_grade, Color.WHITE)
		c.a = clampf(_grade_t / 0.25, 0.0, 1.0)
		var rise := (0.5 - _grade_t) * 40.0
		draw_string(_font, Vector2(left, JUDGE_Y - 140 - rise), _grade.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, LANE_W * LANE_COUNT, 64, c)
		if _timing != "":
			var tc := Color("4fd1ff") if _timing == "FAST" else Color("ff9f43")
			tc.a = c.a
			draw_string(_font, Vector2(left, JUDGE_Y - 90 - rise), _timing, HORIZONTAL_ALIGNMENT_CENTER, LANE_W * LANE_COUNT, 36, tc)
