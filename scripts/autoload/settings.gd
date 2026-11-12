extends Node
## 玩家設定（Autoload: Settings），存在 user://settings.cfg
## scroll_speed：流速 1.0 ~ 20.0（顯示用數字），實際像素速度 = scroll_speed × 100 像素/秒

signal changed

const PATH := "user://settings.cfg"
const SPEED_MIN := 3.0
const SPEED_MAX := 20.0
const SPEED_STEP := 0.5

var scroll_speed := 9.0


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		scroll_speed = clampf(float(cfg.get_value("play", "scroll_speed", scroll_speed)), SPEED_MIN, SPEED_MAX)


func pixels_per_sec() -> float:
	return scroll_speed * 100.0


func change_speed(steps: int) -> void:
	scroll_speed = clampf(scroll_speed + steps * SPEED_STEP, SPEED_MIN, SPEED_MAX)
	var cfg := ConfigFile.new()
	cfg.set_value("play", "scroll_speed", scroll_speed)
	cfg.save(PATH)
	changed.emit()
