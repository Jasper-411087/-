extends Control
## 4 軌音符區：只負責繪製。邏輯在 game.gd。

const LANE_COUNT := 4
const LANE_W := 150.0
const JUDGE_Y := 900.0
const NOTE_H := 28.0
const SCROLL_SPEED := 900.0  # 像素/秒
const KEY_LABELS := ["D", "F", "J", "K"]
const LANE_COLORS := [Color("4fd1ff"), Color("7cf0a8"), Color("ffd166"), Color("ff7aa2")]

var song_time := 0.0
var notes: Array = []          # 每筆 {"t","lane","done"}
var lane_pressed := [false, false, false, false]
var last_grade := ""

var _font := ThemeDB.fallback_font


func _draw() -> void:
	var left := (size.x - LANE_W * LANE_COUNT) / 2.0
	draw_rect(Rect2(left, 0, LANE_W * LANE_COUNT, size.y), Color(0, 0, 0, 0.55))
	for i in LANE_COUNT:
		var x := left + i * LANE_W
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(1, 1, 1, 0.15), 2.0)
		if lane_pressed[i]:
			draw_rect(Rect2(x, 0, LANE_W, JUDGE_Y), Color(LANE_COLORS[i], 0.18))
		var keybox := Rect2(x + 6, JUDGE_Y + 20, LANE_W - 12, 70)
		draw_rect(keybox, Color(LANE_COLORS[i], 0.9 if lane_pressed[i] else 0.35))
		draw_string(_font, Vector2(x, JUDGE_Y + 70), KEY_LABELS[i], HORIZONTAL_ALIGNMENT_CENTER, LANE_W, 40)
	draw_line(Vector2(left + LANE_COUNT * LANE_W, 0), Vector2(left + LANE_COUNT * LANE_W, size.y), Color(1, 1, 1, 0.15), 2.0)
	draw_line(Vector2(left, JUDGE_Y), Vector2(left + LANE_COUNT * LANE_W, JUDGE_Y), Color.WHITE, 4.0)

	for n in notes:
		if n["done"]:
			continue
		var y: float = JUDGE_Y - (n["t"] - song_time) * SCROLL_SPEED
		if y < -NOTE_H or y > size.y:
			continue
		var x: float = left + n["lane"] * LANE_W
		draw_rect(Rect2(x + 8, y - NOTE_H / 2.0, LANE_W - 16, NOTE_H), LANE_COLORS[n["lane"]])

	if last_grade != "":
		draw_string(_font, Vector2(left, JUDGE_Y - 120), last_grade.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, LANE_W * LANE_COUNT, 48)
