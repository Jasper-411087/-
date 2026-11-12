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

	for n in notes:
		if n["done"]:
			continue
		var y: float = JUDGE_Y - (n["t"] - song_time) * speed
		if n["holding"]:
			y = JUDGE_Y
		var y_tail: float = JUDGE_Y - (n["t"] + n["len"] - song_time) * speed
		if y < TOP_Y - NOTE_H or y_tail > size.y:
			continue
		y_tail = maxf(y_tail, TOP_Y)
		var x: float = left + n["lane"] * LANE_W
		var col: Color = LANE_COLORS[n["lane"]]
		if n["len"] > 0.0:
			draw_rect(Rect2(x + 60, y_tail, LANE_W - 120, y - y_tail), Color(col, 0.6 if n["holding"] else 0.35))
		draw_rect(Rect2(x + 10, y - NOTE_H / 2.0, LANE_W - 20, NOTE_H), col)

	if _grade_t > 0.0:
		var c: Color = GRADE_COLORS.get(_grade, Color.WHITE)
		c.a = clampf(_grade_t / 0.25, 0.0, 1.0)
		var rise := (0.5 - _grade_t) * 40.0
		draw_string(_font, Vector2(left, JUDGE_Y - 140 - rise), _grade.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, LANE_W * LANE_COUNT, 64, c)
		if _timing != "":
			var tc := Color("4fd1ff") if _timing == "FAST" else Color("ff9f43")
			tc.a = c.a
			draw_string(_font, Vector2(left, JUDGE_Y - 90 - rise), _timing, HORIZONTAL_ALIGNMENT_CENTER, LANE_W * LANE_COUNT, 36, tc)
