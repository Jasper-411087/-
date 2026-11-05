extends Node
## 自動演奏驗證（無畫面）：godot --headless --path . res://tools/autoplay_test.tscn
## 以固定步長模擬完美擊打所有音符，確認 Phase 1~3 可通關。

const STEP := 1.0 / 240.0

var game: Control
var phase := 1
var finished_flag := false


func _ready() -> void:
	_start()


func _start() -> void:
	GameState.current_phase = phase
	finished_flag = false
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	game.finished.connect(func(): finished_flag = true)
	game.set_process(false)  # 由本腳本以固定步長驅動


func _process(_d: float) -> void:
	for i in 400:
		if finished_flag:
			break
		_step()
	if finished_flag:
		print("Phase %d  cleared=%s score=%d counts=%s maxcombo=%d boss=%d hp=%d" % [phase, GameState.cleared, GameState.score, GameState.counts, GameState.max_combo, GameState.boss_hp, GameState.player_hp])
		game.queue_free()
		for a in game.LANE_ACTIONS:
			Input.action_release(a)
		phase += 1
		if phase > 3:
			get_tree().quit()
		else:
			_start.call_deferred()
		finished_flag = false
		game = null if phase > 3 else game


func _step() -> void:
	for n in game.notes:
		var action: String = game.LANE_ACTIONS[n["lane"]]
		if not n["done"] and not n["holding"] and absf(n["t"] - game.song_time) < STEP:
			Input.action_press(action)
			game._hit_lane(n["lane"])
		elif n["holding"]:
			Input.action_press(action)
		elif n["done"] and Input.is_action_pressed(action):
			Input.action_release(action)
	game._process(STEP)
