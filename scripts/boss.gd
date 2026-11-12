extends Control
## Boss 占位圖與動畫（程式繪製）。之後可換成 Sprite2D / AnimatedSprite2D 的正式美術。
## 動畫：待機浮動、受擊閃白、Miss 回血時抖動、血量歸零時當機（暗化、X 眼）、通關時淡出。

const SIZE := Vector2(400, 400)
const PHASE_COLORS := {1: Color("ff6b4a"), 2: Color("9aa5b1"), 3: Color("b070ff")}

var phase := 1
var _t := 0.0
var _flash := 0.0     # 受擊閃白 0~1
var _shake := 0.0     # 抖動強度
var _defeated := false
var _broken := false  # Boss 血量歸零（但音樂未結束，Miss 仍可能讓它回血）
var _alpha := 1.0


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	pivot_offset = SIZE / 2.0


func setup(p: int) -> void:
	phase = p
	_defeated = false
	_broken = false
	_alpha = 1.0
	queue_redraw()


func on_damage() -> void:
	_flash = 1.0


func on_heal() -> void:
	_shake = 1.0


func set_broken(value: bool) -> void:
	_broken = value


func on_defeat() -> void:
	_defeated = true


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 6.0)
	_shake = maxf(0.0, _shake - delta * 4.0)
	if _defeated:
		_alpha = maxf(0.0, _alpha - delta * 1.2)
		rotation = sin(_t * 40.0) * 0.05 * _alpha
	queue_redraw()


func _draw() -> void:
	var c: Color = PHASE_COLORS.get(phase, Color.WHITE)
	var bob := sin(_t * 2.0) * 12.0
	var jitter := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 10.0 * _shake
	var center := SIZE / 2.0 + Vector2(0, bob) + jitter
	if _broken:
		c = c.darkened(0.6)
	var body := c.lerp(Color.WHITE, _flash * 0.8)
	body.a = _alpha
	var dark := Color(0.08, 0.08, 0.12, _alpha)
	var glow := Color(1, 1, 0.6, _alpha)

	match phase:
		1:  # 外層防火牆：盾形 + 火焰紋
			var pts := PackedVector2Array([
				center + Vector2(-140, -150), center + Vector2(140, -150),
				center + Vector2(150, 20), center + Vector2(0, 160), center + Vector2(-150, 20)])
			draw_colored_polygon(pts, body)
			draw_polyline(pts + PackedVector2Array([pts[0]]), dark, 6.0)
			draw_line(center + Vector2(0, -150), center + Vector2(0, 150), dark, 4.0)
		2:  # 機械怪：堆疊方塊
			for i in 3:
				var w := 300.0 - i * 60.0
				var r := Rect2(center + Vector2(-w / 2.0, -150 + i * 100), Vector2(w, 90))
				draw_rect(r, body)
				draw_rect(r, dark, false, 5.0)
		3:  # 核心：菱形 + 巨眼
			var pts3 := PackedVector2Array([
				center + Vector2(0, -170), center + Vector2(150, 0),
				center + Vector2(0, 170), center + Vector2(-150, 0)])
			draw_colored_polygon(pts3, body)
			draw_polyline(pts3 + PackedVector2Array([pts3[0]]), dark, 6.0)
	# 眼睛（共通）
	var eye_y := -20.0 if phase != 3 else 0.0
	for sx in [-1, 1]:
		var ep: Vector2 = center + Vector2(sx * 45, eye_y)
		if phase == 3 and sx == 1:
			continue
		if phase == 3:
			ep = center
		if _broken:
			var r := 16.0
			draw_line(ep + Vector2(-r, -r), ep + Vector2(r, r), glow, 6.0)
			draw_line(ep + Vector2(-r, r), ep + Vector2(r, -r), glow, 6.0)
			continue
		draw_circle(ep, 26.0 if phase == 3 else 20.0, glow)
		draw_circle(ep + Vector2(0, 4), 10.0, dark)
